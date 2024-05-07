#!/bin/bash

recon(){
	/usr/local/bin/jamf recon
}

# Get the list of available updates
listOfUpdates=$(softwareupdate -l)

# Check if any software is required and exit if not
updateCount=$(echo "$listOfUpdates" | grep -c Label )
if [ $updateCount == 0 ]; then
	echo "No updates"
	exit 0
else
	restartCount=$(echo "$listOfUpdates" | grep -c restart )
	echo " $(($updateCount - $restartCount )) items to install, $restartCount items will not be installed as they require a restart"
fi

# Format the list into an array, separated by *
flatList=$(echo "$listOfUpdates" | xargs)
IFS='*' read -a array <<< "$flatList"

# Set the doRestart Flag to flase
doRestart=false

# Loop though the array
IFS=$'\n'
for item in "${array[@]}"; do
	# Check if the item contains a Label, and skip otherwise
	continue=$(echo "$item" | grep Label)
	if [ -n "$continue" ]; then
		# Grab the Label and if a restart is needed
		label=$(echo "$continue" | sed -e 's/Label: \(.*\)Title.*/\1/' | xargs)
		restartneeded=$(echo "$item" | grep -c restart)
		# If no restart needed, then install the software.
		if [ $restartneeded = 0 ]; then
			echo "Installing $label"
			softwareupdate -i "$label"
		else
			echo "Skipping $label, which requires a restart"
		fi
	fi
done

recon

echo "Install Complete"