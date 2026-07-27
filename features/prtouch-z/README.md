# prtouch-z: strain-gauge Z alongside the cartographer

Loads Creality's compiled prtouch v3 strain endstop **without** claiming the
`probe` object (which the cartographer owns), by registering it as pin chip
`prtouch`. Enables force-based nozzle-tap Z on plates the eddy probe cannot
touch through (e.g. 4mm garolite), while the carto keeps scan meshing.

## Install (manual, staged - do NOT enable blind)

1. `ln -sf <repo>/features/prtouch-z/prtouch_z.py /usr/share/klipper/klippy/extras/prtouch_z.py`
2. `cp prtouch_z.cfg ~/printer_data/config/custom/` and add
   `[include prtouch_z.cfg]` to `custom/main.cfg` (start COMMENTED).
3. **Load test**: uncomment include, restart klipper. Pass = klippy ready.
   Fail = revert include. No motion in this step.
4. **Tap test** (operator at e-stop, nozzle HOT + cleaned, homed via carto):
   `G1 Z10` over bed centre then `PRTOUCH_TAP MAX_DIST=8`. Expect trigger
   near the true surface; repeat 3x for scatter.
5. **Homing switch** (only after 4 passes): in printer.cfg `[stepper_z]`
   set `endstop_pin: prtouch:z_virtual_endstop`; restart; supervised G28 Z.
6. Zero-accuracy shootout vs manual paper cal before trusting production.

## Status

- 2026-07-27: shim written; NOT yet load-tested. Compiled wrapper may make
  assumptions the shim doesn't satisfy (unknown lookups at connect) - the
  load test exists to find out cheaply.
