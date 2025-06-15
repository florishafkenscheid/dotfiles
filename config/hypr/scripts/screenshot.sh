#!/bin/sh
set -e

SCREENSHOT_DIR="$HOME/Desktop/Screenshots"
mkdir -p "$SCREENSHOT_DIR"
FILENAME="$SCREENSHOT_DIR/$(date +'%Y-%m-%d_%H-%M-%S').png"

wayfreeze --hide-cursor &
WAYFREEZE_PID=$! # Capture the PID

sleep 0.1

grim -g "$(slurp)" - | tee "$FILENAME" | wl-copy

kill "$WAYFREEZE_PID" || true

notify-send "Screenshot" "Saved and copied" -i "$FILENAME"
