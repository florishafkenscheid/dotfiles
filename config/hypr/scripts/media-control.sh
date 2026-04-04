#!/bin/sh

# Media control script with rofi-based player selection
# When multiple players are active, shows a menu to choose which to control
# Remembers the last selection until that player exits

ACTION=$1
STATE_FILE="/tmp/media-control-last-player"

# Map common action names to playerctl commands
case "$ACTION" in
    PlayPause|play-pause|Play-Pause) playerctl_action="play-pause" ;;
    Next|next) playerctl_action="next" ;;
    Previous|previous|Prev|prev) playerctl_action="previous" ;;
    Pause|pause) playerctl_action="pause" ;;
    Play|play) playerctl_action="play" ;;
    Stop|stop) playerctl_action="stop" ;;
    *) playerctl_action="$ACTION" ;;
esac

# Player groups: players on same line are considered equivalent
# First one is preferred (shown when multiple from group exist)
# Use simple patterns: exact match or *wildcard*
PLAYER_GROUPS='tidal-hifi *chromium*'

# Check if player matches pattern (supports * wildcards)
matches_pattern() {
    case "$1" in
        $2) return 0 ;;
        *) return 1 ;;
    esac
}

# Get the preferred player from a group based on available players
get_preferred_from_group() {
    local group="$1"
    local all_players="$2"
    local pattern player
    
    for pattern in $group; do
        while IFS= read -r player; do
            if matches_pattern "$player" "$pattern"; then
                echo "$player"
                return 0
            fi
        done <<< "$all_players"
    done
}

# Get list of active players with grouping applied
get_players() {
    local all_players
    all_players=$(playerctl -l 2>/dev/null | grep -v "^No players" || true)
    
    [ -z "$all_players" ] && return
    
    local result=""
    local grouped_players=""
    local player group pattern
    
    # Process each group
    while IFS= read -r group; do
        [ -z "$group" ] && continue
        
        local preferred
        preferred=$(get_preferred_from_group "$group" "$all_players")
        
        if [ -n "$preferred" ]; then
            # Check if multiple players from this group are running
            local count=0
            for pattern in $group; do
                while IFS= read -r player; do
                    if matches_pattern "$player" "$pattern"; then
                        count=$((count + 1))
                    fi
                done <<< "$all_players"
            done
            
            # If 2+ from group, use preferred and mark others as grouped
            if [ "$count" -ge 2 ]; then
                result="$result${result:+
}$preferred"
                for pattern in $group; do
                    grouped_players="$grouped_players${grouped_players:+
}$pattern"
                done
            fi
        fi
    done <<< "$PLAYER_GROUPS"
    
    # Add non-grouped players
    while IFS= read -r player; do
        [ -z "$player" ] && continue
        
        local is_grouped=0
        while IFS= read -r pattern; do
            if matches_pattern "$player" "$pattern"; then
                is_grouped=1
                break
            fi
        done <<< "$grouped_players"
        
        if [ "$is_grouped" -eq 0 ]; then
            result="$result${result:+
}$player"
        fi
    done <<< "$all_players"
    
    echo "$result"
}

# Get status icon for a player
get_status_icon() {
    local player="$1"
    local status
    status=$(playerctl -p "$player" status 2>/dev/null)
    case "$status" in
        Playing) echo "🎵" ;;
        Paused) echo "⏸️" ;;
        Stopped) echo "⏹️" ;;
        *) echo "🔇" ;;
    esac
}

# Get formatted player info for rofi: "icon player    status    title - artist"
get_player_info() {
    local player="$1"
    local icon status title artist
    icon=$(get_status_icon "$player")
    status=$(playerctl -p "$player" status 2>/dev/null)
    title=$(playerctl -p "$player" metadata title 2>/dev/null | cut -c1-30)
    artist=$(playerctl -p "$player" metadata artist 2>/dev/null | cut -c1-30)
    
    # Format: icon player (padded) status (padded) title - artist
    printf "%-4s %-25s %-10s %s" "$icon" "$player" "$status" "${title:+$title}${artist:+ - $artist}"
}

# Show rofi menu and return selected player name
# $1 = players list, $2 = index to pre-select (optional)
show_rofi_menu() {
    local players="$1"
    local selected_idx="${2:-0}"
    local menu_items=""
    local player
    
    # Build menu with player info
    while IFS= read -r player; do
        [ -z "$player" ] && continue
        menu_items="${menu_items}$(get_player_info "$player")\n"
    done <<< "$players"
    
    # Remove trailing newline and show rofi
    menu_items=$(printf "%b" "$menu_items")
    
    # Show rofi, get selection (pre-select saved player)
    local selection
    selection=$(printf "%b" "$menu_items" | rofi -dmenu -i -p "Control Media" -selected-row "$selected_idx" -theme-str 'listview { lines: 6; }')
    
    # Extract player name (second column, trimmed)
    if [ -n "$selection" ]; then
        echo "$selection" | awk '{print $2}'
    fi
}

# Find index of player in list (0-based), return -1 if not found
get_player_index() {
    local players="$1"
    local target="$2"
    local idx=0
    local player
    while IFS= read -r player; do
        [ -z "$player" ] && continue
        if [ "$player" = "$target" ]; then
            echo "$idx"
            return
        fi
        idx=$((idx + 1))
    done <<< "$players"
    echo "-1"
}

# Save selected player to state file
save_selected_player() {
    printf '%s' "$1" > "$STATE_FILE"
}

# Get saved player if still active
get_saved_player() {
    if [ -f "$STATE_FILE" ]; then
        local saved
        # Read file and trim whitespace/newlines
        saved=$(tr -d '[:space:]' < "$STATE_FILE" 2>/dev/null)
        [ -z "$saved" ] && return
        # Check if saved player is still active (check raw playerctl list)
        if playerctl -l 2>/dev/null | grep -qx "$saved"; then
            printf '%s' "$saved"
        fi
    fi
}

# Get player status, normalizing empty/error responses
get_player_status() {
    local player="$1"
    local status
    status=$(playerctl -p "$player" status 2>/dev/null || true)

    case "$status" in
        Playing|Paused|Stopped) printf '%s\n' "$status" ;;
        *) printf '%s\n' "Unknown" ;;
    esac
}

# Return the single playing player, or nothing if selection is ambiguous
get_single_playing_player() {
    local players="$1"
    local playing_player=""
    local playing_count=0
    local player status

    while IFS= read -r player; do
        [ -z "$player" ] && continue

        status=$(get_player_status "$player")
        if [ "$status" = "Playing" ]; then
            playing_count=$((playing_count + 1))
            playing_player="$player"
        fi
    done <<< "$players"

    if [ "$playing_count" -eq 1 ]; then
        printf '%s\n' "$playing_player"
    fi
}

# Main logic
main() {
    local players
    players=$(get_players)
    
    # No players available
    if [ -z "$players" ]; then
        notify-send "Media Control" "No media players running" 2>/dev/null || true
        exit 1
    fi
    
    # Count players
    local player_count
    player_count=$(echo "$players" | wc -l)
    
    local target_player=""
    
    # If only one player, use it directly (no menu needed)
    if [ "$player_count" -eq 1 ]; then
        target_player="$players"
        save_selected_player "$target_player"
    else
        target_player=$(get_single_playing_player "$players")

        # Multiple players only need the menu when state does not identify one target
        if [ -n "$target_player" ]; then
            save_selected_player "$target_player"
        else
        # Get saved player to pre-select it
            local saved_player
            local selected_idx=0
            saved_player=$(get_saved_player)

            # Find index of saved player for pre-selection
            if [ -n "$saved_player" ]; then
                selected_idx=$(get_player_index "$players" "$saved_player")
                [ "$selected_idx" -lt 0 ] && selected_idx=0
            fi

            target_player=$(show_rofi_menu "$players" "$selected_idx")

            # User cancelled rofi
            if [ -z "$target_player" ]; then
                exit 0
            fi

            # Validate selection is still valid
            if ! echo "$players" | grep -qx "$target_player"; then
                notify-send "Media Control" "Selected player no longer available" 2>/dev/null || true
                exit 1
            fi

            save_selected_player "$target_player"
        fi
    fi
    
    # Execute action on selected player
    playerctl -p "$target_player" "$playerctl_action" 2>/dev/null
    
    exit $?
}

main
