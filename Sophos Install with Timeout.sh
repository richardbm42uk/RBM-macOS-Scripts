#!/bin/bash

SOPHOS_DIR="/Users/Shared/Sophos_Install"
SOPHOS_URL="INSTALLURL"
SOPHOS_INSTALL_LOG="/var/log/sophos_install.log"

timeOut=600
counter=0

logIt(){
	echo "$1"
	echo "$(date): $1" >> $SOPHOS_INSTALL_LOG
}

cleanupAndExit(){
	rm -rf $SOPHOS_DIR
	exit $1
}

##### Start of Script

# Create install folder
mkdir $SOPHOS_DIR
cd $SOPHOS_DIR

# Download Sophos Installer

curl -L -O -s "$SOPHOS_URL" >> $SOPHOS_INSTALL_LOG &
curlPID=$!

curlRunning=$(ps aux | grep -c $curlPID)
while (("$curlRunning" > 1 )) && (( $counter < $timeOut )); do
	sleep 1
	counter=$(( $counter + 1 ))
	curlRunning=$(ps aux | grep -c $curlPID)
done

# Check that Sophos downloaded okay
if (( $counter >= $timeOut )); then
	kill -9 $curlPID
	logIt "Installer Failed to download, time out"
	cleanupAndExit 1
else
	if [ ! -e SophosInstall.zip ]; then
		logIt "Installer Failed to download, file doesn't exist"
		cleanupAndExit 1
	else
		logIt "Installer downloaded"
	fi
fi
	
# Unzip Sophos Installer

unzip -o SophosInstall.zip >> $SOPHOS_INSTALL_LOG &
unzipPID=$!

unzipRunning=$(ps aux | grep -c $unzipPID)
while (("$unzipRunning" > 1 )) && (( $counter < $timeOut )); do
	sleep 1
	counter=$(( $counter + 1 ))
	unzipRunning=$(ps aux | grep -c $unzipPID)
done

# Check that Sophos unzipped okay
if (( $counter >= $timeOut )); then
	kill -9 $unzipPID
	logIt "Installer Failed to unzip, time out"
	cleanupAndExit 1
else
	if [ ! -e $SOPHOS_DIR/Sophos\ Installer.app/Contents/MacOS/Sophos\ Installer ]; then
		logIt "Installer Failed to unzip, file doesn't exist"
		cleanupAndExit 1
	else
		logIt "Installer unzipped"
	fi
fi

# Set permissions
chmod a+x $SOPHOS_DIR/Sophos\ Installer.app/Contents/MacOS/Sophos\ Installer
chmod a+x $SOPHOS_DIR/Sophos\ Installer.app/Contents/MacOS/tools/com.sophos.bootstrap.helper

$SOPHOS_DIR/Sophos\ Installer.app/Contents/MacOS/Sophos\ Installer --quiet >> $SOPHOS_INSTALL_LOG &

sleep 5

sophosRunning=$(ps aux | grep ophos | grep -c "Installer")
while (("$sophosRunning" > 1 )) && (( $counter < $timeOut )); do
	sleep 1
	counter=$(( $counter + 1 ))
	sophosRunning=$(ps aux | grep ophos | grep -c "Installer")
done

# Check that Sophos installed okay
if (( $counter >= $timeOut )); then
	installProcesses=$(ps aux | grep ophos | grep "Installer" | awk '{print $2}')
	for installProcess in $installProcesses; do
	kill -9 $installProcess
	done
	logIt "Installer Failed to install, time out"
	cleanupAndExit 1
else
	processArray=($(ps -ax | grep -i sophos | awk '{print$1}'))
	daemonArray=($(launchctl list | grep sophos | awk '{print$1}'))
	if [[ ! ${#daemonArray[@]} > 0 ]] && [[ ! ${#processArray[@]} > 0 ]]; then
		logIt "No Sophos Processes running, installer failed"
		cleanupAndExit 1
	else
		logIt "Installation completed"
	fi
fi

cleanupAndExit 0