import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    required property var theme

    function showSource(window, source): void {
        window.requestedSource = String(source);
        if (!source || window.requestedSource === window.displayedSource)
            return;

        const incoming = window.frontVisible ? window.back : window.front;
        incoming.pending = true;
        incoming.source = source;
        reveal(
            window,
            incoming,
            window.frontVisible ? window.front : window.back,
            !window.frontVisible
        );
    }

    function reveal(window, incoming, outgoing, front): void {
        if (!incoming.pending || incoming.status !== Image.Ready)
            return;
        if (String(incoming.source) !== window.requestedSource) {
            incoming.pending = false;
            return;
        }

        incoming.pending = false;
        incoming.z = 2;
        outgoing.z = 1;
        incoming.opacity = 1;
        outgoing.opacity = 0;
        window.frontVisible = front;
        window.displayedSource = String(incoming.source);
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: wallpaperWindow

            required property var modelData
            property alias front: frontImage
            property alias back: backImage
            property bool frontVisible: true
            property string displayedSource: ""
            property string requestedSource: ""
            readonly property bool themedOutput: modelData.name === "DP-2"

            screen: modelData
            color: themedOutput ? root.theme.backgroundRaised : "#000000"
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: false

            anchors {
                top: true
                right: true
                bottom: true
                left: true
            }

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "blousy-wallpaper"

            Component.onCompleted: {
                if (themedOutput) {
                    frontImage.source = root.theme.wallpaper;
                    displayedSource = String(root.theme.wallpaper);
                    requestedSource = displayedSource;
                }
            }

            Connections {
                target: root.theme

                function onWallpaperChanged(): void {
                    if (wallpaperWindow.themedOutput)
                        root.showSource(wallpaperWindow, root.theme.wallpaper);
                }
            }

            Image {
                id: frontImage

                property bool pending: false

                anchors.fill: parent
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                opacity: 1

                onStatusChanged: root.reveal(
                    wallpaperWindow,
                    frontImage,
                    backImage,
                    true
                )

                Behavior on opacity {
                    NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                }
            }

            Image {
                id: backImage

                property bool pending: false

                anchors.fill: parent
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                opacity: 0

                onStatusChanged: root.reveal(
                    wallpaperWindow,
                    backImage,
                    frontImage,
                    false
                )

                Behavior on opacity {
                    NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
