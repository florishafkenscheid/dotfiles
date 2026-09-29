# Theme catalog

`catalog.json` is the intentionally small source of truth for the desktop
theme. Every entry supplies its wallpaper, switcher preview,
fastfetch image, Neovim colorscheme, and palette tokens.

The switcher is available as a desktop application or with `Super+Shift+T`.
Browse with the mouse, wheel, arrow keys, or `h`/`l`; press Enter or click the
center card to apply. Browsing is a temporary live preview. Applying persists
the selected ID in `~/.local/state/blousy/theme` and atomically generates the
small native fragments used by:

- Hyprland
- Fastfetch
- Neovim
- Starship
- Mako
- Rofi
- Zen Browser

Hyprland and Mako are reloaded immediately. New terminals pick up the generated
Fastfetch and Starship configs; new Neovim processes read the selected
colorscheme. Existing shells and Neovim processes are deliberately not
recolored underneath active work.

Zen's existing userChrome loader runs a tiny managed hook that watches the
generated palette. Installing the hook requires one Zen restart; theme changes
hot-reload after that.

Wallpaper paths may use `$HOME`, or are resolved relative to this directory.
Add another object to the `themes` array to add another card; no QML edits are
needed.

Hyprland uses the Quickshell bar, wallpaper, and switcher.
