![An image of my main screen highlighting my desktop environment](/images/fastfetch_screenshot.png)
## What?
This repository contains the configuration files (dotfiles) for my minimalist, yet aesthetically pleasing, Arch Linux desktop environment.

My philosophy for Arch is a bare bones, yet aesthetically pleasing, environment; mainly used to develop software, or otherwise just entertainment.
With "bare bones", I mean a lean system focussing on functionality and minimal overhead. This includes choices like:
- **systemd-boot & efibootmgr** over GRUB: For simpler boot management.
- **systemd-{networkd,resolvd}** over NetworkManager: This PC will not connect to anything other than ethernet.
- **NeoVim** over VSCode: Prioritizing a customizable and keyboard-driven editor seems fitting for this setup.

The theme is based on the Dune movies, focussing on the vibrant oranges used in the cinematography.

> [!IMPORTANT]
> These files are symlinked to the right place using [GNU Stow](https://brandon.invergo.net/news/2012-05-26-using-gnu-stow-to-manage-your-dotfiles.html).

## Desktop sessions

Hyprland/Eww remains the gaming and entertainment session. Niri/Quickshell is
an independent development session: both sets of configuration coexist under
`~/.config` and only the selected compositor starts its own shell and helpers.

Greetd starts `~/.config/desktop/session`, which keeps the authenticated login
alive while a compositor is running. Use `Super+Shift+D` or click the Arch
logo in either bar to switch. Open clients are closed during this
first-iteration handoff. A normal logout returns to greetd.

`F3` in tuigreet selects the initial session. Hyprland is still the default.

Both sessions explicitly inherit the same `CODEX_HOME` (normally
`~/.codex`). Codex user configuration, profiles, skills, authentication, and
resumable session state therefore stay in sync automatically. That live,
sensitive state is intentionally not copied into this repository; project
overrides such as `.codex/config.toml` remain shared through the project
filesystem as usual.

Suspending individual graphical clients is not enough to preserve them during
the current handoff: their Wayland or Xwayland connection belongs to the
compositor that exits. For low-risk experimentation, run Niri nested inside
Hyprland so both it and its clients remain alive in a normal Hyprland window.
A future native, client-preserving mode would instead keep both compositors
alive on separate VTs and switch between them; that also needs deliberate
isolation of each session's portals, D-Bus activation environment, and other
per-session services.

The Niri session currently expects these additional Arch packages:

```sh
sudo pacman -S niri quickshell swaybg xwayland-satellite
```

Add `xdg-desktop-portal-gnome` when Niri screencasting is needed; the existing
GTK portal continues to cover the basic fallback portal features.

After stowing `config`, install the updated greetd file with the existing
root-targeted `etc` stow workflow. Install the tracked session shim into
`/usr/local/bin`, which is part of greetd's authenticated-session `PATH`, then
log out once so greetd starts the new session supervisor:

```sh
sudo ln -s /home/blousy/dotfiles/local/bin/desktop-session \
    /usr/local/bin/desktop-session
```

The future multi-theme layout is documented in
`~/.config/desktop/themes/README.md`; Dune remains the only implemented theme.

## Progress
> [!NOTE]
> ↩️ means somehow linked to the next point, ⏳ means currently WIP.

- [x] Keybinds - `~/.config/hypr/hyprland.conf`
- [x] Zsh - `~/.zshrc`
- [x] Starship - `~/.config/starship.toml`
- [x] NeoVim - `~/.config/nvim/`
  - [x] `lazy`
  - [x] `lspconfig`
  - [x] `lualine`
  - [x] `lush`
  - [x] `mason`
  - [x] `mason-lspconfig`
  - [x] `nvim-tree`
  - [x] `telescope`
  - [x] `treesitter`
  - [x] `web-devicons`
- [ ] Kitty - `~/.config/kitty/`
- [ ] ~~Waybar - `~/.config/waybar/`~~ ↩️ *(Replaced by EWW)*
- [x] EWW - `~/.config/eww/`
- [ ] Niri - `~/.config/niri/` ⏳
- [ ] Quickshell - `~/.config/quickshell/blousy/` ⏳
- [x] hypridle - `~/.config/hypr/hypridle.conf`
- [x] tuigreet - `/etc/greetd/config.toml`
- [x] fastfetch - `~/.config/fastfetch/config.jsonc`
- [x] rofi - `~/.config/rofi/config.rasi`
- [ ] mako⏳ - `~/.config/mako/config`
- [ ] ~~mopidy~~ ↩️ *(Spotify integration issues)*
- [ ] ~~mpd~~ ↩️
- [ ] ~~rmpc~~
- [ ] spotify-player - `~/.config/spotify-player/app.toml`

### EWW
> [!NOTE]
> Some ideas on what to display using EWW as the top bar.
- CPU & GPU usage in %
    - Clickable for temps?
- Memory Usage (percentage? gb free?)
- Mullvad status
- Time
- Spaces in middle or left, with name or icon of active window(s)
- Spotify now playing

### Idle Screensaver
- `hypridle` starts a non-locking idle screensaver after 3 minutes.
- The helper script is `~/.config/hypr/scripts/idle-screensaver.sh`.
- The primary monitor switches to an empty workspace while the screensaver is active and restores the previous workspace on resume.
- Runtime dependencies: `hypridle`, `mpvpaper`, and `mpv`.
- Set `SCREENSAVER_VIDEO` in the script, or override it through the environment before starting Hyprland.

### Steam Idle Exit
- `steam-idle-exit.timer` closes Steam after no game has been active for 5 minutes.
- Enable it with `systemctl --user enable --now steam-idle-exit.timer` after stowing `config`.

## Future
For when I eventually get sick of this, or I simply want to try out different DE's, WM's, widget systems etc, I am compiling a list of interesting, yet not necessarily related projects to use.

### [Caelestia](https://github.com/caelestia-dots)
- [Quickshell](https://quickshell.outfoxxed.me/)
- [Foot](https://codeberg.org/dnkl/foot)
