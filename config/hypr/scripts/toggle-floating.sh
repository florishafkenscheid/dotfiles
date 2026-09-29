#!/bin/env bash

CURSOR_DATA=$(hyprctl cursorpos -j 2>/dev/null) || exit 0
MONITOR_DATA=$(hyprctl monitors -j 2>/dev/null) || exit 0
CLIENT_DATA=$(hyprctl clients -j 2>/dev/null) || exit 0

# Hyprland's keyboard focus can remain on another window while the pointer is
# over a client-side-fullscreen XWayland window. Resolve the tiled/floating
# window beneath the pointer on the monitor's visible workspace instead.
WINDOW_DATA=$(
  jq -cn \
    --argjson cursor "$CURSOR_DATA" \
    --argjson monitors "$MONITOR_DATA" \
    --argjson clients "$CLIENT_DATA" '
      first(
        $monitors[]
        | select(
            $cursor.x >= .x and $cursor.x < (.x + .width)
            and $cursor.y >= .y and $cursor.y < (.y + .height)
          )
      ) as $monitor
      | [
          $clients[]
          | select(
              .mapped
              and .visible
              and .workspace.id == $monitor.activeWorkspace.id
              and $cursor.x >= .at[0]
              and $cursor.x < (.at[0] + .size[0])
              and $cursor.y >= .at[1]
              and $cursor.y < (.at[1] + .size[1])
            )
        ]
      | sort_by([-(.fullscreen), .focusHistoryID])
      | first
    '
)

if [ -z "$WINDOW_DATA" ] || [ "$WINDOW_DATA" = "null" ]; then
  WINDOW_DATA=$(hyprctl activewindow -j 2>/dev/null) || exit 0
fi

mapfile -t WINDOW_STATE < <(
  jq -r '
    .address // "",
    .class // "",
    .fullscreen // 0,
    .fullscreenClient // 0,
    .floating // false
  ' <<<"$WINDOW_DATA"
)

WINDOW_ADDRESS=${WINDOW_STATE[0]}
WINDOW_CLASS=${WINDOW_STATE[1]}
FULLSCREEN=${WINDOW_STATE[2]}
CLIENT_FULLSCREEN=${WINDOW_STATE[3]}
FLOATING=${WINDOW_STATE[4]}

[[ "$WINDOW_ADDRESS" =~ ^0x[0-9a-fA-F]+$ ]] || exit 0
WINDOW_SELECTOR="address:${WINDOW_ADDRESS}"

case "$WINDOW_CLASS" in
  Minecraft* | minecraft*)
    if [ "$FULLSCREEN" -gt 0 ]; then
      # Keep reporting fullscreen to Minecraft while Hyprland floats it.
      hyprctl dispatch \
        "hl.dsp.window.float({ action = \"set\", window = \"${WINDOW_SELECTOR}\" })" \
        >/dev/null
      sleep 0.05
      hyprctl dispatch \
        "hl.dsp.window.fullscreen_state({ internal = 0, client = 2, action = \"set\", window = \"${WINDOW_SELECTOR}\" })" \
        >/dev/null
      exit 0
    fi

    if [ "$FLOATING" = "true" ] && [ "$CLIENT_FULLSCREEN" -eq 2 ]; then
      # A second press restores the real fullscreen state.
      hyprctl dispatch \
        "hl.dsp.window.float({ action = \"unset\", window = \"${WINDOW_SELECTOR}\" })" \
        >/dev/null
      # Let the dwindle layout finish reattaching the window before promoting
      # its compositor state back to fullscreen. Without this boundary,
      # Hyprland can retain client fullscreen while leaving it half-screen.
      sleep 0.05
      hyprctl dispatch \
        "hl.dsp.window.fullscreen_state({ internal = 2, client = 2, action = \"set\", window = \"${WINDOW_SELECTOR}\" })" \
        >/dev/null
      exit 0
    fi
    ;;
esac

hyprctl dispatch \
  "hl.dsp.window.float({ action = \"toggle\", window = \"${WINDOW_SELECTOR}\" })" \
  >/dev/null
