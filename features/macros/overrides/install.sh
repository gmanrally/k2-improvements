#!/bin/ash
set -e

SCRIPT_DIR=$(readlink -f $(dirname ${0}))

test -f ~/printer_data/config/custom/main.cfg || touch ~/printer_data/config/custom/main.cfg

# this file is intended to be user modified
cp -f ${SCRIPT_DIR}/overrides.cfg ~/printer_data/config/custom/overrides.cfg

if ! grep -qE 'include overrides.cfg' ~/printer_data/config/custom/main.cfg; then
    echo '[include overrides.cfg]' >> ~/printer_data/config/custom/main.cfg
fi

# Unlock the chamber temperature ceiling: Creality's patched heaters.py
# silently clamps SET_HEATER_TEMPERATURE to product_param's chamber_temp
# (stock 60). Raise to 80 for high-temp materials. Factory wipes and
# firmware updates reset this file — this install step restores it.
PARAMS_FILE=~/printer_data/config/printer_params.cfg
if [ -f "$PARAMS_FILE" ]; then
    sed -i 's/variable_chamber_temp: 60/variable_chamber_temp: 80/' "$PARAMS_FILE"
    grep -q 'variable_chamber_temp: 80' "$PARAMS_FILE"         && echo "I: chamber temp ceiling unlocked (60 -> 80)"         || echo "W: chamber ceiling not raised - printer_params.cfg format changed?"
fi

/etc/init.d/klipper restart
