#!/bin/bash

declare -A APP_ICONS=(
  ["kitty"]=":kitty:"
  ["vesktop"]=":discord:"
  ["obsidian"]=":obsidian:"
  ["zen"]=":zen_browser:"
  ["spotify"]=":spotify:"
  ["Spotify"]=":spotify:"
  ["steam"]=":steam:"
  ["factorio"]=":gear_old:"
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

hyprctl workspaces -j | jq --argjson clients "$(hyprctl clients -j)" --argjson active "$(hyprctl activeworkspace -j)" --argjson icons "$(icons_to_json)" '
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
            | if .class == "kitty" and (.title | test("spotify"; "i")) then
                "spotify"
            else
                .class
            end
        )
        | unique
        | map(
            if $icons[.] then $icons[.] else "" end
          )
      )
    }
] | sort_by(.id)'
