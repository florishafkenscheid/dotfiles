#!/usr/bin/env python3
"""Wait for the Maya X to charge before powering off; Ctrl+C overrides the wait."""

import importlib.util
import signal
import subprocess
import sys
import time
from pathlib import Path


def load_battery_helper():
    path = Path(__file__).with_name("get-lamzu-battery.py")
    spec = importlib.util.spec_from_file_location("lamzu_battery", path)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    return helper


def ready_to_shutdown(battery):
    # A full battery may stop charging even though the cable is connected.
    return (
        battery.get("available", False)
        and battery.get("connection") == "wired"
        and (battery.get("charging", False) or battery.get("percent") == 100)
    )


def main():
    print(
        "Checking mouse: plug in your Maya X so it's charging. "
        "Ctrl+C shuts down anyway.",
        flush=True,
    )
    try:
        helper = load_battery_helper()
        previous_status = None
        while True:
            try:
                battery = helper.shared_battery(fresh=True)
            except OSError as exc:
                battery = helper.unavailable(exc)
            if ready_to_shutdown(battery):
                print(f"Mouse connected ({battery['percent']}%). Shutting down.", flush=True)
                break
            if not battery.get("available"):
                status = f"Cannot verify mouse: {battery.get('error', 'unavailable')}"
            elif battery.get("connection") != "wired":
                status = f"Mouse is wireless ({battery['percent']}%). Waiting for the cable…"
            else:
                status = f"Mouse is plugged in but isn't charging ({battery['percent']}%). Waiting…"
            if status != previous_status:
                print(status, flush=True)
                previous_status = status
            time.sleep(2)
    except KeyboardInterrupt:
        print("\nCharging check overridden. Shutting down.", flush=True)

    # Further Ctrl+C presses must not interrupt the shutdown command.
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    return subprocess.call(["poweroff", *sys.argv[1:]])


if __name__ == "__main__":
    sys.exit(main())
