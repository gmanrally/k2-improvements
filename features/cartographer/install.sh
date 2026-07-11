#!/bin/ash
set -e

SCRIPT_DIR=$(readlink -f $(dirname ${0}))

# Pin install root — see features/moonraker/install.sh for the diagnosis.
# When invoked from no-carto.sh / gimme-the-jamin.sh this is already set;
# pinning here too makes standalone invocation safe.
INSTALL_ROOT=/mnt/UDISK/root
mkdir -p "${INSTALL_ROOT}"
export HOME="${INSTALL_ROOT}"
cd "${INSTALL_ROOT}"

# Entware tools (git etc) live in /opt/bin, which only login shells get via
# /etc/profile.d. Non-login invocation (ssh 'sh gimme-the-jamin.sh') has a
# bare PATH -> 'git: not found' on fresh installs. Same pattern fluidd's
# install.sh already uses.
if [ -f /etc/profile.d/entware.sh ]; then
    echo ${PATH} | grep -q /opt || . /etc/profile.d/entware.sh
fi

# clone cartographer plugin
if [ ! -d cartographer3d-plugin/.git ]; then
    echo "I: cloning Jacob10383's cartographer plugin"
    if [ -d cartographer3d-plugin ]; then
        rm -rf cartographer3d-plugin
    fi
    git clone https://github.com/Jacob10383/cartographer3d-plugin.git
fi

echo "I: installing python dependencies"
~/klippy-env/bin/pip install --disable-pip-version-check typing_extensions

# ---------------------------------------------------------------------------
# V3-hardware touch-tolerance schema cap patch.
#
# The V4 plugin's [cartographer touch] schema enforces sample_range <= 0.015
# (15 µm). V4 hardware achieves that. V3 hardware has 150-200 µm touch
# variance and CANNOT, so every V3 CARTOGRAPHER_TOUCH_CALIBRATE fails at the
# default. This sed raises the cap to 0.5 mm. Idempotent — re-running on an
# already-patched file does nothing. Safe on V4 hardware (the V4 cfg can
# still use sample_range: 0.015 unchanged).
# ---------------------------------------------------------------------------
CONFIG_FILE=~/cartographer3d-plugin/src/cartographer/interfaces/configuration.py
if [ -f "$CONFIG_FILE" ]; then
    # Old plugin code shape (pydantic Field):
    sed -i 's/sample_range: float = Field(default=0\.015, le=0\.015/sample_range: float = Field(default=0.015, le=0.5/' "$CONFIG_FILE"
    # Current plugin code shape (option() helper, ~line 205 as of 2026-07):
    sed -i '/sample_range: float = option/ s/max=0\.015/max=0.5/' "$CONFIG_FILE"
    if grep -qE 'le=0\.5|max=0\.5' "$CONFIG_FILE"; then
        echo "I: V3-hardware schema cap applied (sample_range max raised 0.015 -> 0.5)"
    else
        echo "W: sample_range schema cap NOT applied - plugin code shape changed again."
        echo "W: V4 hardware is unaffected; V3 touch calibration may fail at default tolerance."
    fi
fi

# create shim to import cartographer into klipper
cat > ~/klipper/klippy/extras/cartographer.py << 'EOF'
import sys
sys.path.insert(0, '/mnt/UDISK/root/cartographer3d-plugin/src')
from cartographer.extra import *
EOF

# check if native USB ACM support is built into kernel
# skip all usb handling(bridge, wrapper, service) if so
if ! zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_USB_ACM=y"; then
    # install usb bridge and wrapper
    mkdir -p /mnt/UDISK/bin
    ln -sf ${SCRIPT_DIR}/usb_bridge /mnt/UDISK/bin/usb_bridge
    chmod +x /mnt/UDISK/bin/usb_bridge
    ln -sf ${SCRIPT_DIR}/usb_bridge_wrapper.sh /mnt/UDISK/bin/cartographer_wrapper.sh
    chmod +x /mnt/UDISK/bin/cartographer_wrapper.sh

    # install service
    ln -sf ${SCRIPT_DIR}/cartographer.init /etc/init.d/cartographer
    ln -sf ${SCRIPT_DIR}/cartographer.init /opt/etc/init.d/S50cartographer
    # Enable for boot autostart (creates /etc/rc.d/S50cartographer -> /etc/init.d/cartographer).
    # Without this the service only runs after this install.sh's `start` line below
    # — first reboot drops /dev/cartographer and Z homing breaks until manual
    # /etc/init.d/cartographer start. Observed on 86D2 2026-06-05 (~15h dark).
    /etc/init.d/cartographer enable
    /etc/init.d/cartographer start
    CARTO_SERIAL="/dev/cartographer"
else
    echo "I: native USB ACM support detected, skipping usb bridge"
    CARTO_SERIAL="/dev/ttyACM0"
fi


# update printer config
python ${SCRIPT_DIR}/alter_config.py
python ${SCRIPT_DIR}/../../scripts/ensure_included.py \
    ~/printer_data/config/custom/main.cfg prtouch_v3.cfg True
python ${SCRIPT_DIR}/../../scripts/ensure_included.py \
    ~/printer_data/config/printer.cfg custom/main.cfg
cp ${SCRIPT_DIR}/cartographer.cfg ~/printer_data/config/custom
# update serial port based on kernel ACM support
sed -i "s|serial: /dev/cartographer|serial: ${CARTO_SERIAL}|g" ~/printer_data/config/custom/cartographer.cfg
python ${SCRIPT_DIR}/../../scripts/ensure_included.py \
    ~/printer_data/config/custom/main.cfg cartographer.cfg

# install klipper patches
ln -sf ${SCRIPT_DIR}/patches/mcu.py ~/klipper/klippy/mcu.py
ln -sf ${SCRIPT_DIR}/patches/serialhdl.py ~/klipper/klippy/serialhdl.py
ln -sf ${SCRIPT_DIR}/patches/clocksync.py ~/klipper/klippy/clocksync.py
ln -sf ${SCRIPT_DIR}/patches/configfile.py ~/klipper/klippy/configfile.py
ln -sf ${SCRIPT_DIR}/patches/homing.py ~/klipper/klippy/extras/homing.py
ln -sf ${SCRIPT_DIR}/patches/temperature_mcu.py ~/klipper/klippy/extras/temperature_mcu.py
rm -f ~/klipper/klippy/extras/bed_mesh.py*
ln -sf ${SCRIPT_DIR}/patches/bed_mesh.py ~/klipper/klippy/extras/bed_mesh.py

# register for updates
if [ -f ~/printer_data/config/moonraker.conf ]; then
    echo "I: registering cartographer update manager"
    mkdir -p ~/printer_data/config/updates
    cp ${SCRIPT_DIR}/update-manager.cfg ~/printer_data/config/updates/cartographer.cfg
    python3 ~/k2-improvements/scripts/moonraker_include.py updates/cartographer.cfg
else
    echo "W: moonraker not found, skipping update manager registration"
fi

# ---------------------------------------------------------------------------
# Install the carto-watchdog cron — self-heals if /dev/cartographer goes
# away (USB blip, usb_bridge daemon crash, etc.). Runs every minute, costs
# <0.1% CPU. Same defence-in-depth pattern as cam-watchdog.
# ---------------------------------------------------------------------------
if ! zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_USB_ACM=y"; then
    cat > /mnt/UDISK/bin/carto-watchdog.sh << 'WATCHDOG'
#!/bin/sh
# Per-minute: if /dev/cartographer is missing OR usb_bridge isn't running,
# restart the cartographer service. Survives bridge crash + USB
# disconnect/reconnect blips that stock cartographer_wrapper.sh doesn't
# notice on its own.
if [ ! -e /dev/cartographer ] || ! pgrep -f '/mnt/UDISK/bin/usb_bridge' >/dev/null 2>&1; then
    /etc/init.d/cartographer start >/dev/null 2>&1
fi
WATCHDOG
    chmod +x /mnt/UDISK/bin/carto-watchdog.sh
    mkdir -p /etc/crontabs
    touch /etc/crontabs/root
    if ! grep -q carto-watchdog /etc/crontabs/root; then
        echo '* * * * * /mnt/UDISK/bin/carto-watchdog.sh' >> /etc/crontabs/root
        (/etc/init.d/cron restart 2>/dev/null || /etc/init.d/crond restart 2>/dev/null) || true
        echo "I: carto-watchdog cron installed"
    fi
fi

echo "I: restarting klipper"
/etc/init.d/klipper restart

