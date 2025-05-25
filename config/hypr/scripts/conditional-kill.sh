#!/bin/bash

active_window=$(hyprctl --batch "j/activewindow" | jq -r ".class")
echo $active_window > "$HOME/output.log"

hide_apps=("Steam" "vesktop")

if echo "${hide_apps[@]}" | grep -q -w "$active_window"; then
	hyprctl dispatch movetoworkspacesilent special:hidden
else
	hyprctl dispatch killactive
fi
