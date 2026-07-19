#!/usr/bin/env bash

set -euo pipefail

SECONDARY_MONITOR="HDMI-A-1"
POWER_HELPER="/usr/local/sbin/hypr-idle-power"

close_bars() {
  eww close bar_primary || true
  eww close bar_secondary || true
}

open_bars() {
  eww open-many bar_primary bar_secondary || true
}

start_screensaver() {
  sudo -n "${POWER_HELPER}" start || true
  hyprctl dispatch dpms off "${SECONDARY_MONITOR}" || true
  close_bars
  eww open idle_overlay
}

stop_screensaver() {
  eww close idle_overlay || true
  hyprctl dispatch dpms on "${SECONDARY_MONITOR}" || true
  sudo -n "${POWER_HELPER}" stop || true
  sleep 3
  open_bars
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
