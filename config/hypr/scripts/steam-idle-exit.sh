#!/bin/sh

idle_seconds=300
state_file="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/steam-idle-since"
user_id=$(id -u)

steam_running() {
  pgrep -u "$user_id" -x steam >/dev/null ||
    pgrep -u "$user_id" -x steamwebhelper >/dev/null
}

game_running() {
  pgrep -u "$user_id" -f 'reaper SteamLaunch AppId=[0-9][0-9]*' >/dev/null
}

if ! steam_running || game_running; then
  rm -f "$state_file"
  exit 0
fi

now=$(date +%s)
if [ ! -r "$state_file" ]; then
  printf '%s\n' "$now" >"$state_file"
  exit 0
fi
read -r idle_since <"$state_file" || idle_since=

case "$idle_since" in
  '' | *[!0-9]*)
    printf '%s\n' "$now" >"$state_file"
    exit 0
    ;;
esac

[ "$((now - idle_since))" -ge "$idle_seconds" ] || exit 0

steam -shutdown || true
sleep 10

# Do not interrupt a game launched during Steam's shutdown grace period.
if game_running; then
  rm -f "$state_file"
  exit 0
fi

pkill -TERM -u "$user_id" -x steamwebhelper 2>/dev/null || true
pkill -TERM -u "$user_id" -x steam 2>/dev/null || true
rm -f "$state_file"
