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

Hyprland/Eww remains the gaming and entertainment desktop. Niri/Quickshell is
the development desktop. Both compositors are logged in automatically at boot:
Niri starts on VT2 first, then Hyprland starts on VT1 and remains visible.

Use `Super+Shift+D` or click the plain Arch logo in either bar to switch.
The switcher asks logind to activate the other session, so both compositors and
their clients stay alive. No `Ctrl+Alt+F1/F2` is needed. The inactive desktop
continues running rather than being frozen; media, builds, downloads, and GPU
clients may therefore keep consuming resources.

Each compositor runs on a private D-Bus session bus and owns its own
notifications and graphical helpers. Session-specific Wayland state is not
imported into the shared systemd user manager. This reduces cross-session
activation mistakes while retaining the same Unix account and home directory.

Zen keeps one shared browser profile. Because Firefox-family profiles cannot be
opened by two processes concurrently, invoking Zen from the other desktop asks
the existing process to shut down, waits for the profile lock to be released,
and relaunches Zen on the invoking desktop. This preserves browser state without
splitting the profile or switching VTs.

Autologin means anyone with physical access after boot can use both unlocked
desktops. Greetd runs each initial session once per boot; deliberately logging
out of one desktop returns that VT to tuigreet instead of immediately logging
it back in. Portal behavior, application singletons, and hardware acceleration
across an inactive VT should be checked after the first reboot.

Both sessions explicitly inherit the same `CODEX_HOME` (normally
`~/.codex`). Codex user configuration, profiles, skills, authentication, and
resumable session state therefore stay in sync automatically. That live,
sensitive state is intentionally not copied into this repository; project
overrides such as `.codex/config.toml` remain shared through the project
filesystem as usual.

The original compositor handoff remains available as a rollback. Start a
`desktop-session` greetd entry manually (or run it from a TTY) and the same
switch command detects that it is not in persistent mode, then closes the
current compositor and launches the other one. Its implementation lives in
`~/.config/desktop/switch-handoff`.

The Niri session currently expects these additional Arch packages:

```sh
sudo pacman -S niri quickshell swaybg xwayland-satellite
```

Add `xdg-desktop-portal-gnome` when Niri screencasting is needed; the existing
GTK portal continues to cover the basic fallback portal features.

After stowing `config` and `local`, install the tracked greetd configuration
and systemd units with the existing root-targeted `etc` stow workflow. Reload
systemd and enable the secondary greetd instance without starting it in the
current graphical login:

```sh
stow --target "$HOME/.config" config
stow --target "$HOME/.local" local
systemctl --user disable hyprpaper.service hyprpolkitagent.service
sudo stow --target /etc etc
sudo systemctl daemon-reload
sudo systemctl enable greetd-niri.service
```

Reboot to start both sessions. `greetd-niri.service` waits briefly for the
VT2 registration before the primary greetd instance starts on VT1, so Hyprland
is the desktop left on screen.

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
