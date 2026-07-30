#!/usr/bin/env bash
set -euo pipefail

if ! status="$(playerctl -p tidal-hifi status 2>/dev/null)"; then
  printf '%s\n' '{"title":"Nothing Playing","artist":""}'
  exit 0
fi

if [[ "$status" != "Playing" ]]; then
  printf '%s\n' '{"title":"Nothing Playing","artist":""}'
  exit 0
fi

title="$(playerctl -p tidal-hifi metadata title 2>/dev/null || true)"
artist="$(playerctl -p tidal-hifi metadata artist 2>/dev/null || true)"

if [[ -z "$title" ]]; then
  printf '%s\n' '{"title":"Nothing Playing","artist":""}'
  exit 0
fi

jq -cn --arg title "$title" --arg artist "$artist" '{title: $title, artist: $artist}'
