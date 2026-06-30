#!/bin/sh
set -e

SCRIPT_DIR=$(readlink -f $(dirname ${0}))
TARGET=/usr/bin/auto_uvc.sh

if [ ! -f "$TARGET" ]; then
    echo "W: $TARGET not found — skipping webcam-fix"
    exit 0
fi

# Back up original (only on first run, to preserve true original state)
if [ ! -f "${TARGET}.bak" ]; then
    cp "$TARGET" "${TARGET}.bak"
    echo "Original $TARGET backed up to ${TARGET}.bak"
fi

# If $TARGET is a symlink (e.g. from a previous run of this script when it
# used to symlink in a whole replacement), restore from .bak first so we
# sed-modify a real file the user actually has, not our shipped variant
# that may be incompatible with their firmware's cam_app.
if [ -L "$TARGET" ]; then
    rm -f "$TARGET"
    cp "${TARGET}.bak" "$TARGET"
    chmod +x "$TARGET"
    echo "Removed old symlink; restored real file from .bak so we sed in place."
fi

# The whole point of webcam-fix is to change MAIN_PIC_FPS=15 to 30 so the
# main camera streams at 30fps instead of the stock 15. Earlier versions of
# this feature shipped a wholesale-replacement auto_uvc.sh, which broke
# cameras on K2 firmware variants whose cam_app has different CLI flags.
# Surgical in-place sed leaves every other firmware-specific quirk intact.
if grep -qE '^MAIN_PIC_FPS=15$' "$TARGET"; then
    sed -i 's/^MAIN_PIC_FPS=15$/MAIN_PIC_FPS=30/' "$TARGET"
    echo "auto_uvc.sh: MAIN_PIC_FPS bumped 15 -> 30 (in-place)"
elif grep -qE '^MAIN_PIC_FPS=30$' "$TARGET"; then
    echo "auto_uvc.sh: already at MAIN_PIC_FPS=30 — no change needed"
else
    echo "W: $TARGET does not have an 'MAIN_PIC_FPS=15' line — skipping FPS bump."
    echo "W: Your firmware may use a different camera config mechanism."
fi
