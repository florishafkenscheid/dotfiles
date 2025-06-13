#!/bin/sh
set -e # Exit safely when slurp is cancelled

screenshot_dir="$HOME/Desktop/Screenshots"

wayfreeze --hide-cursor --after-freeze-cmd 'grim -g "$(slurp)" - | tee '"$screenshot_dir/"'$(date +'%s_grim.png') | wl-copy; killall wayfreeze'
