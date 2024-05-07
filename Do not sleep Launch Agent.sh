#!/bin/bash

cat << "EOF" > /Library/LaunchAgents/uk.ac.ed.eca.doNotSleep.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
		<string>uk.ac.ed.eca.doNotSleep</string>
	<key>RunAtLoad</key>
		<true/>
	<key>ProgramArguments</key>
		<array>
			<string>caffeinate</string>
			<string>-dimsu</string>
		</array>
</dict>
</plist>
EOF

chown root:wheel /Library/LaunchAgents/uk.ac.ed.eca.doNotSleep.plist
chmod 644 /Library/LaunchAgents/uk.ac.ed.eca.doNotSleep.plist