#!/usr/bin/env bash
set -euo pipefail

target="system"
percent=0
muted=false
icon="󰖀"
active=false
CACHE_FILE="/tmp/eww-volume-cache"
CACHE_TTL_MS=1500

now_ms() {
  date +%s%3N
}

read_cache() {
  [[ -f "$CACHE_FILE" ]] || return 1

  local timestamp cached_target cached_percent cached_muted cached_active age current
  read -r timestamp cached_target cached_percent cached_muted cached_active < "$CACHE_FILE" || return 1

  current="$(now_ms)"
  age=$(( current - timestamp ))
  (( age <= CACHE_TTL_MS )) || return 1

  printf '%s %s %s %s\n' "$cached_target" "$cached_percent" "$cached_muted" "$cached_active"
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

if is_tidal_playing; then
  raw_volume="$(playerctl -p tidal-hifi volume 2>/dev/null || printf '0')"
  percent="$(awk -v value="$raw_volume" 'BEGIN { printf "%d", (value * 100) + 0.5 }')"
  target="player"
  muted=$([[ "$percent" -le 0 ]] && printf 'true' || printf 'false')
  active=true
else
  raw_volume="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || printf 'Volume: 0.00')"
  percent="$(awk '{
    for (i = 1; i <= NF; ++i) {
      if ($i ~ /^[0-9]+(\.[0-9]+)?$/) {
        printf "%d", ($i * 100) + 0.5
        exit
      }
    }
  }' <<<"$raw_volume")"
  percent="${percent:-0}"
  if grep -q '\[MUTED\]' <<<"$raw_volume"; then
    muted=true
  fi
fi

if cache_entry="$(read_cache 2>/dev/null)"; then
  read -r cached_target cached_percent cached_muted cached_active <<< "$cache_entry"
  if [[ "$cached_target" == "$target" ]]; then
    percent="$cached_percent"
    muted="$cached_muted"
    active="$cached_active"
  fi
fi

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
