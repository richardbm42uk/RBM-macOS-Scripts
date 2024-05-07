#!/bin/bash

### Jamf API to set computer name from Asset Tag


IFS=$'\n'
computerIDList=( )
computerNameList=( )
computerSerialList=( )
computerDEPList=( )

xpath() {
	if [[ $(sw_vers -buildVersion) > "20A" ]]; then
		/usr/bin/xpath -e "$@"
	else
		/usr/bin/xpath "$@"
	fi
}

getDialog(){
	dialogInstalled=$(which dialog)
	if [ "$dialogRun" != true ] || [ -z "$dialogInstalled" ] ; then
		# Get the URL of the latest PKG From the Dialog GitHub repo
		dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
		# Expected Team ID of the downloaded PKG
		expectedDialogTeamID="PWA5E9TQ59"
		
		# Check for Dialog and install if not found
		##	if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then
		echo "Dialog not found. Installing..."
		# Create temporary working directory
		tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/dialog.XXXXXX" )
		# Download the installer package
		/usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"
		# Verify the download
		teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
		
		echo $workDirectory
		echo $tempDirectory
		echo $dialogURL
		# Install the package if Team ID validates
		if [ "$expectedDialogTeamID" = "$teamID" ] || [ "$expectedDialogTeamID" = "" ]; then
			/usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
		else
			logIt "Dialog Team ID verification failed."
			exit 1
		fi
	fi
	dialogRun=true
}


setJamfCreds(){
	jamfcreds=$(dialog \
	--title "Jamf LAPS" \
	--titlefont "weight=thin" \
	--textfield "Jamf URL",required,prompt="https://JAMFSERVER.jamfcloud.com" \
	--textfield "Username",required,prompt="UserName" \
	--textfield "Password",secure,required \
	--icon "SF=lock.square,colour=purple,colour2=orange,weight=light" \
	--overlayicon "SF=person.badge.key.fill,palette=black,black,white,bgcolor=none" \
	--message "Enter Jamf Pro Credentials" \
	--button1text "Get Computers" \
	--button2text "Cancel")
	
	if [ -z "$jamfcreds" ]; then
		exit 0
	fi
	
	URL=$(echo "$jamfcreds" | grep URL | awk -F ': ' {'print $2'})
	username=$(echo "$jamfcreds" | grep Username | awk -F ': ' {'print $2'})
	password=$(echo "$jamfcreds" | grep Password | awk -F ': ' {'print $2'})

	
	# Get username and password encoded in base64 format and stored as a variable in a script:
	encodedCredentials=$( printf "$username:$password" | iconv -t ISO-8859-1 | base64 -i - )
	
	# Use encoded username and password to request a token with an API call and store the output as a variable in a script:
	authToken=$(/usr/bin/curl $URL/api/v1/auth/token --silent --request POST --header "Authorization: Basic ${encodedCredentials}")
	
}

setComputer(){
	computerSelect=$(dialog \
	--title "Jamf LAPS" \
	--titlefont "weight=thin" \
	--selecttitle "ID" \
	--selectvalues "$computerIDValues" \
	--selecttitle "Name" \
	--selectvalues "$computerNameValues" \
	--selecttitle "Serial Number" \
	--selectvalues "$computerSerialValues" \
	--icon "SF=lock.square,colour=purple,colour2=orange,weight=light" \
	--overlayicon "SF=desktopcomputer,palette=black,bgcolor=none" \
	--message "Select a computer using one of the criteria below" \
	--button1text "Get Password" \
	--button2text "Cancel" \
	| grep -v index)
	
	if [ -z "$computerSelect" ]; then
		exit 0
	fi
	numberofArguments=$(($(echo "$computerSelect" | awk -F \" {'print $4'} | sed -e '/^$/d' | wc -l) ))
	if [  "$numberofArguments" = 1 ]; then
		idSelected=$(echo "$computerSelect" | grep ID | awk -F \" {'print $4'})
		nameSelected=$(echo "$computerSelect" | grep Name | awk -F \" {'print $4'})
		serialSelected=$(echo "$computerSelect" | grep Serial | awk -F \" {'print $4'})
		if [ -n "$idSelected" ]; then
			jamfID=$idSelected
		elif [ -n "$nameSelected" ]; then
			for index in ${computerIDList[@]}; do
				if [ "$nameSelected" = "${computerNameList[index]}" ]; then
					jamfID=$index
					break 
				fi
			done
		elif [ -n "$serialSelected" ]; then
			for index in ${computerIDList[@]}; do
				if [ "$serialSelected" = "${computerSerialList[index]}" ]; then
					jamfID=$index
					break 
				fi
			done
		else
			unset jamfID
		fi
	else
		unset jamfID
	fi
}

setComputerError(){
	dialog \
	--title "Jamf LAPS" \
	--titlefont "weight=thin" \
	--selecttitle "ID" \
	--icon "SF=lock.square,colour=purple,colour2=orange,weight=light" \
	--overlayicon "SF=exclamationmark.triangle.fill,palette=black,white,yellow,bgcolor=none" \
	--message "$setComputerErrorMessage" \
	--button1text "Try again" \
	--button2text "Cancel"
	errorReturnCode=$?
	if [ $errorReturnCode != 0 ]; then
		exit 0
	else
		setComputer 
	fi
}


errorJamfCreds(){
	dialog \
	--title "Jamf LAPS" \
	--titlefont "weight=thin" \
	--selecttitle "ID" \
	--icon "SF=lock.square,colour=purple,colour2=orange,weight=light" \
	--overlayicon "SF=exclamationmark.triangle.fill,palette=black,white,yellow,bgcolor=none" \
	--message "Those credentials didn't work, please try again" \
	--button1text "Try again" \
	--button2text "Cancel"
	errorReturnCode=$?
	if [ $errorReturnCode != 0 ]; then
		exit 0
	else
		setJamfCreds 
	fi

}

depError(){
	dialog \
	--title "Jamf LAPS" \
	--titlefont "weight=thin" \
	--selecttitle "ID" \
	--icon "SF=lock.square,colour=purple,colour2=orange,weight=light" \
	--overlayicon "SF=exclamationmark.triangle.fill,palette=black,white,yellow,bgcolor=none" \
	--message "${computerNameList[$jamfID]}, ${computerSerialList[$jamfID]}:  \n Mac was not enrolled with Automated Enrollment, and has no LAPs account" \
	--button1text "Quit"
	exit 0
}

passwordError(){
	dialog \
	--title "Jamf LAPS" \
	--titlefont "weight=thin" \
	--selecttitle "ID" \
	--icon "SF=lock.square,colour=purple,colour2=orange,weight=light" \
	--overlayicon "SF=exclamationmark.triangle.fill,palette=black,white,yellow,bgcolor=none" \
	--message "No password found for  \n ${computerNameList[$jamfID]}, ${computerSerialList[$jamfID]}" \
	--button1text "Quit"
	exit 0
}

showPassword(){
	dialog \
	--title "Jamf LAPS" \
	--titlefont "weight=thin" \
	--selecttitle "ID" \
	--icon "SF=lock.square,colour=purple,colour2=orange,weight=light" \
	--overlayicon "SF=checkmark.circle.fill,palette=white,white,green,bgcolor=none" \
	--message "${computerNameList[$jamfID]}, ${computerSerialList[$jamfID]}  \n
Username: $localAccount  \n
Password: $adminPassword" \
	--button1text "Quit"
	exit 0
}

#### Start of Script

getDialog 

setJamfCreds

echo "$authToken"
while [[ "$authToken" = *401* ]] || [ -z "$authToken" ]; do
	errorJamfCreds
done

# Read the output, extract the token information and store the token information as a variable in a script:
token=$( echo $authToken | awk -F \" '{ print $4 }'  | xargs )

# Get a list of all the computers
computerList=$(curl --request GET \
--url $URL/JSSResource/computers \
--header 'accept: application/xml' \
--silent \
--header "Authorization: Bearer $token" | xmllint --xpath "//computer" -)

for computer in $computerList; do
	computerID=$(echo "$computer" | xmllint --xpath "//computer/id/text()" - )
	computerName=$(echo "$computer" | xmllint --xpath "//computer/name/text()" - )
	computerData=$(curl --request GET \
--url $URL/JSSResource/computers/id/$computerID/subset/General \
--header 'accept: application/xml' \
--silent \
--header "Authorization: Bearer $token" )
	computerSerial=$(echo "$computerData" | xmllint --xpath "//serial_number/text()" - )
	computerEnrolledwithDEP=$(echo "$computerData"| xmllint --xpath "//enrolled_via_dep/text()" -)
	computerIDList[$computerID]=$computerID
	computerNameList[$computerID]=$computerName
	computerSerialList[$computerID]=$computerSerial
	computerDEPList[$computerID]=$computerEnrolledwithDEP
done

for computerID in ${computerIDList[@]}; do
	computerIDValues="$computerIDValues,$computerID"
	computerNameValues="$computerNameValues,${computerNameList[$computerID]}"
	computerSerialValues="$computerSerialValues,${computerSerialList[$computerID]}"
done
computerIDValues="${computerIDValues:1}"
computerNameValues="${computerNameValues:1}"
computerSerialValues="${computerSerialValues:1}"
computerList=$(curl --request GET \
--url $URL/JSSResource/computers \
--header 'accept: application/xml' \
--silent \
--header "Authorization: Bearer $token" | xmllint - )


## Use dialog to display a selector for the computer
setComputer

# Check that the computer selection worked and if not, show an error message
while [ -z "$jamfID" ]; do
	if ((  "$numberofArguments" < 1 )); then
		setComputerErrorMessage="Error: No Criteria Selected"
		setComputerError
	elif ((  "$numberofArguments" > 1 )); then
		setComputerErrorMessage="Error: Please choose the computer with one criteria only"
		setComputerError
	else
		setComputerErrorMessage="No computer found"
		setComputerError
	fi
done

if [ "${computerDEPList[$jamfID]}" = "false" ]; then
	depError
fi

managementID=$(curl --request GET \
--url $URL/api/v1/computers-inventory-detail/$jamfID \
--header 'accept: application/json' \
--silent \
--header "Authorization: Bearer $token" | grep managementId | awk -F \" {'print $4'} )

echo $managementID

localAccount=$(curl --request GET \
--url $URL/api/v2/local-admin-password/$managementID/accounts \
--header 'accept: application/json' \
--silent \
--header "Authorization: Bearer $token" | grep username | awk -F \" {'print $4'})

adminPassword=$(curl --request GET \
--url $URL/api/v2/local-admin-password/$managementID/account/$localAccount/password \
--header 'accept: application/json' \
--silent \
--header "Authorization: Bearer $token" | grep password | awk -F \" {'print $4'})

if [ -n "$localAccount" ] && [ -n "$adminPassword" ]; then
	showPassword
else
	passwordError
fi
