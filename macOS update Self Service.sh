#!/bin/bash

# Array of updates to ignore
ignoredupdates=("Sonoma")

recon(){
	/usr/local/bin/jamf recon
}

guiLog(){
	echo "message: $1" >> /var/tmp/dialog.log
}

quitandexit(){
	sleep 10
	echo "quit:" >> /var/tmp/dialog.log
	exit $1
}

# Launch Dialog
dialog --title "macOS Updates" --message "Update Started" --moveable --position topright --progress --mini --icon "/System/Library/PrivateFrameworks/SoftwareUpdate.framework/Versions/A/Resources/SoftwareUpdate.icns" &

# Get the list of available updates
listOfUpdates=$(softwareupdate -l)

# Check if any software is required and exit if not
updateCount=$(echo "$listOfUpdates" | grep -c Label )
if [ $updateCount == 0 ]; then
	guiLog "No updates available"
	quitandexit 0
else
	guiLog "$updateCount items to install"
fi

# Format the list into an array, separated by *
flatList=$(echo "$listOfUpdates" | xargs)
IFS='*' read -a array <<< "$flatList"

# Set the doRestart Flag to flase
doRestart=false
declare -a $restartLabels

# Loop though the array
IFS=$'\n'
for item in "${array[@]}"; do
	ignoreItem=0
	# Check if the item contains a Label, and skip otherwise
	continue=$(echo "$item" | grep Label)
	if [ -n "$continue" ]; then
		# Grab the Label and if a restart is needed
		label=$(echo "$continue" | sed -e 's/Label: \(.*\)Title.*/\1/' | xargs)
		for ignore in "${ignoredupdates[@]}"; do
			shouldIgnore=$(echo "$item" | grep "$ignore")
			if [ -n "$shouldIgnore" ]; then
				guiLog "Ignoring $label"
				ignoreItem=1
			fi
		done
		if [ $ignoreItem == 0 ]; then
			restartneeded=$(echo "$item" | grep -c restart)
			# If no restart needed, then install the software, otherwise set the doRestart Flag to true
			if [ $restartneeded = 0 ]; then
				guiLog "Installing $label"
				softwareupdate -i "$label"
			else
				restartLabels+=($label)
				doRestart=true
			fi
		fi
	fi
done

# If the doRestart flag is false, then everything is done, exit, otherwise continue
if [ "$doRestart" == false ]; then
	rm /Library/Preferences/uk.ac.ed.eca.kextreboot.flag
	recon
	guiLog "Install Complete"
	quitandexit 0
fi

# Set a flag to perform a kext reboot and then recon
touch /Library/Preferences/uk.ac.ed.eca.kextreboot.flag
recon

# Download any other updates
guiLog "Downloading Software Updates"
for update in ${restartLabels[@]}; do
guiLog "Downloading $update"
softwareupdate -d "$update"
done

## Force logout any users
#currentuser=$(stat -f "%Su" /dev/console | grep -v loginwindow | grep -v root)
#if [ -n "$currentuser" ]; then
#	guiLog "User $currentuser is logged in, booting out"
#	#sudo launchctl bootout gui/$(id -u $currentuser)
#fi

# Check the architecture as arm64 Macs need Volume Ownership for restart
architecture=$(uname -m)
if [ "$architecture" = "arm64" ]; then
	# Install and restart for arm64 with credentials
	
	# Derminte build for correct credentials
	guiLog  "Installing $update with restart Apple Silicon"
	softwareupdate -i "$update" -R --user USER --stdinpass <<< 'USERPASSWORD'
else
	# Install and restart for intel
	guiLog "Installing $update with restart for Intel"
	softwareupdate -i "$update" -R
fi

guiLog "Updates Complete"
quitandexit