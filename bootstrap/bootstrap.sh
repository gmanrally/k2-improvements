#!/bin/ash
#
# Bootstrap installer for gmanrally/k2-improvements on a Creality K2 Plus.
#
# Designed to be uploaded as a folder via Fluidd to
# /mnt/UDISK/printer_data/config/bootstrap/ and then run from an SSH session:
#
#   sh /mnt/UDISK/printer_data/config/bootstrap/bootstrap.sh
#
# What it does:
#   1. Installs Entware to /mnt/UDISK/opt (linked from /opt)
#   2. Installs git, curl, jq, unzip, openssh-sftp-server via opkg
#   3. Clones https://github.com/gmanrally/k2-improvements.git into
#      /mnt/UDISK/root/k2-improvements
#   4. Runs features/better-root/install.sh — migrates /root to
#      /mnt/UDISK/root, updates /etc/passwd, creates ~/klipper,
#      ~/klippy-env, ~/printer_data symlinks that downstream install
#      scripts depend on, and LOGS YOU OUT of SSH at the end so the
#      new $HOME takes effect on next login. Mirrors CampbellFabrications's
#      original Bootstrap (V1.1.3.13, Sept 2025) — our earlier bootstrap
#      release accidentally dropped this step, leaving fresh-wipe printers
#      with $HOME=/root and no ~/klipper symlink, which silently broke
#      moonraker + cartographer installs.
#
# After log-out + log-back-in, run one of:
#   sh /mnt/UDISK/root/k2-improvements/no-carto.sh
#   sh /mnt/UDISK/root/k2-improvements/gimme-the-jamin.sh   # if you have a Cartographer probe

set -e

cd "$(dirname "$0")"

unset LD_LIBRARY_PATH
unset LD_PRELOAD

REPO_URL="https://github.com/gmanrally/k2-improvements.git"
REPO_DEST="/mnt/UDISK/root/k2-improvements"

# ---- Step 1: Entware ----

if [ ! -x /opt/bin/opkg ]; then
    echo "## Installing Entware ..."

    rm -rf /opt
    rm -rf /mnt/UDISK/opt
    mkdir -p /mnt/UDISK/opt
    ln -nsf /mnt/UDISK/opt /opt

    for folder in bin etc lib/opkg tmp var/lock; do
        mkdir -p /mnt/UDISK/opt/"$folder"
    done

    chmod 755 ./wget-ssl.py
    URL="https://bin.entware.net/armv7sf-k3.2/installer"

    if ! ./wget-ssl.py "$URL/opkg" -O /opt/bin/opkg; then
        echo "E: failed to fetch opkg from $URL/opkg"
        rm -rf /opt /mnt/UDISK/opt
        exit 1
    fi
    ./wget-ssl.py "$URL/opkg.conf" -O /opt/etc/opkg.conf

    chmod 755 /opt/bin/opkg
    chmod 777 /opt/tmp

    # Place python wget temporarily so opkg can bootstrap wget-ssl
    cp wget-ssl.py /bin/wget

    /opt/bin/opkg update
    /opt/bin/opkg install wget-ssl
    rm -f /bin/wget
    export PATH=/opt/bin:$PATH

    /opt/bin/opkg install entware-opt git git-http curl jq unzip
    /opt/bin/opkg install openssh-sftp-server
    ln -sf /opt/libexec/sftp-server /usr/libexec/sftp-server

    for f in passwd group shells shadow gshadow; do
        if [ -f /etc/$f ]; then
            ln -sf /etc/$f /opt/etc/$f
        else
            [ -f /opt/etc/$f.1 ] && cp /opt/etc/$f.1 /opt/etc/$f
        fi
    done
    [ -f /etc/localtime ] && ln -sf /etc/localtime /opt/etc/localtime

    mkdir -p /etc/profile.d
    echo 'export PATH="/opt/bin:/opt/sbin:$PATH"' > /etc/profile.d/entware.sh

    cp unslung.init /etc/init.d/unslung
    chmod 755 /etc/init.d/unslung
    ln -sf /etc/init.d/unslung /etc/rc.d/S99unslung
    ln -sf /etc/init.d/unslung /etc/rc.d/K01unslung

    echo "## Entware installed."
else
    echo "## Entware already present at /opt/bin/opkg - skipping install."
fi

. /etc/profile.d/entware.sh

# ---- Step 2: Clone the k2-improvements repo ----

mkdir -p "$(dirname "$REPO_DEST")"

if [ -d "$REPO_DEST/.git" ]; then
    echo "## Repo exists at $REPO_DEST - pulling latest"
    git -C "$REPO_DEST" pull --ff-only
else
    echo "## Cloning $REPO_URL into $REPO_DEST"
    git clone "$REPO_URL" "$REPO_DEST"
fi

# ---- Step 3: better-root ----
#
# Migrate /root -> /mnt/UDISK/root and create the symlinks downstream
# install scripts assume exist (~/klipper, ~/klippy-env, ~/printer_data,
# ~/moonraker, ~/moonraker-env). The script self-skips via the
# `grep -qE 'root.*UDISK' /etc/passwd` check if already migrated.
#
# better-root kills the SSH session at the end (via SIGKILL on dropbear)
# so the new $HOME takes effect on the next login. ANY echo after this
# point will NOT be seen by the user — print the next-step instructions
# BEFORE invoking it.
BETTER_ROOT="$REPO_DEST/features/better-root/install.sh"
if [ -x "$BETTER_ROOT" ]; then
    echo
    echo "## Bootstrap entware + clone complete."
    echo "## Step 3 will now run better-root, which will LOG YOU OUT of SSH."
    echo "## After it disconnects you, log back in and run one of:"
    echo "##   sh $REPO_DEST/no-carto.sh           # printers without a Cartographer probe"
    echo "##   sh $REPO_DEST/gimme-the-jamin.sh    # printers with a Cartographer probe"
    echo
    echo "## Running better-root ..."
    sh "$BETTER_ROOT"
else
    echo
    echo "## Bootstrap complete."
    echo "## W: $BETTER_ROOT not found — skipping homedir migration."
    echo "## W: Subsequent install scripts may fail if ~/klipper etc do not exist."
    echo "## Next step - run one of:"
    echo "##   sh $REPO_DEST/no-carto.sh           # printers without a Cartographer probe"
    echo "##   sh $REPO_DEST/gimme-the-jamin.sh    # printers with a Cartographer probe"
fi
