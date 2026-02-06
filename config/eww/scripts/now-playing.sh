#!/bin/bash
# Now playing script with TIDAL/MPRIS support
# Outputs JSON with title, artist, artUrl, and status

get_metadata() {
    local player_status
    local title
    local artist

    # Try to get the first active player (TIDAL, Spotify, etc.)
    player_status=$(playerctl status 2>/dev/null)

    if [ -z "$player_status" ] || [ "$player_status" = "Stopped" ]; then
        echo '{"title": "", "artist": "", "artUrl": "", "status": "Stopped"}'
        return
    fi

    title=$(playerctl metadata title 2>/dev/null || echo "")
    artist=$(playerctl metadata artist 2>/dev/null || echo "")

    # Escape special characters for JSON
    title=$(echo "$title" | sed 's/"/\\"/g' | tr '\n' ' ')
    artist=$(echo "$artist" | sed 's/"/\\"/g' | tr '\n' ' ')

    printf '{"title": "%s", "artist": "%s", "status": "%s"}\n' \
        "$title" "$artist" "$player_status"
}

# Initial output
get_metadata

# Follow changes
playerctl --follow metadata 2>/dev/null | while read -r _; do
    get_metadata
done
