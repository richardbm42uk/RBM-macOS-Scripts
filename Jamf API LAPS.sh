#!/bin/bash

### Jamf API to set computer name from Asset Tag

# Jamf Pro URL and Credentials
URL="JAMFURL"
username="APIUSER"
password="APIPASS"


### If running via policy, grab the serial for the Mac we're running on

#serial=$(/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | /usr/bin/awk -F'"' '/IOPlatformSerialNumber/{print $4}')
serial=SERIAL

xpath() {
	if [[ $(sw_vers -buildVersion) > "20A" ]]; then
		/usr/bin/xpath -e "$@"
	else
		/usr/bin/xpath "$@"
	fi
}


#### Start of Script

# Get username and password encoded in base64 format and stored as a variable in a script:
encodedCredentials=$( printf "$username:$password" | iconv -t ISO-8859-1 | base64 -i - )

# Use encoded username and password to request a token with an API call and store the output as a variable in a script:
authToken=$(/usr/bin/curl $URL/api/v1/auth/token --silent --request POST --header "Authorization: Basic ${encodedCredentials}")

# Read the output, extract the token information and store the token information as a variable in a script:
token=$( echo $authToken | awk -F \" '{ print $4 }'  | xargs )

jamfID=$(curl --request GET \
--url $URL/JSSResource/computers/serialnumber/$serial/subset/General \
--header 'accept: application/xml' \
--silent \
--header "Authorization: Bearer $token" | xmllint --xpath "//computer/general/id/text()" - )

managementID=$(curl --request GET \
--url $URL/api/v1/computers-inventory-detail/$jamfID \
--header 'accept: application/json' \
--silent \
--header "Authorization: Bearer $token" | grep managementId | awk -F \" {'print $4'} )

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

#audit=$(curl --request GET \
#--url $URL/api/v2/local-admin-password/$managementID/account/$localAccount/audit \
#--header 'accept: application/json' \
#--silent \
#--header "Authorization: Bearer $token")

#echo $jamfID
#echo $managementID
echo $localAccount
echo $adminPassword
#echo "$audit"