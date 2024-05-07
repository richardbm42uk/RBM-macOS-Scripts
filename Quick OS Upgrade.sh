#!/bin/bash

### macOS Upgrader - Simple version

## Static variables

# OS to install
osName=Ventura
authUser=SOMEUSERWITHDISKOWNERSHIP
authPass=PASSWORDOFUSER

#### Functions

failAndQuit(){
	if [ -n "$1" ]; then
		echo  "$1"
	fi
	echo "Error, aborting"
	exit 1
}

getMist(){
	mkdir /tmp/mist
	curl -o /tmp/mist/mist.pkg  -L 'https://github.com/ninxsoft/mist-cli/releases/download/v1.14/mist-cli.1.14.pkg'
	installer -pkg /tmp/mist/mist.pkg -target /
}

downloadmacOSInstaller(){
	installerName="Install macOS $osName.app"
	mist download installer "$osName" application --application-name "$installerName" --output-directory /Applications --temporary-directory /tmp/mist/ -q
	downloadOkay=$?
	if [ "$downloadOkay" == 0 ]; then
		echo "macOS $osName downloaded"
	else
		failAndQuit "macOS $osName failed to download"
	fi
}

checkDisk(){
	if [ -n "$(sudo diskutil verifyVolume / | grep "File system check exit code is 0" )" ]; then
		echo "✅ Boot Volume verified"
	else
		echo "❌ Boot Volume verification failed"
		failAndQuit "Boot Volume failed to verify and may be corrupted \n Please contact IT"
	fi
}

getInstallerSize(){
	case $osName in 
		Monterey) 
			installerSpaceRequired=12157035487
		;;
		Ventura) 
			installerSpaceRequired=12159754550
		;;
		Sonoma) 
			installerSpaceRequired=12159754550
		;;
		*) 
			failAndQuit "Unknown OS version. Update the script!"
			
		;;
	esac
}

checkSpace(){
	availableSpace=$(diskutil info / | grep Free | awk '{print $6}' | tr -d \(\) )
	if [ -z $availableSpace ]; then
		echo "Available space could not be determined"
		failAndQuit "Available space could not be determined"
	else
		echo "Available space: $(( $availableSpace / 1024 / 1024 / 1024)) GB"
	fi
	getInstallerSize
	requiredSpace=$(($installerSpaceRequired * 25 / 10))
	if (( $availableSpace > $requiredSpace )); then
		echo  "✅ $(( $requiredSpace / 1024 / 1024 / 1024 )) GB required"
	else
		extraSpaceRequired=$(( $requiredSpace - $availableSpace ))
		echo  "❌ Additional $(( extraSpaceRequired / 1024 / 1024 / 1024 )) GB required"
		failAndQuit "Not enough available storage.\n An additional $(( extraSpaceRequired / 1024 / 1024 / 1024 )) GB is required \n Ensure $requiredSpace is available before trying again."
	fi
}


#Start of script

# Check requirements
checkSpace
checkDisk 

# Get Mist downloader
getMist

# Use Mist to download selected OS
downloadmacOSInstaller 

# Install using the appropriate command for the Architecture
architecture=$(uname -m)

case $architecture in
	arm64)
		echo "Starting install of macOS $osName for arm64"
		"/Applications/Install macOS $osName.app/Contents/Resources/startosinstall" --agreetolicense --forcequitapps --nointeraction --user "$authUser" <<< "$authPass"
	;;
	x86_64)
		echo "Starting install of macOS $osName for x86_64"
		"/Applications/Install macOS $osName.app/Contents/Resources/startosinstall" --agreetolicense --forcequitapps --nointeraction
	;;
	*)
		failAndQuit "Architecture unknown"
	;;
esac
		