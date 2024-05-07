#!/bin/bash

# Install Mount Home folder script and Launch Agent

# Install the finder sidebar tool
sudo -H pip3 install finder-sidebar-editor 

# Create the script
mkdir -p /Library/Management/Scripts
cat << "END" > /Library/Management/Scripts/mountusernetworkhome.sh
#!/bin/bash
## Mount User Network Home and add it to sidebar
#Get username of logged in user
User_Name=$(stat -f "%Su" /dev/console)
echo "$(date) User $User_Name Logging in" >> /Users/${User_Name}/Library/Logs/mountadhome.log
# Get AD entry for user
adEntry=$(dscl /Active\ Directory/ED/All\ Domains -read /Users/$User_Name)
Home_Path=$(echo "$adEntry" | grep "NFSHomeDirectory" | grep '/Users/' | awk '{print $2}')
Network_Home="$(echo "$adEntry" | grep "SMBHome" | grep -v SMBHomeDrive | awk '{print $2}' | tr '\' '/')"
# Quit if user isn't an AD User
if [ -z "$Home_Path" ] || [ -z "$Network_Home" ]; then
	echo "$(date) User $User_Name is not an AD user, aborting" >> /Users/${User_Name}/Library/Logs/mountadhome.log
	exit 0
fi
echo "$(date) User $User_Name is an AD user, continuing" >> /Users/${User_Name}/Library/Logs/mountadhome.log
# Break down and reformat the home path
homeServer=$(echo "$Network_Home" | awk -F "/" '{print $2}') 
homeSharePoint=$(echo "$Network_Home" | awk -F "/" '{print $NF}') 
homePath=$(echo "$Network_Home" | awk -F "/" '{for(i=4;i<=NF;i++) print $i}') 
homeSharePath=`echo $homePath | tr ' ' '/'`
script_args="mount volume \"smb:$Network_Home\""
# Define the completed path from which to create the sidebar shortcut
share="/Volumes/${homeSharePoint}"
if [  ! -e /Users/${User_Name}/Library/Management/Scripts ]; then
	mkdir -p /Users/${User_Name}/Library/Management/Scripts
fi
# Write the Pyton Script to add to the sidebar
cat << EOF > /Users/${User_Name}/Library/Management/Scripts/addNetworkHomeToSideBar.py
import sys
sys.path.append('/usr/local/python3')
from finder_sidebar_editor import FinderSidebar
sidebar = FinderSidebar()
sidebar.add("/Volumes/${homeSharePoint}")
EOF
# Check sidebartool is installed
sidebartoolinstalled=$(pip3 list | grep finder-sidebar-editor)
if [ -z "$sidebartoolinstalled" ]; then
	echo "$(date) Installing Python tool" >> /Users/${User_Name}/Library/Logs/mountadhome.log
	pip3 install finder-sidebar-editor 
fi
# Mount the Home Folder
if [ ! -d /Volumes/${homeSharePoint} ]; then
	script_args="mount volume \"smb:$Network_Home\""
	# If the home volume is unavailable take 2 attempts at (re)mounting it
	tries=0
	while ! [ -d /Volumes/${homeSharePoint} ] && [ ${tries} -lt 2 ];
	do
		echo "$(date) Mouting User Network Home, attempt $tries" >> /Users/${User_Name}/Library/Logs/mountadhome.log
		tries=$((${tries}+1))
		osascript -e "{$script_args}"
		sleep 5
	done
fi
if [ -d /Volumes/${homeSharePoint} ]; then
	echo "$(date) User Network Home mounted, adding to sidebar" >> /Users/${User_Name}/Library/Logs/mountadhome.log
	# Run the python script to add the home folder to the sidebar
	python3 /Users/${User_Name}/Library/Management/Scripts/addNetworkHomeToSideBar.py
fi
END

# Create the launch agent
cat << "END" > /Library/LaunchAgents/uk.ac.ed.eca.mountusernetworkhome.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>Label</key>
<string>uk.ac.ed.eca.mountusernetworkhome</string>
<key>ProgramArguments</key>
<array>
<string>/Library/Management/Scripts/mountusernetworkhome.sh</string>
</array>
<key>RunAtLoad</key>
<true/>
</dict>
</plist>
END

chown root:wheel "/Library/Management/Scripts/mountusernetworkhome.sh"
chmod 755 "/Library/Management/Scripts/mountusernetworkhome.sh"

chown root:wheel "/Library/LaunchAgents/uk.ac.ed.eca.mountusernetworkhome.plist"
chmod 644 "/Library/LaunchAgents/uk.ac.ed.eca.mountusernetworkhome.plist"

currentuser=$(stat -f "%Su" /dev/console)
uid=$(id -u "$currentuser")
launchctl asuser $uid launchctl unload /Library/LaunchAgents/uk.ac.ed.eca.mountusernetworkhome.plist
launchctl asuser $uid launchctl load /Library/LaunchAgents/uk.ac.ed.eca.mountusernetworkhome.plist