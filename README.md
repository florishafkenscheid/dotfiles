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
- [x] tuigreet - `/etc/greetd/config.toml`
- [ ] fastfetch - `~/.config/fastfetch/config.jsonc`
- [ ] rofi - `~/.config/rofi/config.rasi`
- [ ] mako - `~/.config/mako/config`
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

## Future
For when I eventually get sick of this, or I simply want to try out different DE's, WM's, widget systems etc, I am compiling a list of interesting, yet not necessarily related projects to use.

### [Caelestia](https://github.com/caelestia-dots)
- [Quickshell](https://quickshell.outfoxxed.me/)
- [Foot](https://codeberg.org/dnkl/foot)
