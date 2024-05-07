#!/bin/bash

mistinstalled=$(which mist)
if [  -z "$mistinstalled" ]; then
	curl -L -o /tmp/mist.pkg https://github.com/ninxsoft/mist-cli/releases/download/v2.0/mist-cli.2.0.pkg
	installer -pkg /tmp/mist.pkg -target /
fi

if [ ! -e "/Applications/Install macOS Ventura.app" ]; then
mist download installer Ventura application -o /Applications --application-name "Install macOS Ventura.app"
fi

# Force logout any users
currentuser=$(stat -f "%Su" /dev/console | grep -v loginwindow | grep -v root)
if [ -n "$currentuser" ]; then
	echo "User $currentuser is logged in, booting out"
	sudo launchctl bootout gui/$(id -u $currentuser)
fi

"/Applications/Install macOS Ventura.app/Contents/Resources/startosinstall" --eraseinstall --agreetolicense --user ecasupport --stdinpass <<< 'PASSWORD'