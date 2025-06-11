#!/bin/sh
set -e # Exit safely when slurp is cancelled

screenshot_dir="$HOME/Desktop/Screenshots"

grim -g "$(slurp)" - | tee $screenshot_dir/$(date +'%s_grim.png') | wl-copy
