#/bin/bash

## Jamf Pro Category Fixer
# by Richard Brown-Martin 2023
# For internal use by Academia only

# Fixes an issue in Jamf Pro 10.45 where mobile apps which are assigned to a category are not displayed in that category within Self Service.
# Jamf's workaround is to unassign the app from categories, tick the Self Service assignment for the category and then reassign the app to the category. 
# This faffing is not actually needed with the script as the API can assign an app to a Self Service category without the need to unassign and resassign.

username="USERNAMEHERE"
password="PASSWORDHERE"
url="JAMFURLHERE"

#Variable declarations
bearerToken=""
tokenExpirationEpoch="0"

getBearerToken() {
	response=$(curl -s -u "$username":"$password" "$url"/api/v1/auth/token -X POST)
	bearerToken=$(echo "$response" | plutil -extract token raw -)
	tokenExpiration=$(echo "$response" | plutil -extract expires raw - | awk -F . '{print $1}')
	tokenExpirationEpoch=$(date -j -f "%Y-%m-%dT%T" "$tokenExpiration" +"%s")
}

checkTokenExpiration() {
    nowEpochUTC=$(date -j -f "%Y-%m-%dT%T" "$(date -u +"%Y-%m-%dT%T")" +"%s")
    if [[ tokenExpirationEpoch -gt nowEpochUTC ]]
	then
        echo "Token valid until the following epoch time: " "$tokenExpirationEpoch"
	else
        echo "No valid token available, getting new token"
        getBearerToken
	fi
}

invalidateToken() {
	responseCode=$(curl -w "%{http_code}" -H "Authorization: Bearer ${bearerToken}" $url/api/v1/auth/invalidate-token -X POST -s -o /dev/null)
	if [[ ${responseCode} == 204 ]]
	then
		echo "Token successfully invalidated"
		bearerToken=""
		tokenExpirationEpoch="0"
	elif [[ ${responseCode} == 401 ]]
	then
		echo "Token already invalid"
	else
		echo "An unknown error occurred invalidating the token"
	fi
}

xpath() {
	if [[ $(sw_vers -buildVersion) > "20A" ]]; then
		/usr/bin/xpath -e "$@"
	else
		/usr/bin/xpath "$@"
	fi
}

xSearch(){
	echo "$1" | xmllint --xpath "$2" -
}

getData(){
curl --request GET \
--silent \
--url "$url/JSSResource/$1" \
--header 'accept: application/xml' \
--header "Authorization: Bearer $bearerToken"
}

## Start of Script ####

checkTokenExpiration

### Get a list of Mobile Device apps
appListRaw=$(getData "mobiledeviceapplications")
appList=$(xSearch "$appListRaw" "//id/text()" )

## Loop through the IDs
for appID in $appList; do
	# Grab the app's data
	appData=$(getData "mobiledeviceapplications/id/$appID")
	# Check if it's assigned to an ID
	appCategoryID=$(xSearch "$appData" "/mobile_device_application/general/category/id/text()")
	# Check if it's deployed with Self Service
	deploymentMethod=$(xSearch "$appData" "/mobile_device_application/general/deployment_type/text()") 
	# If it has a category and is used with Self Service then...
	if (( $appCategoryID > -1 )) && [ "$deploymentMethod" = "Make Available in Self Service" ]; then
		# Grab the app's name for feedback only
		appName=$(xSearch "$appData" "/mobile_device_application/general/display_name/text()")
		echo "Fixing $appName"
		
#		## Set the category to none
#		noCategory=$(curl --request PUT \
#		--silent \
#		--url "$url/JSSResource/mobiledeviceapplications/id/$appID" \
#		--header 'Content-type: application/xml' \
#		--header "Authorization: Bearer $bearerToken" \
#		--data  '<mobile_device_application>	<general><category><id>-1</id></category></general></mobile_device_application>')
		
		## Set the Self Service category to app category
		selfServiceCategory=$(curl --request PUT \
		--url "$url/JSSResource/mobiledeviceapplications/id/$appID" \
		--silent \
		--header 'Content-type: application/xml' \
		--header "Authorization: Bearer $bearerToken" \
		--data  "<mobile_device_application><self_service><self_service_categories><category><id>$appCategoryID</id><display_in>true</display_in></category></self_service_categories></self_service></mobile_device_application>")
		
#		## Set the category back to the app category
#		resetCategory=$(curl --request PUT \
#		--silent \
#		--url "$url/JSSResource/mobiledeviceapplications/id/$appID" \
#		--header 'Content-type: application/xml' \
#		--header "Authorization: Bearer $bearerToken" \
#		--data  "<mobile_device_application>	<general><category><id>$appCategoryID</id></category></general></mobile_device_application>")
		
	else
		# Grab the app's name for feedback only
		appName=$(xSearch "$appData" "/mobile_device_application/general/display_name/text()")
		echo "Skipping $appName"
	fi
done	

invalidateToken
	