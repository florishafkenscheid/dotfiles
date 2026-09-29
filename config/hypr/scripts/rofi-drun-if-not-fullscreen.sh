#!/bin/env sh

WINDOW_DATA=$(hyprctl activewindow -j 2>/dev/null) || exit 0
FULLSCREEN=$(echo "$WINDOW_DATA" | jq -r '.fullscreen // 0')

if [ "${FULLSCREEN:-0}" -gt 0 ]; then
  hyprctl dispatch \
    'hl.dsp.send_shortcut({ mods = "CTRL", key = "space", window = "activewindow" })' \
    >/dev/null 2>&1
  exit 0
fi

exec rofi -show drun
