#!/bin/sh
set -e

SCREENSHOT_DIR="$HOME/Desktop/Screenshots"
mkdir -p "$SCREENSHOT_DIR"
FILENAME="$SCREENSHOT_DIR/$(date +'%Y-%m-%d_%H-%M-%S').png"

# 1. Launch wayfreeze in the background
wayfreeze --hide-cursor &
WAYFREEZE_PID=$! # Capture the PID (the sh equivalent of $last_pid)

# 2. Give wayfreeze a moment to start up
sleep 0.1

# 3. Run the capture pipeline. If slurp is cancelled, `set -e` will stop the script.
grim -g "$(slurp)" - | tee "$FILENAME" | wl-copy

# 4. Kill the wayfreeze process now that grim/slurp is done.
#    The `|| true` prevents the script from erroring if the process is already gone.
kill "$WAYFREEZE_PID" || true

# 5. Send the notification.
notify-send "Screenshot" "Saved and copied" -i "$FILENAME"
