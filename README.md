# K2 Plus Improvements

This is the actively-maintained continuation of [CampbellFabrications/k2-improvements](https://github.com/CampbellFabrications/k2-improvements) (archived 2026-02-07), which itself forked from [@jamincollins](https://github.com/jamincollins). Most of the underlying features (fluidd, moonraker, cartographer3d-plugin) come from [@Jacob10383](https://github.com/Jacob10383)'s ongoing work; this fork adds nozzle-camera streaming, firmware-compat fixes for the latest Creality builds, and a few quality-of-life macros.

**Current release:** [`v1.3.0`](https://github.com/gmanrally/k2-improvements/releases/tag/v1.3.0) — cartographer reliability pack (boot autostart, V3 schema patch, carto-watchdog cron, CARTO-SAFE homing.py patch, V3-tuned bed-mesh defaults). Verified against Creality K2 Plus firmware **V1.1.5.5** (kernel build 2026-05-08). See [Latest Added Features](#latest-added-features) for the full v1.3.0 changelog.

In the `features` folder you will find install scripts for each of the features, if you'd rather install them individually.

## DISCLAIMER

Use at your own risk, I'm not responsible for fires or broken dreams.  But you do get to keep both halves if something breaks.

## Warning

As a _heads up_ these improvements are not compatible with Creality's _auto-calibration_.  In our experience we get better results through manual tuning.

## Start Here at Bootstrap

The Bootstrap is a requirement for the improvements to install properly, so this must be accomplished first. Of note, it will install entware tools necessary to accomplish the installs. Additionally, root is enabled by default with the password: 'creality_2024'. At some point, we recommend running command 'passwd' in the terminal to change the default password to something secure.

It is recommend to perform a factory reset prior to install to avoid potential conflicts with previous modifications.  A factory reset can be achieved with the following command in a terminal on the K2:

```raw
echo "all" | /usr/bin/nc -U /var/run/wipe.sock
```

1. Enable root access on the K2 Plus by going to Settings, General tab and root on the physical screen. Take note of the password.
1. Download `bootstrap.zip` from the latest [release](https://github.com/gmanrally/k2-improvements/releases) and extract the folder. (Source for the bootstrap lives in [`bootstrap/`](./bootstrap/README.md).)
1. To install the bootstrap, connect to your K2 Plus's Fluid interface via browser **http://PrinterIP:4408**
1. Unzip the downloaded bootstrap folder and upload the extracted bootstrap folder by going to Configuration **{...}**, **+**, **Upload Folder**, and selecting the extracted bootstrap folder.
    ![image](https://github.com/user-attachments/assets/3d242efc-4cf8-412d-b4b0-59507720f5ad)
1. SSH to the K2 Plus using any terminal tool (e.g. PuTTy) using the printers ip adress, port 22, user "root" and the password noted in step 1.
1. If you execute a wipe, you will need to go through setup on the K2 screen and complete all the way through creality cloud connection. This will give you the wifi/network connection that you will need and connect appropriately to creality cloud. Stop at the calibration, you can do this later.
1. To start the boostrap install: paste into the terminal `sh /mnt/UDISK/printer_data/config/bootstrap/bootstrap.sh` and hit enter.
1. Once the setup completes, it will log you out of your terminal and you will need to log back in.

## Installers

* Option 1: `gimme-the-jamin.sh` - Used to install cartographer features **NOTE MUST HAVE CARTO FLASHED AND PLUGGED IN AND READY TO GO** by following instructions [here](https://github.com/gmanrally/k2-improvements/blob/main/features/cartographer/firmware/README.md) first.

    To run, use the terminal command `sh /mnt/UDISK/root/k2-improvements/gimme-the-jamin.sh`

    After install you will need to calibrate the carto by following instructions [here](https://github.com/gmanrally/k2-improvements/blob/main/features/cartographer/SETUP.md)

    V3 Cartographer hardware works fine with the bundled V4 plugin — the `Survey_Cartographer_USB_8kib_offset.bin` firmware in `features/cartographer/firmware/` handles V3 boards.

* Option 2: `no-carto.sh` - Use this if you aren't going to use a carto, or don't have your carto yet.

    To run, use the terminal command `sh /mnt/UDISK/root/k2-improvements/no-carto.sh`

They both install the same set of features (those that I use).  The only difference is whether or not the cartographer bits are installed. If you start with no-carto.sh and later get a carto, you can then run the gimme-the-jamin.sh script and it will install all of the necessary carto items appropriately.

You are still welcome to hand pick which features you want to install.

# Latest Added Features:

## v1.3.0 — Cartographer reliability pack

This release packages everything we learned operating a small K2 Plus fleet under sustained PA-CF / engineering-polymer print loads. All changes are in the `features/cartographer/` install path.

**install.sh changes:**
- **`/etc/init.d/cartographer enable`** — service is now registered for boot autostart. Without this, after the first reboot the bridge daemon didn't start and `/dev/cartographer` went missing silently (Klipper marked the MCU `non_critical_disconnected` and Z homing broke). Observed Jun 2026.
- **V3-touch schema-cap patch** — sed on `cartographer3d-plugin/src/cartographer/interfaces/configuration.py` raises the `sample_range` max from `0.015` (V4-hardware tight) to `0.5` so V3 hardware can pass `CARTOGRAPHER_TOUCH_CALIBRATE`. Idempotent.
- **`carto-watchdog.sh` cron** — installed at `/mnt/UDISK/bin/carto-watchdog.sh`, runs every minute, restarts the cartographer service if `/dev/cartographer` is missing or `usb_bridge` isn't running. Defence-in-depth alongside the boot autostart fix.

**`patches/homing.py` CARTO-SAFE patch:**
- Removed the `error = None` clearing for Z axis when `check_triggered` fires without a real trigger. The original behaviour was: SCAN-mode homing returns `trig_pos: None`, K2's patched homing silently accepts the home, the cartographer plugin's `on_home_end` runs, calls `set_z_homed_position()` with whatever the coil reads, and the next move rams the toolhead into the bed. The patch makes Z-no-trigger an error (recoverable) instead of a fake success (crash). Logged as `key22 No trigger on z`.

**`cartographer.cfg` template changes (V3-safe defaults baked in):**
- `bed_mesh.speed: 200 -> 150`
- `bed_mesh.probe_count: 31, 31 -> 19, 19`
- Added `[cartographer scan]` with `mesh_runs: 2`
- Added `[cartographer touch]` block with V3-safe values (`samples: 5`, `max_noisy_samples: 4`, `sample_range: 0.2`)

The previous higher-density / single-pass settings were correct for V4 hardware but failed stochastically on V3 boards under USB-bridge packet loss. New settings work for both.

## V3 vs V4 cartographer hardware — what to change

The fork ships V3-safe defaults. Here's the matrix:

| Setting | V3 hardware (default) | V4 hardware (edit if you have V4) |
|---|---|---|
| `[cartographer touch] sample_range` | `0.2` | `0.015` (V4-plugin default) — or just **comment out the whole `[cartographer touch]` block** |
| `[cartographer touch] samples` | `5` | `3` |
| `[cartographer touch] max_noisy_samples` | `4` | `2` |
| `[bed_mesh] probe_count` | `19, 19` | `31, 31` if you want higher mesh resolution |
| `[bed_mesh] speed` | `150` | `200` works on V4 |
| `[cartographer scan] mesh_runs` | `2` | `1` works on V4 (faster mesh) |
| ADXL345 `cs_pin` (if used) | `cartographer:PA3` | `cartographer:PA0` |

**How to tell which hardware you have:**

- After install, query the MCU version:
  ```
  curl -s 'http://YOUR_PRINTER_IP:7125/printer/objects/query?mcu%20cartographer=' | python -c "import json,sys; print(json.load(sys.stdin)['result']['status']['mcu cartographer']['mcu_version'])"
  ```
  - V3 hardware reports `CARTOGRAPHER K1 5.x.x`
  - V4 hardware reports a different version string (newer ASIC)
- Physically: V3 has a single sensor coil PCB; V4 has the newer integrated ASIC daughterboard

**The V3 schema patch is harmless on V4** — it raises a *ceiling* but doesn't change the default. V4 configs that set `sample_range: 0.015` work identically.

## Nozzle Camera Streaming (v1.2.0)
The K2 Plus has a built-in nozzle camera that Creality only enables briefly during first-layer calibration. The new [nozzle-cam](./features/nozzle-cam/README.md) feature powers it on demand and serves an MJPEG stream on port 8081 so it can be viewed in Fluidd alongside the chamber webcam. Call `NOZZLE_CAM_ON` / `NOZZLE_CAM_OFF` from the Fluidd console; the LED auto-shuts-off after 10 minutes for safety.

## PAUSE / RESUME Safety Guards (v1.2.0)
Stock Creality `PAUSE_EXTERNAL` can save `extruder.target=0` if paused before the heater ramps up, and the stock `RESUME` then quietly turns the hotend off mid-print. This fork guards against that in `features/macros/overrides/overrides.cfg`: PAUSE refuses to save a corrupted state, and RESUME blocks on `M109` and `M190` so the print never continues with a cold nozzle or cold bed.

## Cartographer V4 Support
Replaced the Cartographer Feature Folder with [Jacob10383's](https://github.com/Jacob10383) commit enabling [Cartographer V4](https://github.com/Jacob10383/k2-improvements/commit/a6698912233346fe593b7ae30bd22693854f9cac) support.
Installs the new [Cartographer3D-plugin](https://github.com/CampbellFabrications/cartographer3d-plugin) as a fork of [Jacob10383](https://github.com/Cartographer3D/cartographer3d-plugin/commit/ddcb2537826fac11b9130bc4011ed16e25627d46)'s work on enabling k2 compatability. that replaces the previous deprecated 'cartographer-klipper'.

## Webcam-FPS 17-10-25
The stock chamber camera is set to 15fps. `v4l2-ctl --list-formats-ext -d /dev/v4l/by-id/main-video0` reports 30fps as available. Lets get that framerate.

## Non-Critical Cartographer MCU
Allows `[mcu cartographer]` within Cartographer.cfg to be defined as optional with the following flag: `is_non_critical`.

Massive Thanks to [Jacob10383](https://github.com/Jacob10383) for [This](https://github.com/Jacob10383/Printer/commit/670d405f1a6d40760fe4e9c74c87a0100c1135a4#diff-45f5ce587b170586644c8277b076bd26669b8262c464575c9e20f15f665acead) commit.

Set this value to `is_non_critical: true` to allow disconnects without the printer stopping.


## Features

* [axis_twist_compensation](./features/axis_twist_compensation/README.md)
* [better init](./features/better-init/README.md)
* [better root](./features/better-root/README.md) home directory
* [Cartographer](./features/cartographer/README.md) support (V3 and V4 hardware)
* installs [Entware](https://github.com/Entware/Entware)
* updated [Fluidd](./features/fluidd/README.md)
* updated [Moonraker](./features/moonraker/README.md)
* [nozzle-cam](./features/nozzle-cam/README.md) — view the built-in nozzle camera in Fluidd
* [Obico](./features/obico/README.md) - _WIP_
* implements [SCREWS_TILT_CALCULATE](https://www.klipper3d.org/Manual_Level.html#adjusting-bed-leveling-screws-using-the-bed-probe)

And a few quality of life improvement macros

* [MESH_IF_NEEDED](./features/macros/bed_mesh/README.md)
* [START_PRINT](./features/macros/start_print/README.md)
* [M191](./features/macros/m191/README.md)

### Bed Leveling

Sadly, many of the K2 beds resemble a taco or valley.  In the [bed_leveling](bed_leveling) folder you will find a python based script and short writeup on how to apply aluminium tape to shim the bed.

## Credits


* [@jamincollins](https://github.com/jamincollins) - The guy who started this project
* [@CampbellFabrications](https://github.com/CampbellFabrications) - Maintained the project through the V4 cartographer transition
* [@Jacob10383](https://github.com/Jacob10383/) - KAMP, Resonance Sweeping changes for `shaper_calibrate`, ongoing maintenance of moonraker / fluidd / cartographer3d-plugin forks consumed here
* [@Guilouz](https://github.com/Guilouz) - standing on the shoulders of giants
* [@stranula](https://github.com/stranula)
* [@juliosueiras](https://github.com/juliosueiras)

* Moonraker - [https://github.com/Arksine/moonraker](https://github.com/Arksine/moonraker)
* Klipper - [https://github.com/Klipper3d/klipper](https://github.com/Klipper3d/klipper)
* Fluidd - [https://github.com/fluidd-core/fluidd](https://github.com/fluidd-core/fluidd)
* Entware - [https://github.com/Entware/Entware](https://github.com/Entware/Entware)
* Obico - [https://www.obico.io/](https://www.obico.io/)
* SimplyPrint - [https://simplyprint.io/](https://simplyprint.io/)
* KAMP - [https://github.com/kyleisah](https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging)
* GuppyScreen - [https://github.com/foo](https://github.com/foo/guppyscreen)

## FAQ

See the [FAQ](./FAQ.md)
