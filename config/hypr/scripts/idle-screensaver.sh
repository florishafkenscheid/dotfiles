#!/usr/bin/env bash

set -euo pipefail

SECONDARY_MONITOR="HDMI-A-1"
POWER_HELPER="/usr/local/sbin/hypr-idle-power"

set_secondary_power() {
  local action=$1

  # A missing monitor can make the dispatcher fall back to the active output.
  hyprctl -j monitors | jq -e --arg monitor "${SECONDARY_MONITOR}" \
    'any(.[]; .name == $monitor)' >/dev/null || return 0

  hyprctl dispatch \
    "hl.dsp.dpms({ action = \"${action}\", monitor = \"${SECONDARY_MONITOR}\" })" \
    || true
}

start_screensaver() {
  sudo -n "${POWER_HELPER}" start || true
  set_secondary_power disable
  qs ipc -c blousy call idle start || true
}

stop_screensaver() {
  qs ipc -c blousy call idle stop || true
  set_secondary_power enable
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
