# Cartographer Firmware

A flashing script has been included that can flash your cartographer device on the K2. This can be run with or without k2-improvements installed. Without bootstrap, manually copy the `firmware/` folder to the K2 and run `flash.py`. Otherwise, bootstrap will have cloned the repo, so you can run:
```bash
python3 /mnt/UDISK/root/k2-improvements/features/cartographer/firmware/flash.py
```

Connect the Cartographer via USB, then follow the prompts.

The script supports cartographer v3 and v4.

Otherwise, you can follow the official guide to flash the cartographer on another device:  
https://docs.cartographer3d.com/cartographer-probe/firmware/updating-firmware
## Variant note (2026-07-16, measured on 86D2)

Despite the flash menu labelling Lite "Recommended for K2", **V4 6.2.0 Lite
misbehaved on a K2 Plus**: constantly-lit probe LED, a spontaneous USB
re-enumeration, and wedged touch triggering (key22 on every TOUCH_HOME while
comms stayed healthy). **6.2.0 Full works correctly** on the same probe and
host (calibrate verified 0.013mm across 10 samples, touch-home first try).
The K2 host handled full-rate 6.0.0 for weeks - use Full.
