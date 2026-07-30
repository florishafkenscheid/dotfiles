#!/usr/bin/env bash
set -euo pipefail

empty='{"title":"Nothing Playing","artist":""}'
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
state_dir="${runtime_dir}/blousy-desktop-shared"
state_file="${state_dir}/now-playing.json"
max_age=6

publish() {
  local title="$1"
  local artist="$2"
  local now temporary

  now="$(date +%s)"
  mkdir -p "$state_dir"
  chmod 700 "$state_dir"
  temporary="$(mktemp "${state_file}.XXXXXX")"

  jq -cn \
    --arg title "$title" \
    --arg artist "$artist" \
    --argjson updated "$now" \
    '{title: $title, artist: $artist, updated: $updated}' >"$temporary"
  mv "$temporary" "$state_file"

  jq -cn --arg title "$title" --arg artist "$artist" \
    '{title: $title, artist: $artist}'
}

if status="$(playerctl -p tidal-hifi status 2>/dev/null)"; then
  if [[ "$status" == "Playing" ]]; then
    title="$(playerctl -p tidal-hifi metadata title 2>/dev/null || true)"
    artist="$(playerctl -p tidal-hifi metadata artist 2>/dev/null || true)"

    if [[ -n "$title" ]]; then
      publish "$title" "$artist"
      exit 0
    fi
  fi

  publish "Nothing Playing" ""
  exit 0
fi

if [[ -r "$state_file" ]]; then
  now="$(date +%s)"
  cutoff=$((now - max_age))
  cached="$(
    jq -ce --argjson cutoff "$cutoff" '
      select(
        (.updated | type) == "number"
        and .updated >= $cutoff
        and (.title | type) == "string"
        and (.artist | type) == "string"
      )
      | {title, artist}
    ' "$state_file" 2>/dev/null || true
  )"

  if [[ -n "$cached" ]]; then
    printf '%s\n' "$cached"
    exit 0
  fi
fi

printf '%s\n' "$empty"
