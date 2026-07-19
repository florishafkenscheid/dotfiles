#!/usr/bin/env bash
set -euo pipefail

monitor_filter="${1:-}"

declare -A ICONS=(
  ["kitty"]=":kitty:"
  ["discord"]=":discord:"
  ["vesktop"]=":discord:"
  ["obsidian"]=":obsidian:"
  ["zen"]=":zen_browser:"
  ["firefox"]=":firefox:"
  ["spotify"]=":spotify:"
  ["steam"]=":steam:"
  ["factorio"]=":gear_old:"
  ["jellyfin"]=":jellyfin:"
  ["rofi"]=":spotlight:"
  ["tor browser"]=":tor_browser:"
  ["tidal-hifi"]=":tidal:"
  ["filezilla"]=":filezilla:"
  ["zed"]=":zed:"
  ["mpv"]=":mpv:"
  ["lm studio"]=":lm_studio:"
  ["default"]=":default:"
  ["code"]=":code:"
  ["gimp"]=":gimp:"
  ["thunar"]=":finder:"
  ["slack"]=":slack:"
)

icon_for() {
  local class="${1:-}"
  local title="${2:-}"

  # exact matches first
  if [[ -n "${class}" && -n "${ICONS[$class]+x}" ]]; then
    printf '%s\n' "${ICONS[$class]}"
    return
  fi
  if [[ -n "${title}" && -n "${ICONS[$title]+x}" ]]; then
    printf '%s\n' "${ICONS[$title]}"
    return
  fi

  # patterns / aliases
  case "$class" in
    steam_app_* | cs2 | gamescope) printf '%s\n' "${ICONS[steam]}"; return ;;
    *minecraft* | *prismlauncher*) printf '%s\n' ":minecraft:"; return ;;
    *discord* | vesktop) printf '%s\n' "${ICONS[discord]}"; return ;;
    *zed*) printf '%s\n' "${ICONS[zed]}"; return ;;
    *factorio*) printf '%s\n' "${ICONS[factorio]}"; return ;;
  esac

  case "$title" in
    *discord*) printf '%s\n' "${ICONS[discord]}"; return ;;
  esac

  printf '%s\n' "${ICONS[default]}"
}

batch_json="$(
  hyprctl --batch "j/clients;j/workspaces;j/monitors" | jq -cs .
)"

pairs="$(
  jq -r '
    .[0][]
    | select(.workspace.id > 0)
    | [
        (.workspace.id | tostring),
        ((.initialClass // .class // "") | ascii_downcase),
        ((.initialTitle // .title // "") | ascii_downcase)
      ]
    | @tsv
  ' <<<"$batch_json" |
    while IFS=$'\t' read -r wsid cls ttl; do
      icon="$(icon_for "$cls" "$ttl")"
      printf '%s\t%s\n' "$wsid" "$icon"
    done
)"

jq -n \
  --argjson workspaces "$(jq -c '.[1]' <<<"$batch_json")" \
  --argjson monitors "$(jq -c '.[2]' <<<"$batch_json")" \
  --arg monitor_filter "$monitor_filter" \
  --arg pairs "$pairs" '
  def parse_pairs($s):
    ($s
     | split("\n")
     | map(select(length > 0) | split("\t"))
     | map({ id: (.[0] | tonumber), icon: .[1] })
     | sort_by(.id));

  (
    parse_pairs($pairs)
    | group_by(.id)
    | map({ (.[0].id | tostring): (map(.icon) | unique) })
    | add
  ) // {} as $iconmap
  |
  (
    $monitors
    | map({
        key: (.name // (.id | tostring)),
        value: (.activeWorkspace.id // 0)
      })
    | from_entries
  ) as $active_by_monitor
  |
  [
    $workspaces[]
    | select(.id > 0 and (.name | test("^special:") | not))
    | select(
        $monitor_filter == ""
        or .monitor == $monitor_filter
        or ((.monitorID // -1) | tostring) == $monitor_filter
      )
    | {
        id: .id,
        name: .name,
        active: (.id == ($active_by_monitor[(.monitor // ((.monitorID // -1) | tostring))] // 0)),
        icons: ($iconmap[(.id | tostring)] // [])
      }
  ]
  | sort_by(.id)
'
