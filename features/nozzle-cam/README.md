# nozzle-cam

Power the K2 Plus's stock nozzle camera and serve its stream over HTTP so it
can be viewed in Fluidd alongside the chamber webcam.

## What this does

The K2 Plus has a built-in nozzle camera (`XWF-1080p6`, exposed at
`/dev/video2` once powered) that Creality only enables briefly during
first-layer calibration. The camera's USB power rail is gated by a GPIO and
its hot LED is intentionally not run continuously.

This feature wires up:

- A toggle script (`/mnt/UDISK/bin/nozzle-cam.sh`) that powers the cam, kills
  the auto-spawned `cam_sub_app` (which would otherwise hold `/dev/video2`),
  and starts an `ffmpeg` MJPEG HTTP server on port `8081`.
- Klipper g-code macros `NOZZLE_CAM_ON` / `NOZZLE_CAM_OFF` (via the bundled
  `gcode_shell_command` extra).
- A `[delayed_gcode]` that auto-powers-off after 10 minutes so the LED never
  runs hot indefinitely.

## Usage

From the Fluidd console:

```
NOZZLE_CAM_ON
```

then open `http://<printer-ip>:8081/` — it streams `multipart/x-mixed-replace`
MJPEG at 1280×720 @ 5fps and renders directly in any browser.

```
NOZZLE_CAM_OFF
```

stops the stream and powers the cam down.

To add it as a permanent webcam in Fluidd: **Settings → Cameras → Add Camera**,
type MJPEG-Streamer (multipart/adaptive), stream URL
`http://<printer-ip>:8081/`. Pair with `NOZZLE_CAM_ON` whenever you want to
view it; the cam will auto-shut-off 10 minutes later.

## Dependencies

- `entware` (provides `opkg`)
- `ffmpeg` from entware (~13 MB libs, installed automatically on first run)
- `better-init` (puts `/mnt/UDISK/bin` on `PATH`)

## Notes

- The LED on the nozzle cam is bright and hot. Don't leave it on for hours.
  The 10-minute auto-off is a safety net, not a feature to rely on.
- Single-frame snapshots aren't supported by this stream (ffmpeg's `mpjpeg`
  serves a continuous multipart MJPEG, no `?action=snapshot`).
- This is independent of Creality's first-layer calibration flow, which still
  works as before via `LOAD_AI_NOZZLE_CAM_POWER_ON` / `_OFF`.
