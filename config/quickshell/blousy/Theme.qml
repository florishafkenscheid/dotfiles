import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var themes: []
    property string defaultId: "arrakis"
    property string currentId: defaultId
    property string previewId: ""

    readonly property string desktopStatePath:
        (Quickshell.env("XDG_STATE_HOME")
            || Quickshell.env("HOME") + "/.local/state")
        + "/blousy"
    readonly property var currentTheme: themeById(currentId)
    readonly property var effectiveTheme: themeById(previewId || currentId)
    readonly property var palette: effectiveTheme.palette || ({})
    readonly property url wallpaper: resolveAsset(effectiveTheme.wallpaper || "")
    readonly property var paletteChips: [
        palette.accent || "#d77f00",
        palette.accentBright || "#ff8c28",
        palette.foreground || "#ffffff",
        palette.foregroundMuted || "#99ffffff",
        palette.backgroundRaised || "#0c0804"
    ]

    property color background: palette.background || "#f2080604"
    property color backgroundRaised: palette.backgroundRaised || "#f20c0804"
    property color accent: palette.accent || "#d77f00"
    property color accentBright: palette.accentBright || "#ff8c28"
    property color accentMuted: palette.accentMuted || "#66d77f00"
    property color accentSoft: palette.accentSoft || "#2ed77f00"
    property color divider: palette.divider || "#66d77f00"
    property color surfaceHover: palette.surfaceHover || "#26d77f00"
    property color foreground: palette.foreground || "#f2ffffff"
    property color foregroundMuted: palette.foregroundMuted || "#99ffffff"

    readonly property string fontFamily: "MesloLGM Nerd Font Propo"
    readonly property string monoFontFamily: "MesloLGM Nerd Font Mono"

    function parseJson(text, fallback) {
        try {
            return JSON.parse(text);
        } catch (error) {
            return fallback;
        }
    }

    function themeById(id) {
        const match = themes.find(theme => theme.id === id);
        if (match)
            return match;

        const fallback = themes.find(theme => theme.id === defaultId);
        return fallback || {
            "id": "arrakis",
            "name": "Arrakis",
            "subtitle": "Deep desert",
            "wallpaper": "$HOME/dotfiles/images/dune.png",
            "palette": {}
        };
    }

    function indexOf(id) {
        const index = themes.findIndex(theme => theme.id === id);
        return index < 0 ? 0 : index;
    }

    function resolveAsset(path) {
        if (!path)
            return "";
        if (path.startsWith("$HOME/"))
            return Quickshell.env("HOME") + path.slice(5);
        if (path.startsWith("~/"))
            return Quickshell.env("HOME") + path.slice(1);
        if (path.startsWith("/") || path.startsWith("file:"))
            return path;
        return Quickshell.shellPath("../../desktop/themes/" + path);
    }

    function preview(id): void {
        if (themes.some(theme => theme.id === id))
            previewId = id;
    }

    function cancelPreview(): void {
        previewId = "";
    }

    function accept(id): void {
        if (themes.some(theme => theme.id === id))
            currentId = id;
        previewId = "";
    }

    function loadCatalog(): void {
        const value = parseJson(catalogFile.text(), null);
        if (!value || !Array.isArray(value.themes) || value.themes.length === 0)
            return;

        themes = value.themes;
        defaultId = value.default || value.themes[0].id;
        if (!themes.some(theme => theme.id === currentId))
            currentId = defaultId;
    }

    function loadState(): void {
        const value = stateFile.text().trim();
        if (themes.some(theme => theme.id === value))
            currentId = value;
    }

    Component.onCompleted: {
        loadCatalog();
        loadState();
    }

    FileView {
        id: catalogFile

        path: Quickshell.shellPath("../../desktop/themes/catalog.json")
        blockLoading: true
        watchChanges: true

        onFileChanged: reload()
        onLoaded: root.loadCatalog()
    }

    FileView {
        id: stateFile

        path: root.desktopStatePath + "/theme"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.loadState()
    }

    Behavior on background {
        ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    Behavior on backgroundRaised {
        ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    Behavior on accent {
        ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    Behavior on accentBright {
        ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    Behavior on foreground {
        ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    Behavior on foregroundMuted {
        ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
    }
}
