#!/bin/ash

set -e

# Entware tools live in /opt/bin; non-login shells don't get it via
# /etc/profile.d. Source it if missing (same pattern as fluidd/cartographer).
if [ -f /etc/profile.d/entware.sh ]; then
    echo ${PATH} | grep -q /opt || . /etc/profile.d/entware.sh
fi

TMPFILE=$(mktemp)
jq \
    '.user_info.self_test_sw = 0 | .user_info.screensaver = 120' \
    /mnt/UDISK/creality/userdata/config/system_config.json \
    > $TMPFILE
mv $TMPFILE /mnt/UDISK/creality/userdata/config/system_config.json
jq . /mnt/UDISK/creality/userdata/config/system_config.json
