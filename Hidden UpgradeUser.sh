#!/bin/bash

# Make user hidden

dscl . create /Users/upgradeuser IsHidden 1
chflags hidden /Users/upgradeuser

# Make user admin
sudo dscl . -append /groups/admin GroupMembership upgradeuser  
sysadminctl -secureTokenStatus upgradeuser
# Escrow Bootstrap
sudo profiles install -type bootstraptoken -user upgradeuser -password PASSWORD
# Make user standard
dscl . -delete /groups/admin GroupMembership upgradeuser 