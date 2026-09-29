#!/usr/bin/env bash

set -euo pipefail

SECONDARY_MONITOR="HDMI-A-1"
POWER_HELPER="/usr/local/sbin/hypr-idle-power"

start_screensaver() {
  sudo -n "${POWER_HELPER}" start || true
  hyprctl dispatch \
    "hl.dsp.dpms({ action = \"disable\", monitor = \"${SECONDARY_MONITOR}\" })" \
    || true
  qs ipc -c blousy call idle start || true
}

stop_screensaver() {
  qs ipc -c blousy call idle stop || true
  hyprctl dispatch \
    "hl.dsp.dpms({ action = \"enable\", monitor = \"${SECONDARY_MONITOR}\" })" \
    || true
  sudo -n "${POWER_HELPER}" stop || true
}

case "${1:-}" in
  start)
    start_screensaver
    ;;
  stop)
    stop_screensaver
    ;;
  *)
    echo "Usage: $0 {start|stop}" >&2
    exit 1
    ;;
esac
