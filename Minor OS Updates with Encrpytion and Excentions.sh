#!/bin/bash

# macOS Minor Updates 
# By Richard Brown-Martin

# Array of updates to ignore
ignoredupdates=("Sonoma")

# Recon Function
recon(){
	/usr/local/bin/jamf recon
}

# Check if encoded credentials have been passed in
if [ -z "$4" ]; then
	echo "Please run this script and pass in the encrypted username and password generated by Encrypter.sh in parameter \$4"
	exit 1
fi

# Decrypt Credentials
decrypted=$(printf "$encrypt" | base64 -d)
updateUser=$(echo $decrypted | awk -F ":" '{print $1}')
updatePassword=$(echo $decrypted | awk -F ":" '{print $2}')

# Check that user has a secure token
userST=$(fdesetup list --extended | grep $updateUser)
if [ -z "$userST" ]; then
	echo "User $updateUser does not have a Secure Token, aborting"
	exit 1
fi

# Check that the password is valid for user
if [ -n "$(dscl /Local/Default -authonly $updateUser <<< echo "$updatePassword")" ]; then
	echo "Password provided for user $updateUser is not correct"
	exit 1
fi
	
# Get the list of available updates
listOfUpdates=$(softwareupdate -l)

# Check if any software is required and exit if not
updateCount=$(echo "$listOfUpdates" | grep -c Label )
if [ $updateCount == 0 ]; then
	echo "No updates"
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
	echo "Install Complete"
	exit 0
fi

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
	sudo launchctl bootout gui/$(id -u $currentuser)
fi

# Check the architecture as arm64 Macs need Volume Ownership for restart
architecture=$(uname -m)
if [ "$architecture" = "arm64" ]; then
	# Install and restart for arm64 with credentials
	
	# Derminte build for correct credentials
			echo "Installing $update with restart arm64"
			softwareupdate -i "$update" -R --user $updateUser --stdinpass <<< "$updatePassword"
else
	# Install and restart for intel
	echo "Installing $update with restart for intel"
	softwareupdate -i "$update" -R
fi