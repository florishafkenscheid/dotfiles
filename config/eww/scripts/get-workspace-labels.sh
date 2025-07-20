#!/bin/bash

declare -A APP_ICONS=(
  ["kitty"]=":kitty:"
  ["discord"]=":discord:"
  ["obsidian"]=":obsidian:"
  ["zen browser"]=":zen_browser:"
  ["firefox"]=":firefox:"
  ["spotify"]=":spotify:"
  ["steam"]=":steam:"
  ["factorio"]=":gear_old:"
  ["jellyfin media player"]=":jellyfin:"
  ["default"]=":default:"
)

icons_to_json() {
    local json="{"
    for key in "${!APP_ICONS[@]}"; do
        json+="\"$key\":\"${APP_ICONS[$key]}\","
    done
    json="${json%,}"
    json+="}"
    echo "$json"
}

clients=$(hyprctl clients -j)
workspaces=$(hyprctl workspaces -j)
active_workspace=$(hyprctl activeworkspace -j)
icons_json=$(icons_to_json)

echo "$workspaces" | jq --slurpfile clients <(echo "$clients") \
                           --argjson active "$active_workspace" \
                           --argjson icons "$icons_json" '
[
  .[]
  | select(.id > 0 and (.name | test("^special:") | not))
  | .id as $workspace_id
  | {
      id: $workspace_id,
      name,
      active: (.id == $active.id),
      icons: (
        $clients[0]
        | map(
            select(.workspace.id == $workspace_id)
            | $icons[(.initialClass? | ascii_downcase)] // $icons[(.initialTitle? | ascii_downcase)] // $icons["default"]
          )
        | unique
      )
    }
] | sort_by(.id)
'

