{Insert fastfetch screenshot}
## What?
This repository contains the configuration files (dotfiles) for my minimalist, yet aesthetically pleasing, Arch Linux desktop environment.

My philosophy for Arch is a bare bones, yet aesthetically pleasing, environment; mainly used to develop software, or otherwise just entertainment.
With "bare bones", I mean a lean system focussing on functionality and minimal overhead. This includes choices like:
- **systemd-boot & efibootmgr** over GRUB: For simpler boot management.
- **systemd-{networkd,resolvd}** over NetworkManager: This PC will not connect to anything other than ethernet.
- **NeoVim** over VSCode: Prioritizing a customizable and keyboard-driven editor seems fitting for this setup.

The theme is based on the Dune movies, focussing on the vibrant oranges used in the cinematography.

## Progress
> [!NOTE]
> ↩️ means somehow linked to the next point, ⏳ means currently WIP.

- [x] Keybinds		        ~/.config/hypr/hyprland.conf
- [x] Zsh			        ~/.zshrc
- [x] Starship		        ~/.config/starship.toml
- [x] NeoVim		        ~/.config/nvim
	- [x] lazy
	- [x] lspconfig
	- [x] lualine
	- [x] lush
	- [x] mason
	- [x] mason-lspconfig
	- [x] nvim-tree
	- [x] telescope
	- [x] treesitter
	- [x] web-devicons
- [ ] Kitty settings	    ~/.config/kitty
- [ ] <s>! Waybar		    ~/.config/waybar</s> // Replaced by EWW ↩️ 
- [ ] EWW			        ~/.config/eww/* 
- [x] tuigreet		        /etc/greetd/config.toml
- [ ] fastfetch		        ~/.config/fastfetch/config.jsonc
- [ ] rofi			        ~/.config/rofi/config.rasi
- [ ] mako                  ~/.config/mako/config
- [ ] <s>mopidy ↩️</s> // Good luck if you want to use spotify
- [ ] <s>mpd ↩️</s>
- [ ] <s>rmpc </s>
