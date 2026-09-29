//@ pragma StateDir $BASE/blousy

import Quickshell

ShellRoot {
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
