#!/bin/sh

# Approximate one ultrawide workspace across Niri's independent output stacks.
# Switch the inactive outputs first, then restore the original output and apply
# the requested focus/move there so keyboard focus never ends up elsewhere.

set -u

action="${1:-}"
reference="${2:-}"

case "$action" in
    focus | move) ;;
    *)
        printf 'Usage: %s focus|move INDEX|up|down\n' "$0" >&2
        exit 2
        ;;
esac

workspaces="$(niri msg --json workspaces)" || exit 1
outputs="$(niri msg --json outputs)" || exit 1

original_output="$(
    printf '%s\n' "$workspaces" |
        jq -r '.[] | select(.is_focused) | .output' |
        head -n 1
)"
current_index="$(
    printf '%s\n' "$workspaces" |
        jq -r '.[] | select(.is_focused) | .idx' |
        head -n 1
)"

[ -n "$original_output" ] || exit 1
case "$current_index" in
    "" | *[!0-9]*) exit 1 ;;
esac

case "$reference" in
    up)
        target_index=$((current_index - 1))
        if [ "$target_index" -lt 1 ]; then
            target_index=1
        fi
        ;;
    down)
        target_index=$((current_index + 1))
        ;;
    *[!0-9]* | "") exit 2 ;;
    *) target_index="$reference" ;;
esac

if [ "$target_index" -lt 1 ]; then
    exit 2
fi

ordered_outputs="$(
    printf '%s\n' "$outputs" |
        jq -r '
            to_entries |
            sort_by(.value.logical.x, .value.logical.y) |
            .[].key
        '
)"

sync_failed=0
for output in $ordered_outputs; do
    [ "$output" = "$original_output" ] && continue

    if ! niri msg action focus-monitor "$output" >/dev/null ||
        ! niri msg action focus-workspace "$target_index" >/dev/null; then
        sync_failed=1
        break
    fi
done

niri msg action focus-monitor "$original_output" >/dev/null || exit 1
[ "$sync_failed" -eq 0 ] || exit 1

case "$action" in
    focus)
        niri msg action focus-workspace "$target_index" >/dev/null
        ;;
    move)
        niri msg action move-column-to-workspace "$target_index" >/dev/null
        ;;
esac
