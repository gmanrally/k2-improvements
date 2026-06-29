#!/bin/ash
set -e

# DEPENDS: moonraker
if [ ! -f /mnt/UDISK/root/printer_data/config/moonraker.conf ]; then
    echo "E: you must have updated moonraker first!"
    exit 1
fi

SCRIPT_DIR=$(readlink -f $(dirname ${0}))

# Pin install root — see features/moonraker/install.sh for the diagnosis.
# Without this, on a fresh wipe $HOME=/root and the `ln -sf ~/fluidd
# /usr/share/fluidd` below would symlink to /root/fluidd, then break when
# anything else looks for it at /mnt/UDISK/root/fluidd.
INSTALL_ROOT=/mnt/UDISK/root
mkdir -p "${INSTALL_ROOT}"
export HOME="${INSTALL_ROOT}"
cd "${INSTALL_ROOT}"

# MUST have Entware installed
if [ ! -f /opt/bin/opkg ]; then
    echo "E: you must have entware installed!"
    exit 1
fi

# handle entware being installed in the current login
if [ -f /etc/profile.d/entware.sh ]; then
    echo ${PATH} | grep -q /opt || source /etc/profile.d/entware.sh
fi

if ! type -p unzip > /dev/null; then
    opkg install unzip
fi

rm -fr fluidd

mkdir -p fluidd
cd fluidd
python3 ${SCRIPT_DIR}/get_latest_release.py Jacob10383/fluidd
unzip fluidd.zip
rm -f fluidd.zip
cd ..

# replace the existing Fluidd
rm -fr /usr/share/fluidd
ln -sf ~/fluidd /usr/share/fluidd

# restart nginx
/etc/init.d/nginx restart
# register for updates
mkdir -p ~/printer_data/config/updates
cp ${SCRIPT_DIR}/update-manager.cfg ~/printer_data/config/updates/fluidd.cfg
python3 ~/k2-improvements/scripts/moonraker_include.py updates/fluidd.cfg

# TODO: should this should be gated on a port check?
# wait for everything to be ready
sleep 5
python3 ${SCRIPT_DIR}/create_camera.py

/etc/init.d/moonraker restart
