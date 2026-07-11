#!/bin/ash

set -e

# Entware tools live in /opt/bin; non-login shells don't get it via
# /etc/profile.d. Source it if missing (same pattern as fluidd/cartographer).
if [ -f /etc/profile.d/entware.sh ]; then
    echo ${PATH} | grep -q /opt || . /etc/profile.d/entware.sh
fi

TMPFILE=$(mktemp)
# delay_image.switch=0: Creality's stock timelapse (restored to ON by every
# factory wipe) parks the head for a frame ~every 30 min, cycling the print
# through paused state — reads as "random pauses". Farm printers have their
# own cameras; re-enable via the printer screen if wanted.
jq \
    '.user_info.self_test_sw = 0 | .user_info.screensaver = 120 | .delay_image.switch = 0' \
    /mnt/UDISK/creality/userdata/config/system_config.json \
    > $TMPFILE
mv $TMPFILE /mnt/UDISK/creality/userdata/config/system_config.json
jq . /mnt/UDISK/creality/userdata/config/system_config.json
