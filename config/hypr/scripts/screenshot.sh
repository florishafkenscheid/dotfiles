#!/bin/sh
SCREENSHOT_DIR="$HOME/Desktop/Screenshots"
mkdir -p "$SCREENSHOT_DIR"
FILENAME="$SCREENSHOT_DIR/$(date +'%Y-%m-%d_%H-%M-%S').png"
TEMP_PNG=$(mktemp --suffix=".png")

wayfreeze --hide-cursor &
WAYFREEZE_PID=$! # Capture the PID

trap "kill \"$WAYFREEZE_PID\" || true; rm -f \"$TEMP_PNG\"" EXIT

sleep 0.1

GEOMETRY=$(slurp)

if [ -z "$GEOMETRY" ]; then
    notify-send "Screenshot Cancelled" "Selection was cancelled."
    exit 0
fi

if grim -g "$GEOMETRY" "$TEMP_PNG"; then
    if [ -s "$TEMP_PNG" ]; then
        cat "$TEMP_PNG" | tee "$FILENAME" | wl-copy
        notify-send "Screenshot" "Saved and copied" -i "$FILENAME" -t 10000
    else
        notify-send "Screenshot Failed" "Grim created an empty image file for the selection."
    fi
else
    notify-send "Screenshot Failed" "Grim encountered an error while capturing the screen."
fi
