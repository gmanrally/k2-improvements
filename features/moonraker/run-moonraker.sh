#!/bin/sh
set -e

CONF=$(awk -F= '/CONF=/ {print $2}' /etc/init.d/moonraker)
LOG=$(awk -F= '/LOG=/ {print $2}' /etc/init.d/moonraker)

# Match moonraker.init: upload staging on the eMMC, never tmpfs. See the
# comment there for why.
TMPDIR=/mnt/UDISK/tmp/moonraker
export TMPDIR
mkdir -p "${TMPDIR}"

/usr/share/moonraker-env/bin/python \
    /usr/share/moonraker/moonraker.py \
    -v \
    -c ${CONF} \
    -l ${LOG}
