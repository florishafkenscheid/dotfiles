#!/usr/bin/env bash
set -euo pipefail

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
    steam_app_* | cs2) printf '%s\n' "${ICONS[steam]}"; return ;;
    *minecraft* | *prismlauncher*) printf '%s\n' ":minecraft:"; return ;;
    *discord* | vesktop) printf '%s\n' "${ICONS[discord]}"; return ;;
    *zed*) printf '%s\n' "${ICONS[zed]}"; return ;;
  esac

  case "$title" in
    *discord*) printf '%s\n' "${ICONS[discord]}"; return ;;
  esac

  printf '%s\n' "${ICONS[default]}"
}

clients_json="$(hyprctl clients -j)"
workspaces_json="$(hyprctl workspaces -j)"
active_workspace_json="$(hyprctl activeworkspace -j)"

pairs="$(
  jq -r '
    .[]
    | select(.workspace.id > 0)
    | [
        (.workspace.id | tostring),
        ((.initialClass // .class // "") | ascii_downcase),
        ((.initialTitle // .title // "") | ascii_downcase)
      ]
    | @tsv
  ' <<<"$clients_json" |
    while IFS=$'\t' read -r wsid cls ttl; do
      icon="$(icon_for "$cls" "$ttl")"
      printf '%s\t%s\n' "$wsid" "$icon"
    done
)"

jq -n \
  --argjson workspaces "$workspaces_json" \
  --argjson active "$active_workspace_json" \
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
  [
    $workspaces[]
    | select(.id > 0 and (.name | test("^special:") | not))
    | {
        id: .id,
        name: .name,
        active: (.id == $active.id),
        icons: ($iconmap[(.id | tostring)] // [])
      }
  ]
  | sort_by(.id)
'
