#!/bin/bash

active_window=$(hyprctl --batch "j/activewindow" | jq -r ".class")

hide_apps=("vesktop" "discord")

if echo "${hide_apps[@]}" | grep -q -w "$active_window"; then
	hyprctl dispatch movetoworkspacesilent special:hidden
else
	hyprctl dispatch killactive
fi
