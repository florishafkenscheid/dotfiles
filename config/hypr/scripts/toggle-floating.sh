#!/bin/env bash

WINDOW_DATA=$(hyprctl activewindow -j 2>/dev/null) || exit 0

mapfile -t WINDOW_STATE < <(
  jq -r '
    .class // "",
    .fullscreen // 0,
    .fullscreenClient // 0,
    .floating // false
  ' <<<"$WINDOW_DATA"
)

WINDOW_CLASS=${WINDOW_STATE[0]}
FULLSCREEN=${WINDOW_STATE[1]}
CLIENT_FULLSCREEN=${WINDOW_STATE[2]}
FLOATING=${WINDOW_STATE[3]}

case "$WINDOW_CLASS" in
  Minecraft* | minecraft*)
    if [ "$FULLSCREEN" -gt 0 ]; then
      # Keep reporting fullscreen to Minecraft while Hyprland floats it.
      hyprctl dispatch fullscreenstate 0 2 set >/dev/null
      hyprctl dispatch setfloating >/dev/null
      exit 0
    fi

    if [ "$FLOATING" = "true" ] && [ "$CLIENT_FULLSCREEN" -eq 2 ]; then
      # A second press restores the real fullscreen state.
      hyprctl dispatch settiled >/dev/null
      hyprctl dispatch fullscreen 0 set >/dev/null
      exit 0
    fi
    ;;
esac

hyprctl dispatch togglefloating >/dev/null
