//@ pragma StateDir $BASE/blousy

import Quickshell

ShellRoot {
    // Shared by Niri and Hyprland; compositor-specific behavior lives in Bar.
    Theme {
        id: theme
    }

    Wallpaper {
        theme: theme
    }

    ThemeSwitcher {
        id: themeSwitcher
        theme: theme
    }

    IdleOverlay {
        theme: theme
    }

    Bar {
        theme: theme
    }
}
