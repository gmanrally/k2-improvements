# bootstrap

Self-contained installer that runs once per printer to lay down Entware
and clone the `gmanrally/k2-improvements` repo onto a freshly-flashed
Creality K2 Plus.

## Files

- `bootstrap.sh` — orchestrator; installs Entware then clones the repo into
  `/mnt/UDISK/root/k2-improvements`.
- `wget-ssl.py` — Python-based HTTPS fetcher. Stock K2 Plus firmware has no
  `wget` / `curl`, so this provides the seed download path before opkg is
  available to install the real `wget-ssl`.
- `unslung.init` — Entware startup procd script, copied to
  `/etc/init.d/unslung` so Entware mounts on boot.

## Usage

1. From the printer's LCD: **Settings → General → root** to enable SSH
   (note the password it displays).
2. Download `bootstrap.zip` from the latest
   [release](https://github.com/gmanrally/k2-improvements/releases) and
   extract it.
3. Open Fluidd at `http://<printer-ip>:4408` → **Configuration** tab →
   **Upload Folder** → select the extracted `bootstrap` folder. This puts
   the files at `/mnt/UDISK/printer_data/config/bootstrap/`.
4. SSH to the printer (`root` / password from step 1) and run:

   ```
   sh /mnt/UDISK/printer_data/config/bootstrap/bootstrap.sh
   ```

5. When the bootstrap exits, run one of:

   ```
   sh /mnt/UDISK/root/k2-improvements/no-carto.sh         # no Cartographer
   sh /mnt/UDISK/root/k2-improvements/gimme-the-jamin.sh  # with Cartographer
   ```

The bootstrap is idempotent — running it again with Entware already
installed will only `git pull` the repo to update it.
