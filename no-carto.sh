#!/bin/ash

set -xe

SCRIPT_DIR=$(readlink -f $(dirname ${0}))

# Pin install root + HOME so every feature install.sh below lands files in
# /mnt/UDISK/root/* regardless of whether `features/better-root` has been
# run yet. Without this, on a fresh wipe $HOME=/root (per /etc/passwd) and
# moonraker/cartographer/fluidd installs land in /root/* while their init
# scripts look in /mnt/UDISK/root/* — silent breakage at first startup.
# Diagnosed 2026-06-29 via an external user report.
INSTALL_ROOT=/mnt/UDISK/root
mkdir -p "${INSTALL_ROOT}"
export HOME="${INSTALL_ROOT}"
cd "${INSTALL_ROOT}"

install_feature() {
    FEATURE=${1}
    if [ ! -f /tmp/${FEATURE} ]; then
        ${SCRIPT_DIR}/features/${FEATURE}/install.sh
        touch /tmp/${FEATURE}
    fi
}

install_feature better-init
install_feature skip-setup
install_feature moonraker
install_feature fluidd
install_feature screws_tilt_adjust
#install_feature cartographer
#install_feature kamp
mkdir -p /tmp/macros
install_feature macros/bed_mesh
install_feature macros/m191
install_feature macros/start_print
install_feature macros/overrides
install_feature webcam-fix
install_feature resonance-tester