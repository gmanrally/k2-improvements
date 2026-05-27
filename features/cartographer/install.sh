#!/bin/ash
set -e

SCRIPT_DIR=$(readlink -f $(dirname ${0}))

cd ${HOME}

# clone cartographer plugin
if [ ! -d cartographer3d-plugin/.git ]; then
    echo "I: cloning Jacob10383's cartographer plugin"
    if [ -d cartographer3d-plugin ]; then
        rm -rf cartographer3d-plugin
    fi
    git clone https://github.com/Jacob10383/cartographer3d-plugin.git
fi

# Patch the V4 plugin's sample_range schema cap so V3 hardware (which has
# wider touch-sample variance) can be configured with V3-equivalent
# tolerances (~200um). Upstream caps sample_range at 0.015mm (15um);
# we raise to 0.5mm to allow up to V3's 200um default.
# Idempotent: only patches if the original constraint string is found.
PLUGIN_CFG=${HOME}/cartographer3d-plugin/src/cartographer/interfaces/configuration.py
if [ -f "$PLUGIN_CFG" ] && grep -q 'sample_range:.*max=0.015' "$PLUGIN_CFG"; then
    echo "I: patching V4 plugin sample_range cap for V3-hardware compatibility"
    sed -i 's/sample_range: float = option("Acceptable range (in mm) between touch samples.", default=0.010, min=0.001, max=0.015)/sample_range: float = option("Acceptable range (in mm) between touch samples.", default=0.010, min=0.001, max=0.5)/' "$PLUGIN_CFG"
fi

# Apply upstream Cartographer3D/cartographer3d-plugin PR #480 — "fix:
# improve bed mesh scan robustness". Fixes the "Grid point (X,Y) has
# no valid samples" failure where corner grid cells used an asymmetric
# 100x smaller capture radius (epsilon=0.01) than interior cells
# (max_distance=1.0). Jacob10383's fork (which we clone) lags upstream
# and didn't have this fix at install-time. Idempotent.
PLUGIN_HELPERS=${HOME}/cartographer3d-plugin/src/cartographer/macros/bed_mesh/helpers.py
if [ -f "$PLUGIN_HELPERS" ] && grep -q 'if not self.grid.contains_point((x, y)):' "$PLUGIN_HELPERS"; then
    echo "I: applying PR #480 mesh-binning fix"
    sed -i 's|if not self.grid.contains_point((x, y)):|if not self.grid.contains_point((x, y), epsilon=self.max_distance):|' "$PLUGIN_HELPERS"
fi

echo "I: installing python dependencies"
~/klippy-env/bin/pip install --disable-pip-version-check typing_extensions

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

echo "I: restarting klipper"
/etc/init.d/klipper restart

