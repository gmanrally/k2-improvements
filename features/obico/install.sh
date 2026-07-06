#!/bin/ash

set -e

SCRIPT_DIR="$(readlink -f $(dirname $0))"

# Pin install root — see features/moonraker/install.sh for the diagnosis.
INSTALL_ROOT=/mnt/UDISK/root
mkdir -p "${INSTALL_ROOT}"
export HOME="${INSTALL_ROOT}"
cd "${INSTALL_ROOT}"

# Entware tools live in /opt/bin; non-login shells don't get it via
# /etc/profile.d. Source it if missing (same pattern as fluidd/cartographer).
if [ -f /etc/profile.d/entware.sh ]; then
    echo ${PATH} | grep -q /opt || . /etc/profile.d/entware.sh
fi

git clone https://github.com/jamincollins/moonraker-obico.git
cd moonraker-obico
git checkout k2

export CREALITY_VARIANT=k2

sh ./scripts/install_creality.sh
