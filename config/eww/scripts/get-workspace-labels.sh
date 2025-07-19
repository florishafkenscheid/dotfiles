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

hyprctl workspaces -j | jq --argjson clients "$clients" --argjson active "$active_workspace" --argjson icons "$icons_json" '
[
  .[]
  | select(.id > 0 and (.name | test("^special:") | not))
  | .id as $id
  | {
      id: $id,
      name,
      active: ($id == $active.id),
      icons: (
        $clients
        | map(
            select(.workspace.id == $id)
            | (.initialTitle? | ascii_downcase // "__app_not_found__") as $app_key_candidate
            | if $icons[$app_key_candidate] then
                $icons[$app_key_candidate]
              else
                $icons["default"]
              end
          )
        | unique
      )
    }
] | sort_by(.id)'
