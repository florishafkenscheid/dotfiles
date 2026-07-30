import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    required property var theme

    property bool active: false
    readonly property var targetScreen: Quickshell.screens.find(
        screen => screen.name === "DP-2"
    ) || Quickshell.screens[0]

    IpcHandler {
        target: "idle"

        function start(): void {
            root.active = true;
        }

        function stop(): void {
            root.active = false;
        }
    }

    PanelWindow {
        screen: root.targetScreen
        visible: root.active
        color: root.theme.backgroundRaised
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "blousy-idle-overlay"

        Image {
            anchors.fill: parent
            source: root.theme.wallpaper
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
        }
    }
}
