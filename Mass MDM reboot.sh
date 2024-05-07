#!/bin/bash

# MDM Mass Reboot

URL= #Jamf Pro URL
username= #User
password= #Password
serials="
SERIAL
SERIAL
SERIAL
SERIAL
" #Serials of Mac to reboot

xpath() {
	if [[ $(sw_vers -buildVersion) > "20A" ]]; then
		/usr/bin/xpath -e "$@"
	else
		/usr/bin/xpath "$@"
	fi
}

encodedCredentials=$( printf "$username:$password" | iconv -t ISO-8859-1 | base64 -i - )

authToken=$(/usr/bin/curl $URL/api/v1/auth/token --silent --request POST --header "Authorization: Basic ${encodedCredentials}")
token=$( echo $authToken | awk -F \" '{ print $4 }'  | xargs )

for serial in $serials; do

computerID=$(curl --request GET \
--url $URL/JSSResource/computers/serialnumber/$serial \
--header 'accept: application/xml' \
--silent \
--header "Authorization: Bearer $token" | xmllint --xpath "//computer/general/id/text()" - )

managementID=$(curl --request GET \
--url $URL/api/v1/computers-inventory-detail/$computerID \
--header 'accept: application/json' \
--silent \
--header "Authorization: Bearer $token" | grep managementId | awk -F \" {'print $4'} )

curl --request POST \
--url $URL/api/preview/mdm/commands \
--header "Authorization: Bearer $token" \
--header 'Content-Type: application/json' \
--data-raw "{
	\"clientData\": [
		{
			\"managementId\": \"$managementID\",
			\"clientType\": \"COMPUTER\"
		}
	],
	\"commandData\": {
		\"commandType\": \"RESTART_DEVICE\", 
		\"notifyUser\": \"false\"
	}
}"
	
done