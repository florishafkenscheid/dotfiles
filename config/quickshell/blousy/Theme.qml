import QtQuick

// Dune is the only palette today. Keeping the shell palette behind this object
// leaves a small, native Quickshell seam for the future cross-session theme
// switcher without forcing the Hyprland/Eww files into the same format.
QtObject {
    readonly property color background: "#f2080604"
    readonly property color backgroundRaised: "#f20c0804"
    readonly property color accent: "#d77f00"
    readonly property color accentBright: "#ff8c28"
    readonly property color accentMuted: "#66d77f00"
    readonly property color accentSoft: "#2ed77f00"
    readonly property color divider: "#66d77f00"
    readonly property color surfaceHover: "#26d77f00"
    readonly property color foreground: "#f2ffffff"
    readonly property color foregroundMuted: "#99ffffff"
    readonly property string fontFamily: "MesloLGM Nerd Font Propo"
    readonly property string monoFontFamily: "MesloLGM Nerd Font Mono"
}
