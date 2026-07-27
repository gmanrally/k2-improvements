# prtouch_z: Creality strain-gauge (prtouch v3) as a standalone Z endstop
# chip that COEXISTS with a cartographer owning the 'probe' object.
#
# Why: stock prtouch_v3.py registers add_object('probe', ...) which collides
# with the cartographer plugin ("Printer object 'probe' already created",
# observed 86D2 2026-07-27). The strain endstop itself is just an object -
# this shim loads the same compiled PRTouchEndstopWrapper but registers it
# as pin chip 'prtouch' instead of as the printer's probe.
#
# Usage:
#   [prtouch_z]            <- same options as the stock [prtouch_v3] section
#   ...
#   [stepper_z]
#   endstop_pin: prtouch:z_virtual_endstop   <- strain nozzle-tap Z homing
#
# The cartographer keeps 'probe' (scan meshing etc). Hybrid result: force-
# based true-surface Z on any plate (incl. thick garolite) + eddy scan mesh.
#
# PRTOUCH_TAP [SPEED=] [MAX_DIST=]: guarded single tap from the current
# position for bench testing - probes downward at most MAX_DIST (default 5mm).
import logging
import pins
from . import prtouch_v3_wrapper


class PRTouchZ:
    def __init__(self, config):
        self.printer = config.get_printer()
        # The compiled wrapper's connect handler reaches into
        # bed_mesh.bmc.probe_helper (stock layout). The carto-patched
        # bed_mesh moved that helper onto BedMeshCalibrate.probe_mgr.
        # Register our aliasing handler BEFORE creating the wrapper so it
        # runs first (connect handlers fire in registration order).
        self.printer.register_event_handler(
            "klippy:connect", self._alias_probe_helper)
        self.mcu_probe = prtouch_v3_wrapper.PRTouchEndstopWrapper(config)
        self.multi_probe_pending = False
        self.speed = config.getfloat('speed', 5.0, above=0.)
        # Consume the options the stock pairing's PrinterProbe would have
        # read from this section (we don't instantiate one) - otherwise
        # Klipper rejects them as unknown ("Option 'samples' is not valid",
        # observed at first load test 2026-07-27).
        self.z_offset = config.getfloat('z_offset', 0.)
        config.getint('samples', 1, minval=1)
        config.get('samples_result', 'average')
        config.getfloat('samples_tolerance', 0.1, above=0.)
        config.getint('samples_tolerance_retries', 0, minval=0)
        # Register as an independent pin chip (mirrors probe.py's pattern,
        # different chip name so the cartographer's 'probe' is untouched).
        self.printer.lookup_object('pins').register_chip('prtouch', self)
        self.printer.register_event_handler(
            "homing:homing_move_begin", self._handle_homing_move_begin)
        self.printer.register_event_handler(
            "homing:homing_move_end", self._handle_homing_move_end)
        self.printer.register_event_handler(
            "homing:home_rails_begin", self._handle_home_rails_begin)
        self.printer.register_event_handler(
            "homing:home_rails_end", self._handle_home_rails_end)
        self.printer.register_event_handler(
            "gcode:command_error", self._handle_command_error)
        gcode = self.printer.lookup_object('gcode')
        gcode.register_command(
            'PRTOUCH_TAP', self.cmd_PRTOUCH_TAP,
            desc="Single guarded strain-gauge tap from the current position")

    def _alias_probe_helper(self):
        try:
            bmc = self.printer.lookup_object('bed_mesh').bmc
            if not hasattr(bmc, 'probe_helper'):
                mgr = getattr(bmc, 'probe_mgr', None)
                helper = getattr(mgr, 'probe_helper', None)
                if helper is not None:
                    bmc.probe_helper = helper
                    logging.info("prtouch_z: aliased bed_mesh probe_helper "
                                 "from probe_mgr for wrapper compatibility")
        except Exception:
            logging.exception("prtouch_z: probe_helper alias failed")

    # --- pin chip interface (mirrors probe.py) ---
    def setup_pin(self, pin_type, pin_params):
        if pin_type != 'endstop' or pin_params['pin'] != 'z_virtual_endstop':
            raise pins.error(
                "prtouch virtual endstop only useful as endstop pin")
        if pin_params['invert'] or pin_params['pullup']:
            raise pins.error(
                "Can not pullup/invert prtouch virtual endstop")
        return self.mcu_probe

    # --- homing event glue (mirrors probe.py) ---
    def _handle_homing_move_begin(self, hmove):
        if self.mcu_probe in hmove.get_mcu_endstops():
            self.mcu_probe.probe_prepare(hmove)

    def _handle_homing_move_end(self, hmove):
        if self.mcu_probe in hmove.get_mcu_endstops():
            self.mcu_probe.probe_finish(hmove)

    def _handle_home_rails_begin(self, homing_state, rails):
        endstops = [es for rail in rails for es, name in rail.get_endstops()]
        if self.mcu_probe in endstops:
            self.multi_probe_begin()

    def _handle_home_rails_end(self, homing_state, rails):
        endstops = [es for rail in rails for es, name in rail.get_endstops()]
        if self.mcu_probe in endstops:
            self.multi_probe_end()

    def _handle_command_error(self):
        try:
            self.multi_probe_end()
        except Exception:
            logging.exception("prtouch_z multi-probe end")

    def multi_probe_begin(self):
        self.mcu_probe.multi_probe_begin()
        self.multi_probe_pending = True

    def multi_probe_end(self):
        if self.multi_probe_pending:
            self.multi_probe_pending = False
            self.mcu_probe.multi_probe_end()

    # --- guarded bench-test command ---
    def cmd_PRTOUCH_TAP(self, gcmd):
        speed = gcmd.get_float("SPEED", self.speed, above=0.)
        maxdist = gcmd.get_float("MAX_DIST", 5.0, above=0., maxval=15.)
        toolhead = self.printer.lookup_object('toolhead')
        pos = toolhead.get_position()
        target = list(pos)
        target[2] = pos[2] - maxdist
        phoming = self.printer.lookup_object('homing')
        self.multi_probe_begin()
        try:
            epos = phoming.probing_move(self.mcu_probe, target, speed)
        finally:
            self.multi_probe_end()
        gcmd.respond_info("PRTOUCH_TAP triggered at Z=%.4f" % (epos[2],))


def load_config(config):
    return PRTouchZ(config)
