# Theme extension point

Dune remains the only implemented theme. A future theme switcher can add one
directory per theme here without requiring a single generated source of truth:

```text
themes/<name>/
├── hyprland.conf
├── eww.scss
├── rofi.rasi
├── niri.kdl
└── quickshell/Theme.qml
```

The switcher should install or link each native fragment, validate both
compositor configs, reload the active shell, and persist the selected name.
Niri's `do-screen-transition` action can hide the staggered redraw while a Niri
session is active.

For now, the existing Dune values intentionally remain in their current native
files. `~/.config/quickshell/blousy/Theme.qml` is Quickshell's matching palette
boundary.
