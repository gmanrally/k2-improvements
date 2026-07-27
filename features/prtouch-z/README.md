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

## Post-mortem (2026-07-27): hybrid NOT viable

The shim loads cleanly alongside the cartographer (probe-slot collision,
option consumption, and the bed_mesh probe_helper relocation all solved -
see git history). But the compiled wrapper's probing ritual **dispatches
its own _HOME_Z / G28 gcode internally**: Creality prtouch assumes full
ownership of Z homing. Under carto-owned Z (virtual endstop + patched
homing.py) that ritual corrupts stepper state -> `Internal error in MCU
'mcu' stepcompress` -> shutdown, reproducibly (2/2 tap attempts, with and
without shim-side homing glue). No motion ever occurred; failures were
pre-move.

Conclusion: strain Z on a carto machine requires an EXCLUSIVE-mode swap
(carto includes + patched extras out, stock prtouch stack in - note the
carto install deletes stock bed_mesh.py*, so stock extras must be restored
from the firmware image). Parked as a designed project; the shim is kept
for its findings and the chip-registration pattern.
