# Carto-out / prtouch-in exclusive conversion (PROVEN 86D2 2026-07-27)

Converts a carto-equipped K2 back to stock strain (prtouch v3) probing -
for plates the eddy probe cannot work on (V4 + 4mm garolite), or whenever
"no carto at all" is wanted. First strain results on thick garolite:
G28 tap-home first try, PROBE_ACCURACY range 4.5um ON THE PRINT SURFACE,
trammed 7x7 mesh spread 0.41mm / 33um neighbor deltas (true surface - no
magnet texture, unlike eddy scan through the plate).

## Procedure (all steps proven in order)

1. Extract stock extras from the matching-version OTA image (carto install
   deleted/overrode them). 7-Zip opens it: .img = cpio -> rootfs = SquashFS.
   Files needed - BOTH .py and .pyc (Klipper's loader wants the .py):
   `usr/share/klipper/klippy/extras/{bed_mesh,homing,temperature_mcu}.{py,pyc}`
2. Backup `printer.cfg` + `custom/main.cfg` (timestamped).
3. In `/usr/share/klipper/klippy/extras/`: remove the fork symlinks
   (`bed_mesh.py homing.py temperature_mcu.py`) + their __pycache__ entries,
   copy in the stock files. (mcu/serialhdl/clocksync/configfile patches can
   stay - inert without a carto device.)
4. Strip all `#*# [cartographer ...]` SAVE_CONFIG blocks from printer.cfg
   (they error as unknown sections once the plugin is gone).
5. `custom/main.cfg`: comment `[include cartographer.cfg]`, enable the STOCK
   `[include prtouch_v3.cfg]` (prtouch legitimately owns the probe slot;
   stepper_z's probe:z_virtual_endstop resolves to strain automatically).
6. Stop the cartographer service; comment the carto-watchdog cron line.
7. `[bed_mesh] probe_count` down to 7,7 (meshing is now physical taps).
8. Restart klipper -> verify: probe object present, carto objects/commands
   gone, then SUPERVISED first G28 (Z homes by nozzle tap).
9. Z_TILT_ADJUST (strain) -> BED_MESH_CALIBRATE -> SAVE_CONFIG. Do NOT mesh
   untrammed - the gantry ramp dwarfs the surface (1.9mm fake spread seen).

## Notes

- Manual G28 lost the fork's XY key22 auto-retry (lived in the carto homing
  patch). START_PRINT's _HOME_VERIFY still re-issues; console G28 may need
  a manual retry on the RS485 stall transient.
- START_PRINT's non-carto branch (MESH_IF_NEEDED path) serves this mode; the
  no_touch/coil-gate machinery is inert without printer.cartographer.
- Revert = restore the .pre-prtouch-* backups, re-symlink the patch files,
  swap the includes back, re-run carto calibration.
