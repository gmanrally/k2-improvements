# Run shell commands from g-code macros.
#
# Config:
#   [gcode_shell_command NAME]
#   command: /path/to/script arg1 arg2
#   timeout: 5.0           # seconds, default 2.0
#   verbose: True          # echo stdout/stderr to console, default True
#
# G-code:
#   RUN_SHELL_COMMAND CMD=NAME [PARAMS="extra args"]

import logging
import os
import shlex

from subprocess import PIPE, Popen


class ShellCommand:
    def __init__(self, config):
        self.name = config.get_name().split()[-1]
        self.printer = config.get_printer()
        self.gcode = self.printer.lookup_object("gcode")
        self.command = config.get("command")
        self.timeout = config.getfloat("timeout", 2.0, above=0.0)
        self.verbose = config.getboolean("verbose", True)
        self.proc_fd = None
        self.partial_output = ""
        self.gcode.register_mux_command(
            "RUN_SHELL_COMMAND",
            "CMD",
            self.name,
            self.cmd_RUN_SHELL_COMMAND,
            desc="Run a registered shell command",
        )

    def _process_output(self, eventtime):
        if self.proc_fd is None:
            return
        try:
            data = os.read(self.proc_fd, 4096).decode("utf-8", errors="replace")
        except Exception:
            return
        if not data:
            return
        if "\n" not in data:
            self.partial_output += data
            return
        elif self.partial_output:
            data = self.partial_output + data
            self.partial_output = ""
        if data[-1] != "\n":
            self.partial_output = data[data.rfind("\n") + 1 :]
            data = data[: data.rfind("\n") + 1]
        self.gcode.respond_info(data.rstrip("\n"))

    cmd_RUN_SHELL_COMMAND_help = "Run a registered shell command"

    def cmd_RUN_SHELL_COMMAND(self, gcmd):
        params = gcmd.get("PARAMS", default="")
        cmd = self.command
        if params:
            cmd = cmd + " " + params
        try:
            argv = shlex.split(cmd)
        except ValueError as e:
            raise gcmd.error("Bad command: %s" % str(e))
        try:
            proc = Popen(argv, stdout=PIPE, stderr=PIPE)
        except Exception as e:
            raise gcmd.error("Spawn failed: %s" % str(e))
        try:
            stdout, stderr = proc.communicate(timeout=self.timeout)
        except Exception as e:
            proc.kill()
            stdout, stderr = proc.communicate()
            if self.verbose:
                gcmd.respond_info("Command timed out: %s" % str(e))
        if self.verbose:
            out = (stdout or b"").decode("utf-8", errors="replace").strip()
            err = (stderr or b"").decode("utf-8", errors="replace").strip()
            if out:
                gcmd.respond_info(out)
            if err:
                gcmd.respond_info(err)
        if proc.returncode:
            logging.warning(
                "shell_command %s exited with %d", self.name, proc.returncode
            )


def load_config_prefix(config):
    return ShellCommand(config)
