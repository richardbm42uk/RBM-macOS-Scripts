#!/bin/bash

######### Jamf Pro, Upload to JDCS Script
#### By Richard Brown-Martin at Academia
#### All rights reserved

#### Items to Upload
# Set the file to upload here using full paths
filesToUpload="/path/to/file1.pkg
/path/to/file1.pkg"

##############################
#### Setup Instructions #####
############################

# 1. Install aws-cli. This is available from https://aws.amazon.com/cli/

# 2. Set the User Defined Variables
### This script uses API Clients in Jamf, ensure you have created an API Role and Client in Jamf Pro
### The API Client must have the following permissions
# Create Jamf Content Distribution Server Files
# Read Categories, Create Categories
# Read Packages, Create Packages

# 3. Populate the Jamf Pro URL and client credentials shown here

# 4. Populate a category to upload files to

# 5. You can create multiple copies of the script with different Jamf credentials to enable easy future uploads

#################
#### Usage #####
###############

# This script can be used in 2 ways
# 1. Upload a single file by passing an argument - eg: /path/to/script.sh "/path/to/package.pkg"
## Optionally, upload a single file to a category by passing two arguments - eg: /path/to/script.sh "/path/to/package.pkg" "Category Name"
# If no category argument is passed, the script will use the category defined as $categoryForUploaded
# 2. Amend the list of files to upload at the top of this script. You can add multiple packages on different lines

#################################
#### Setup variables here: #####
###############################

# Enter your Jamf API client here
URL=YOURJAMFPROURL
client_id="CLIENTID"
client_secret='CLIENTSECRET'

# Any packages on the FSDP missing from the Jamf Pro database will be created and added to a category with the name below.
categoryForUploaded="JDCS"

##############################################################
###### Nothing should need to be changed below this comment #
############################################################

# Global variables 
IFS=$'\n'

# Functions

logIt(){
	# Logging function
	dateNow=$(date)
	echo "$dateNow: $1"
	#   echo "$dateNow: $1" >> $logfile
}

vlogIt(){
	# Verbose logging function - only log if debug is 1.
	if [ "$debug" = 1 ]; then
		logIt "DEBUG: $1"
	fi
}

xpath() {
	# XPath for different macOS versions
	if [[ $(sw_vers -buildVersion) > "20A" ]]; then
		/usr/bin/xpath -e "$@"
	else
		/usr/bin/xpath "$@"
	fi
}

getToken(){
	# Get the API Token from the credentials
	authToken=$(curl --silent --location --request POST "${URL}/api/oauth/token" \
		--header "Content-Type: application/x-www-form-urlencoded" \
		--data-urlencode "client_id=${client_id}" \
		--data-urlencode "grant_type=client_credentials" \
		--data-urlencode "client_secret=${client_secret}")
	token=$( echo $authToken | grep token | awk -F \" '{ print $4 }'  | xargs )
	if [ -z "$token" ]; then
		logIt  "Could not obtain token, check JSS URL, Credentials and Network"
		exit 1
	fi
}

checkIfCategoryExists(){
	getToken
	# API call to find if the upload category exists
	categoryExists=$(curl --request GET \
	--header "authorization: Bearer $token" \
	--header 'Accept: application/xml' \
	--silent \
	"$URL/JSSResource/categories" | xmllint --xpath "//name/text()" - | grep "$categoryForUploaded")
}

createCategory(){
	getToken
	# Category XML data
	category_data="<category>
	<name>$categoryForUploaded</name>
	<priority>9</priority>
</category>"
	# Create the category
	curl --request "POST" \
	--silent \
	--header "authorization: Bearer $token" \
	--header 'Content-Type: application/xml' \
	--data "$category_data" \
	"$URL/JSSResource/categories/id/0" 
}

fetchUploadDetails(){
	getToken 
	# Jamf API call to obtain the AWS details for uploading to the JDCS
	curl --request POST \
	--silent \
	--header "authorization: Bearer $token" \
	--header 'Accept: application/json' \
	"$URL/api/v1/jcds/files"
}

getUploadDetails(){
	# Fetch the JDCS Upload details for the Jamf API
	uploadDetails=$(fetchUploadDetails) 
	# Extract the necessary configuration into variables
	default_access_key=$(echo "$uploadDetails" | grep accessKeyID | awk -F \" '{print $4'})
	default_secret_key=$(echo "$uploadDetails" | grep secretAccessKey | awk -F \" '{print $4'})
	aws_session_token=$(echo "$uploadDetails" | grep sessionToken | awk -F \" '{print $4'})
	region=$(echo "$uploadDetails" | grep region | awk -F \" '{print $4'})
	s3_bucket=$(echo "$uploadDetails" | grep bucketName | awk -F \" '{print $4'})
	s3_path=$(echo "$uploadDetails" |  grep path | awk -F \" '{print $4'} )
}

awsSetUp(){
	# Configure the AWS binary
	aws configure set aws_access_key_id "$default_access_key"
	aws configure set aws_secret_access_key "$default_secret_key"
	aws configure set aws_session_token "$aws_session_token"
	aws configure set default.region "$region"
}

awsUploadPackage(){
	getUploadDetails 
	awsSetUp 
	logIt "Uploading $pkg_name"
	# Use AWS CP to copy the file to the S3 path
	aws s3 cp "$1" "s3://$s3_bucket/$s3_path"
	uploadresult=$?
}

uploadToJDCS(){
	# Get a new Jamf API token in the event that the old one has expired during long uploads
	getToken 
	# Loop over the combined list of packages to upload to the JDCS
		logIt "Uploading $packageToUpload"
		# Configure AWS and upload the package
		getUploadDetails 
		awsSetUp 
		awsUploadPackage
		if [ $uploadresult = 0 ]; then
			logIt "$packageToUpload successfully uploaded"
		else
			logIt "WARNING: $packageToUpload upload failed"
		fi
}

createPackageInJamf(){
	getToken
	# XML Metadata for package
	pkg_data="<package>
	<name>$1</name>
	<filename>$1</filename>
	<category>$categoryForUploaded</category>
</package>"

	
	# Create the package and extract the ID to ensure it was uploaded okay
	uploadXML=$(curl --request "POST" \
	--header "authorization: Bearer $token" \
	--header 'Content-Type: application/xml' \
	--data "$pkg_data" \
	--silent \
	"$URL/JSSResource/packages/id/-1")
	echo "$uploadXML"
	uploadresult=$(echo "$uploadXML" | xmllint --xpath "//id/text()" - | tr -dc '0-9')
	if [ -n "$uploadresult" ]; then
		logIt "Package $1 created successfully with id $uploadresult"
	else
		logIt "WARNING: Package $1 failed to create"
	fi
}

doesPackageExist(){
	unset packageExists
	getToken 
	packageList=$(curl --request "GET" \
	--header "authorization: Bearer $token" \
	--header 'Content-Type: application/xml' \
	--silent \
	"$URL/JSSResource/packages" | xmllint --xpath "//name/text()" - | grep "$1" )
	for checkPkg in $packageList; do
		if [ "$checkPkg" == "$1" ]; then
			packageExists="yes"
			break
		fi
	done
}

createPackageIfNeeded(){
	pkgToCreate="$1"
	doesPackageExist $pkg_name
	if [ -n "$packageExists" ]; then
		logIt "$pkg_name already exists on Jamf"
	else
		logIt "Creating $pkg_name on Jamf"
		createPackageInJamf "$pkgToCreate"
	fi
}

createCategoryIfNeeded(){
	checkIfCategoryExists
	if [ -n "$categoryExists" ]; then
		categoryNeedsCreating=true
		for categoryToCheck in $categoryExists; do
			if [ "$categoryToCheck" == "$categoryForUploaded" ]; then
				logIt  "Category already exists"
				categoryNeedsCreating=false
				break
			fi
		done
	else
		categoryNeedsCreating=true
	fi
	if [ "$categoryNeedsCreating" = "true" ]; then
		logIt  "Creating new category: $categoryForUploaded"
		silence=$(createCategory)
	fi
}

#### Start of Script #########################

if [ -n "$1" ]; then
	filesToUpload="$1"
fi 
if [ -n "$2" ]; then
	$categoryForUploaded="$2"
fi 
getToken 
logIt "Token Obtained, continuing"
createCategoryIfNeeded 
for pkg_path in $filesToUpload; do
	if [ -e "$pkg_path" ]; then
	pkg_name=$( echo "$pkg_path" | awk -F '/' '{print $NF}' )
	createPackageIfNeeded "$pkg_name"
	awsUploadPackage $pkg_path
	else
		logIt "Could not find item $pkg_path, please check your path"
	fi
done