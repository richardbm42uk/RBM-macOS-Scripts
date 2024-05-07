#!/bin/bash

### Jamf API to set the Recovery Lock Password of a Mac
# by Richard Brown-Martin 2023
# For internal use by Academia only

## Jamf Pro URL and Credentials
URL="https://YOURJAMF.jamfcloud.com"
username="YOURJAMFUSERNAME"
password="YOURJAMFPASSWORD"

## Serial to reset - for testing or manual reset
#serial="SERIALNUMBER"
# OR
## Grab the serial for the Mac we're running on
#serial=$(/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | /usr/bin/awk -F'"' '/IOPlatformSerialNumber/{print $4}')

## Password to set Recovery Lock to - leave blank to disable
#recoveryLock=""
# OR
#recoveryLock="SOMEPASSWORD"

#### Start of Script

# Get username and password encoded in base64 format and stored as a variable in a script:
encodedCredentials=$( printf "$username:$password" | iconv -t ISO-8859-1 | base64 -i - )

# Use encoded username and password to request a token with an API call and store the output as a variable in a script:
authToken=$(/usr/bin/curl $URL/api/v1/auth/token --silent --request POST --header "Authorization: Basic ${encodedCredentials}")

# Read the output, extract the token information and store the token information as a variable in a script:
token=$( echo $authToken | awk -F \" '{ print $4 }'  | xargs )

# Use an API call to get the Jamf ID for the Mac
computerID=$(curl --request GET \
--url $URL/JSSResource/computers/serialnumber/$serial \
--header 'accept: application/xml' \
--silent \
--header "Authorization: Bearer $token" | xmllint --xpath "//computer/general/id/text()" - )

# Get the Management ID
managementID=$(curl --request GET \
--url $URL/api/v1/computers-inventory-detail/$computerID \
--header 'accept: application/json' \
--silent \
--header "Authorization: Bearer $token" | grep managementId | awk -F \" '{ print $4 }'  | xargs )

### Send the Set Recovery Lock command
curl --request POST \
--header "Authorization: Bearer $token" \
--url $URL/api/preview/mdm/commands \
--header 'accept: application/json' \
--header 'content-type: application/json' \
--data-raw "{
	\"clientData\": [
		{
			\"managementId\": \"$managementID\",
			\"clientType\": \"COMPUTER\"
		}
	],
	\"commandData\": {
		\"commandType\": \"SET_RECOVERY_LOCK\",
		\"newPassword\": \"$recoveryLock\"
	}
}"
