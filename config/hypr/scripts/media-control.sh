#!/bin/sh

ACTION=$1

case "$ACTION" in
  PlayPause|play-pause|Play-Pause) action_kind="toggle" ;;
  Next|next) action_kind="next" ;;
  Previous|previous) action_kind="prev" ;;
  Pause|pause) action_kind="pause" ;;
  *) action_kind="other" ;;
esac

spotify_present() {
  playerctl -p spotify status >/dev/null 2>&1
}

spotify_playing() {
  [ "$(playerctl -p spotify status 2>/dev/null)" = "Playing" ]
}

any_other_playing() {
  playerctl -a status 2>/dev/null | grep -qx "Playing"
}

if ! spotify_present; then
    playerctl "$ACTION" 2>/dev/null
    exit $?
fi

case "$action_kind" in
    toggle)
        if spotify_playing; then
            playerctl -p spotify "$ACTION" 2>/dev/null
        elif any_other_playing; then
            playerctl "$ACTION"
        else
            playerctl -p spotify "$ACTION" 2>/dev/null
        fi
        ;;
    pause)
        if spotify_playing; then
            playerctl -p spotify "$ACTION" 2>/dev/null
        else
            playerctl "$ACTION" 2>/dev/null
        fi
        ;;
    next|prev|other)
        playerctl -p spotify "$ACTION" 2>/dev/null || playerctl "$ACTION" 2>/dev/null
        ;;
esac
