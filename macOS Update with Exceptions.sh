#!/bin/bash

# Array of updates to ignore
ignoredupdates=("Sonoma")

recon(){
	/usr/local/bin/jamf recon
}

# Get the list of available updates
listOfUpdates=$(softwareupdate -l)

# Check if any software is required and exit if not
updateCount=$(echo "$listOfUpdates" | grep -c Label )
if [ $updateCount == 0 ]; then
	echo "No updates"
	rm /Library/Preferences/uk.ac.ed.eca.kextreboot.flag
	recon
	exit 0
else
	echo "$updateCount items to install"
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
				echo "Ignoring $label"
				ignoreItem=1
			fi
		done
		if [ $ignoreItem == 0 ]; then
			restartneeded=$(echo "$item" | grep -c restart)
			# If no restart needed, then install the software, otherwise set the doRestart Flag to true
			if [ $restartneeded = 0 ]; then
				echo "Installing $label"
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
	echo "Install Complete"
	exit 0
fi

# Set a flag to perform a kext reboot and then recon
touch /Library/Preferences/uk.ac.ed.eca.kextreboot.flag
recon

# Download any other updates
echo "Downloading Software Updates"
for update in ${restartLabels[@]}; do
echo "Downloading $update"
softwareupdate -d "$update"
done

# Force logout any users
currentuser=$(stat -f "%Su" /dev/console | grep -v loginwindow | grep -v root)
if [ -n "$currentuser" ]; then
	echo "User $currentuser is logged in, booting out"
	#sudo launchctl bootout gui/$(id -u $currentuser)
fi

# Check the architecture as arm64 Macs need Volume Ownership for restart
architecture=$(uname -m)
if [ "$architecture" = "arm64" ]; then
	# Install and restart for arm64 with credentials
	
	# Derminte build for correct credentials
	buildType=$(defaults read "/Library/Preferences/uk.ac.ed.eca.build.plist" Build)
	case $buildType in
		ECA*)
			echo "Installing $update with restart for ECA arm64"
			softwareupdate -i "$update" -R --user ecasupport --stdinpass <<< '133V!!zp8qhn'
		;;
		EDUC*)
			echo "Installing $update with restart for EDUC arm64"
			softwareupdate -i "$update" -R --user educsupport --stdinpass <<< '8A8OxqJ$hU*q'
		;;
		*)
			echo "Installing $update with restart for Unknown build arm64"
			softwareupdate -i "$update" -R --user ecasupport --stdinpass <<< '133V!!zp8qhn'
		;;
	esac
else
	# Install and restart for intel
	echo "Installing $update with restart for intel"
	softwareupdate -i "$update" -R
fi