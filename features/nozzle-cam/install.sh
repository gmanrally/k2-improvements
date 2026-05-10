#!/bin/ash
set -e

SCRIPT_DIR=$(readlink -f $(dirname ${0}))

# Entware on PATH for opkg / ffmpeg
[ -f /etc/profile.d/entware.sh ] && . /etc/profile.d/entware.sh

if [ ! -x /opt/bin/opkg ]; then
    echo "E: entware required (run features/entware/install.sh first)"
    exit 1
fi

if [ ! -x /opt/bin/ffmpeg ]; then
    echo "## Installing ffmpeg via entware ..."
    /opt/bin/opkg update
    /opt/bin/opkg install ffmpeg
fi

# Toggle script (PATH includes /mnt/UDISK/bin via better-init)
mkdir -p /mnt/UDISK/bin
ln -sf ${SCRIPT_DIR}/nozzle-cam.sh /mnt/UDISK/bin/nozzle-cam.sh

# Klipper extra
ln -sf ${SCRIPT_DIR}/gcode_shell_command.py \
    ~/klipper/klippy/extras/gcode_shell_command.py

# Macro config (project convention: drop in custom/, register in custom/main.cfg)
test -d ~/printer_data/config/custom || mkdir -p ~/printer_data/config/custom
ln -sf ${SCRIPT_DIR}/nozzle_cam.cfg \
    ~/printer_data/config/custom/nozzle_cam.cfg
python ${SCRIPT_DIR}/../../scripts/ensure_included.py \
    ~/printer_data/config/custom/main.cfg \
    nozzle_cam.cfg

/etc/init.d/klipper restart

echo
echo "## nozzle-cam installed."
echo "## In Fluidd console: NOZZLE_CAM_ON / NOZZLE_CAM_OFF"
echo "## Stream: http://<printer-ip>:8081/  (auto-off after 10 min)"
