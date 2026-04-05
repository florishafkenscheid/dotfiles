#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
VALUE="${2:-}"
STATE_FILE="/tmp/eww-tidal-volume"
CACHE_FILE="/tmp/eww-volume-cache"
LOCK_FILE="/tmp/eww-volume.lock"
CACHE_TTL_MS=1500

now_ms() {
  date +%s%3N
}

write_cache() {
  printf '%s %s %s %s %s\n' "$(now_ms)" "$1" "$2" "$3" "$4" > "$CACHE_FILE"
}

read_cache_percent() {
  local expected_target="$1"
  [[ -f "$CACHE_FILE" ]] || return 1

  local timestamp cached_target cached_percent cached_muted cached_active age current
  read -r timestamp cached_target cached_percent cached_muted cached_active < "$CACHE_FILE" || return 1

  current="$(now_ms)"
  age=$(( current - timestamp ))

  [[ "$cached_target" == "$expected_target" ]] || return 1
  (( age <= CACHE_TTL_MS )) || return 1

  printf '%s\n' "$cached_percent"
}

is_tidal_playing() {
  local status
  status="$(playerctl -p tidal-hifi status 2>/dev/null || true)"
  [[ "$status" == "Playing" ]]
}

icon_for_percent() {
  local value="$1"
  local is_muted="$2"

  if [[ "$is_muted" == "true" ]] || (( value <= 0 )); then
    printf '%s\n' "󰝟"
  elif (( value <= 20 )); then
    printf '%s\n' "󰕿"
  elif (( value <= 50 )); then
    printf '%s\n' "󰖀"
  else
    printf '%s\n' "󰕾"
  fi
}

clamp_percent() {
  local value="${1:-0}"
  awk -v value="$value" 'BEGIN {
    if (value < 0) value = 0
    if (value > 100) value = 100
    printf "%d", value + 0.5
  }'
}

get_player_percent() {
  local raw_volume
  raw_volume="$(playerctl -p tidal-hifi volume 2>/dev/null || printf '0')"
  awk -v value="$raw_volume" 'BEGIN { printf "%d", (value * 100) + 0.5 }'
}

set_player_percent() {
  local percent
  percent="$(clamp_percent "$1")"
  playerctl -p tidal-hifi volume "$(awk -v value="$percent" 'BEGIN { printf "%.2f", value / 100 }')"
}

set_system_percent() {
  local percent
  percent="$(clamp_percent "$1")"
  wpctl set-volume @DEFAULT_AUDIO_SINK@ "${percent}%"
}

emit_volume_data() {
  local target="$1"
  local percent="$2"
  local muted="$3"
  local active="$4"
  local icon
  icon="$(icon_for_percent "$percent" "$muted")"

  jq -cn \
    --arg target "$target" \
    --argjson percent "$percent" \
    --argjson muted "$muted" \
    --arg icon "$icon" \
    --argjson active "$active" \
    '{
      target: $target,
      percent: $percent,
      muted: $muted,
      icon: $icon,
      active: $active
    }'
}

toggle_player_mute() {
  local current restore
  current="$(read_cache_percent player 2>/dev/null || get_player_percent)"

  if (( current > 0 )); then
    printf '%s\n' "$current" > "$STATE_FILE"
    set_player_percent 0
    write_cache player 0 true true
    return
  fi

  if [[ -f "$STATE_FILE" ]]; then
    restore="$(<"$STATE_FILE")"
  else
    restore=50
  fi

  if [[ -z "$restore" || "$restore" == "0" ]]; then
    restore=50
  fi

  set_player_percent "$restore"
  write_cache player "$restore" false true
}

exec 9>"$LOCK_FILE"
flock 9

if is_tidal_playing; then
  target="player"
  active=true
  case "$ACTION" in
    set)
      percent="$(clamp_percent "$VALUE")"
      set_player_percent "$percent"
      muted="$([[ "$percent" -le 0 ]] && printf 'true' || printf 'false')"
      write_cache "$target" "$percent" "$muted" "$active"
      ;;
    scroll)
      current_percent="$(read_cache_percent player 2>/dev/null || get_player_percent)"
      case "$VALUE" in
        up)
          percent="$(( current_percent + 1 ))"
          ;;
        down)
          percent="$(( current_percent - 1 ))"
          ;;
      esac
      percent="$(clamp_percent "$percent")"
      set_player_percent "$percent"
      muted="$([[ "$percent" -le 0 ]] && printf 'true' || printf 'false')"
      write_cache "$target" "$percent" "$muted" "$active"
      ;;
    toggle-mute)
      toggle_player_mute
      percent="$(read_cache_percent player 2>/dev/null || get_player_percent)"
      muted="$([[ "$percent" -le 0 ]] && printf 'true' || printf 'false')"
      ;;
    *)
      exit 1
      ;;
  esac
else
  target="system"
  active=false
  case "$ACTION" in
    set)
      percent="$(clamp_percent "$VALUE")"
      set_system_percent "$percent"
      muted=false
      write_cache "$target" "$percent" "$muted" "$active"
      ;;
    scroll)
      current_percent="$(read_cache_percent system 2>/dev/null || wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{
        for (i = 1; i <= NF; ++i) {
          if ($i ~ /^[0-9]+(\.[0-9]+)?$/) {
            printf "%d", ($i * 100) + 0.5
            exit
          }
        }
      }')"
      case "$VALUE" in
        up)
          percent="$(( current_percent + 1 ))"
          ;;
        down)
          percent="$(( current_percent - 1 ))"
          ;;
      esac
      percent="$(clamp_percent "$percent")"
      set_system_percent "$percent"
      muted=false
      write_cache "$target" "$percent" "$muted" "$active"
      ;;
    toggle-mute)
      current_percent="$(read_cache_percent system 2>/dev/null || wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{
        for (i = 1; i <= NF; ++i) {
          if ($i ~ /^[0-9]+(\.[0-9]+)?$/) {
            printf "%d", ($i * 100) + 0.5
            exit
          }
        }
      }')"
      muted_state="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q '\[MUTED\]' && printf 'true' || printf 'false')"
      wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      if [[ "$muted_state" == "true" ]]; then
        percent="${current_percent:-0}"
        muted=false
      else
        percent="${current_percent:-0}"
        muted=true
      fi
      write_cache "$target" "$percent" "$muted" "$active"
      ;;
    *)
      exit 1
      ;;
  esac
fi

emit_volume_data "$target" "$percent" "$muted" "$active"
