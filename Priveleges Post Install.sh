#!/bin/bash

# postinstall.sh
# Marc Thielemann, 2020/01/21
# Fixed because it was utterly broken by Richard Brown-Martin, 2023/10/31

exitCode=0

helperPath="/Applications/Privileges.app/Contents/XPCServices/PrivilegesXPC.xpc/Contents/Library/LaunchServices/corp.sap.privileges.helper"

if [ -e "$helperPath" ]; then
	echo "Helper Path Exists"
	# create the target directory if needed
	if [ ! -d "/Library/PrivilegedHelperTools" ]; then
		/bin/mkdir -p "/Library/PrivilegedHelperTools"
		/bin/chmod 755 "/Library/PrivilegedHelperTools"
		/usr/sbin/chown -R root:wheel "/Library/PrivilegedHelperTools"
	fi
	
	# move the privileged helper into place
	/bin/cp -f "$helperPath" "/Library/PrivilegedHelperTools"
	
	if [ $? == 0 ]; then
    	echo "Helper copied"
		/bin/chmod 755 "/Library/PrivilegedHelperTools/corp.sap.privileges.helper"
		
		# create the launchd plist
		helperPlistPath="/Library/LaunchDaemons/corp.sap.privileges.helper.plist"
		
		/bin/cat > "$helperPlistPath" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD helperPlistPath 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>corp.sap.privileges.helper</string>
	<key>MachServices</key>
	<dict>
		<key>corp.sap.privileges.helper</key>
		<true/>
	</dict>
	<key>ProgramArguments</key>
	<array>
		<string>/Library/PrivilegedHelperTools/corp.sap.privileges.helper</string>
	</array>
</dict>
</plist>
EOF
		chown root:wheel "$helperPlistPath"
		chmod 644 "$helperPlistPath"
		
		# load the launchd plist only if installing on the boot volume
			saprunning=$(launchctl list | grep "com.sap")
			if [ -n "$saprunning" ]; then
			/bin/launchctl unload "$helperPlistPath"
			fi
			/bin/launchctl load "$helperPlistPath"

		
		# restart the Dock if Privileges is in there. This ensures proper loading
		# of the (updated) Dock tile plug-in
		
		# get the currently logged-in user and go ahead if it's not root
		currentUser=$(stat -f "%Su" /dev/console)
		
		if [ -n "$currentUser" ] && [ "$currentUser" != "root" ]; then
			if [[ -n $(/usr/bin/sudo -u "$currentUser" /usr/bin/defaults read com.apple.dock "persistent-apps" | /usr/bin/grep "/Applications/Privileges.app") ]]; then
				/usr/bin/killall Dock
			fi
		fi
		
		# make sure PrivilegesCLI can be accessed without specifying the full path
		echo "/Applications/Privileges.app/Contents/Resources" > "/private/etc/paths.d/PrivilegesCLI"
		
	else
		exitCode=1
	fi
else
	exitCode=2
fi

exit $exitCode