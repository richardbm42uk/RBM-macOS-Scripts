#!/bin/bash

# MAU Update by Richard Brown-Martin at Academia.

### HOW TO USE
# To update a specific item, pass argument as $4
# If no argument provided, all updates will be run

# Check if anyone is logged in
currentUser=$(stat -f "%Su" /dev/console | grep -v loginwindow | grep -v root)
if [ -z $currentUser ]; then
	echo "No user logged in"
fi

# Check if the background agent is running, and launch it if not
MUARunning=$(ps aux | grep "Microsoft Update Assistant" | grep -v grep)
MAUHRunning=$(ps aux | grep "com.microsoft.autoupdate.helper" | grep -v grep)

if [ -z "$MAUHRunning" ] || [ -z "$MUARunning" ]; then
	echo "MAU Not running, launching"
	/Library/Application\ Support/Microsoft/MAU2.0/Microsoft\ AutoUpdate.app/Contents/MacOS/Microsoft\ Update\ Assistant.app/Contents/MacOS/Microsoft\ Update\ Assistant --launchByAgent &
fi

# Wait for MAU processes to run, or for 20 second timeout
timeout=20
while [ -z "$MAUHRunning" ] && [ -z "$MUARunning" ] && [ $timeout -le 0 ]; do
	sleep 1
	timeout=$(( $timeout - 1 ))
	MUARunning=$(ps aux | grep "Microsoft Update Assistant" | grep -v grep)
	MAUHRunning=$(ps aux | grep "com.microsoft.autoupdate.helper" | grep -v grep)
done

# Check if MAU is now running, and if so perform updates
if [ -z "$MAUHRunning" ] || [ -z "$MUARunning" ]; then
	if [ -n "$4" ]; then
		echo "MAU now running, starting updates for $4"
		/Library/Application\ Support/Microsoft/MAU2.0/Microsoft\ AutoUpdate.app/Contents/MacOS/msupdate --install -apps $4 > /tmp/msulog.log &
		MSUProcess=$!
	else
		echo "MAU now running, starting updates for all apps"
		/Library/Application\ Support/Microsoft/MAU2.0/Microsoft\ AutoUpdate.app/Contents/MacOS/msupdate --install > /tmp/msulog.log &
		MSUProcess=$!
	fi
else
	echo "MAU did not launch, aborting"
	exit 1
fi

MSURunning=$(ps aux | grep "msupdate" | grep -v grep)
MSUStatus=$(cat "/tmp/msulog.log" | grep -c "Update Assistant: Idle" )

# msupdate may hang or idle, if it does, then it then kill it after 10 minutes
timeout=600
while [ -n "$MSURunning" ] && [ $MSUStatus -eq 0 ] && [ $timeout -gt 0 ]; do
	sleep 10
	timeout=$(( $timeout - 10 ))
	MSURunning=$(ps aux | grep "msupdate" | grep -v grep)
	MSUStatus=$(cat "/tmp/msulog.log" | grep -c "Update Assistant: Idle" )
done

if [ $MSUStatus -gt 0 ]; then
	echo "MS Update went idle, likely no updates to install"
fi

if [ $timeout -le 0 ]; then
	echo "MS Update timed out"	
fi

if [ -n "$MSURunning" ]; then
	echo "MS Update is still running, killing now"
	kill -9 $MSUProcess
	exit 1
fi

cat "/tmp/msulog.log"

