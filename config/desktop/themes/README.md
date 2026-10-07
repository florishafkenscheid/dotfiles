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
- Codex CLI

Hyprland and Mako are reloaded immediately. New terminals pick up the generated
Fastfetch and Starship configs; new Neovim processes read the selected
colorscheme. Existing shells and Neovim processes are deliberately not
recolored underneath active work.

Zen's existing userChrome loader runs a tiny managed hook that watches the
generated palette. Installing the hook requires one Zen restart; theme changes
hot-reload after that.

Codex CLI gets a `blousy-<id>.tmTheme` for every catalog entry under
`$CODEX_HOME/themes` (default: `~/.codex/themes`). Applying a desktop theme
updates only `tui.theme` in Codex's `config.toml`, preserving other settings.
New Codex sessions use the selected palette; existing sessions can select it
with `/theme`. Theme previews do not change Codex settings. Adding a catalog
entry automatically adds a Codex palette on the next apply.
Shell commands use the bright accent and bold text, flags use the main accent,
quoted strings use the success color, and unquoted arguments use the foreground.
Shell variable expansions use the bright accent.

The Codex integration requires Python 3.11 or newer. To sync only Codex without
reloading the desktop, run:

```sh
python3 ~/.config/desktop/codex-theme.py \
    ~/.config/desktop/themes/catalog.json "$(~/.config/desktop/theme current)"
```

Wallpaper paths may use `$HOME`, or are resolved relative to this directory.
Add another object to the `themes` array to add another card; no QML edits are
needed.

Hyprland uses the Quickshell bar, wallpaper, and switcher.
