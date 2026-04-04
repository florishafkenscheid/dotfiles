#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
snapshot_script="$script_dir/get-workspace-labels.sh"
monitor_filter="${1:-}"

emit_snapshot() {
  "$snapshot_script" "$monitor_filter" | jq -c .
}

last_payload=""

emit_if_changed() {
  local payload
  if ! payload="$(emit_snapshot 2>/dev/null)"; then
    return 0
  fi

  if [[ "$payload" != "$last_payload" ]]; then
    printf '%s\n' "$payload"
    last_payload="$payload"
  fi
}

event_requires_refresh() {
  local event_name="${1%%>>*}"

  case "$event_name" in
    workspacev2 | focusedmonv2 | createworkspacev2 | destroyworkspacev2 | moveworkspacev2 | renameworkspace | activespecialv2 | openwindow | closewindow | movewindowv2 | windowtitlev2)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

socket_path() {
  printf '%s\n' "${XDG_RUNTIME_DIR:?}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:?}/.socket2.sock"
}

wait_for_socket() {
  local socket
  socket="$(socket_path)"

  while [[ ! -S "$socket" ]]; do
    sleep 1
  done
}

main() {
  while true; do
    wait_for_socket
    emit_if_changed

    if ! nc -U "$(socket_path)" | while IFS= read -r event_line; do
      if event_requires_refresh "$event_line"; then
        emit_if_changed
      fi
    done; then
      sleep 1
    fi

    sleep 1
  done
}

main
