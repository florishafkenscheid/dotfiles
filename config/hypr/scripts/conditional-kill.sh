#!/usr/bin/env bash

WINDOW_DATA=$(hyprctl activewindow -j)
ACTIVE_CLASS=$(echo "$WINDOW_DATA" | jq -r '.class')
ACTIVE_TITLE=$(echo "$WINDOW_DATA" | jq -r '.title')

if [[ "$ACTIVE_CLASS" =~ ^(cs2)$ ]] || [[ "$ACTIVE_TITLE" == "Counter-Strike 2" ]]; then
	pkill -15 -x cs2
	sleep 0.2
	pkill -9 -x cs2
	exit 0
fi

if [[ "$ACTIVE_CLASS" =~ ^(vesktop|discord)$ ]]; then
	hyprctl dispatch movetoworkspacesilent special:hidden
else
	hyprctl dispatch killactive
fi
