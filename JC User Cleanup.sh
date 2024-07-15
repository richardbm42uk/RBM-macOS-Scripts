#!/bin/bash

# User Cleanup

# Max days before cleanup
maxdays=28

# Define "safe user" accounts to always keep
safeUsers=("root" "Shared" "academia" "admin" "educsupport" ".localized" "loginwindow")

## Start of script

# Get the current user folders
userList=$(ls /Users)
# Remove "safe user" accounts from the list 
for safeUser in ${safeUsers[@]}; do
	userList=$(echo "$userList" | grep -v "$safeUser")
done
# Remove any non-Jamf Connect local accounts from the list 
for someUser in $userList; do
		isJCUser=$(dscl . read /Users/$someUser | grep OIDC)
		if [ -z "$isJCUser" ]; then
				echo "Ignoring $someUser, UID: $userID - not an JC user"
				userList=$(echo "$userList" | grep -v "$someUser")
		fi
done

if [ -z "$userList" ]; then
	echo "No JC users present, exiting"
	exit 0
fi

todayDate=$(date +%s)

# Remove any users that have accessed in the past 28 days from the list
for someUser in $userList; do
	lastAccessDate=$(stat -f "%Sa" /Users/$someUser)
	lastAccessEpoch=$(date -j -f "%b %d %T %Y" "$lastAccessDate" +%s)
	daysSinceLastLogin=$(( ($todayDate - $lastAccessEpoch) / 86400  ))
	if (( $daysSinceLastLogin < $maxdays )); then
		echo "Ignoring $someUser, folder modified $daysSinceLastLogin days ago"
		userList=$(echo "$userList" | grep -v "$someUser")
	fi
done

# Remove any users that have files modified in the last 28 days from the list
for someUser in $userList; do
	newFiles=$(mdfind "kMDItemFSContentChangeDate > \$time.today(-$maxdays) || kMDItemFSCreationDate > \$time.today(-$maxdays)" -onlyin /Users/$thisUser -count)
	if [ $newFiles -gt 0 ]; then
		echo "Ignoring $someUser, files modified within the last $maxdays"
		userList=$(echo "$userList" | grep -v "$someUser")
	fi
done

# Delete any users remaining in the list
for someUser in $userList; do
	lastAccessDate=$(stat -f "%Sa" /Users/$someUser)
	echo "Deleting user $someUser, last modified date $lastAccessDate"
	systemadminctl -deleteuser $someUser
	userExists=$(dscl . read /Users/$someUser)
	if [ -z "userExists" ]; then
		echo "User $someUser successfully deleted"
	else
		echo "User $someUser not deleted, removing with dscl"
		dscl . -delete /Users/$someUser
	fi
	if [ -e "/Users/$someUser" ]; then
		echo "User $someUser home folder successfully deleted"
	else
		echo "User $someUser home folder not deleted, removing with rm"
		rm -r /Users/$someUser
	fi
done