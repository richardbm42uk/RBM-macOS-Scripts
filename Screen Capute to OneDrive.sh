#!/bin/bash

mkdir -p /Library/Management/

cat << "EOF" > "/Library/Management/ScreenCapture.sh"
#!/bin/bash
currentuser=$(stat -f "%Su" /dev/console)

OneDrivePath=$(defaults read "/Users/$currentuser/Library/Group Containers/UBF8T346G9.OfficeOneDriveSyncIntegration/Library/Preferences/UBF8T346G9.OfficeOneDriveSyncIntegration.plist" | grep MountPoint | grep -v Shared | awk -F \" '{print $2}' )
OneDriveCount=$(( $(echo "$OneDrivePath" | wc -l ) ))

echo "$OneDrivePath, $OneDriveCount"

if (( $OneDriveCount == 1 )); then 
	if [ -e "$OneDrivePath" ]; then
	echo "Setting Path to OneDrive"
	defaults write /Users/$currentuser/Library/Preferences/com.apple.screencapture.plist location "$OneDrivePath"
		defaults write /Users/$currentuser/Library/Preferences/com.apple.screencapture.plist target file
	else
	echo "Failed to find path to OneDrive, using Desktop"
	defaults write /Users/$currentuser/Library/Preferences/com.apple.screencapture.plist location "~/Desktop"
	defaults write /Users/$currentuser/Library/Preferences/com.apple.screencapture.plist target file
	fi
else
	echo "Failed to find path to OneDrive, using Desktop"
	defaults write /Users/$currentuser/Library/Preferences/com.apple.screencapture.plist location "~/Desktop"
	defaults write /Users/$currentuser/Library/Preferences/com.apple.screencapture.plist target file
fi

chown $currentuser:staff /Users/$currentuser/Library/Preferences/com.apple.screencapture.plist
chmod 700 /Users/$currentuser/Library/Preferences/com.apple.screencapture.plist

EOF

cat << EOF > "/Library/LaunchAgents/uk.ac.exeter.screencapture.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
		<string>uk.ac.exeter.screencapture</string>
	<key>RunAtLoad</key>
		<true/>
	<key>ProgramArguments</key>
		<array>
			<string>/Library/Management/ScreenCapture.sh</string>
		</array>
</dict>
</plist>
EOF

chown root:wheel "/Library/LaunchAgents/uk.ac.exeter.screencapture.plist"
chmod 644 /Library/Management/ScreenCapture.sh 

chown root:wheel "/Library/Management/ScreenCapture.sh"
chmod 755 "/Library/Management/ScreenCapture.sh"
chmod +x "/Library/Management/ScreenCapture.sh"

currentuser=$(stat -f "%Su" /dev/console)
uid=$(id -u "$currentuser")
launchctl asuser $uid launchctl load /Library/LaunchAgents/uk.ac.exeter.screencapture.plist
/Library/Management/ScreenCapture.sh 
