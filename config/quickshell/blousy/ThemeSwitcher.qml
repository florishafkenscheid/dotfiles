import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    required property var theme

    property bool opened: false
    property bool applying: false
    property string errorMessage: ""
    readonly property var targetScreen: Quickshell.screens.find(
        screen => screen.name === "DP-2"
    ) || Quickshell.screens[0]

    function open(): void {
        if (theme.themes.length === 0)
            return;

        errorMessage = "";
        carousel.currentIndex = theme.indexOf(theme.currentId);
        theme.preview(theme.currentId);
        opened = true;
        focusTimer.restart();
    }

    function close(): void {
        if (applying)
            return;

        opened = false;
        theme.cancelPreview();
    }

    function toggle(): void {
        if (opened)
            close();
        else
            open();
    }

    function move(delta): void {
        const next = Math.max(
            0,
            Math.min(theme.themes.length - 1, carousel.currentIndex + delta)
        );
        carousel.currentIndex = next;
    }

    function apply(id): void {
        if (applying || !theme.themes.some(candidate => candidate.id === id))
            return;

        applying = true;
        errorMessage = "";
        applyProcess.pendingId = id;
        applyProcess.exec([
            "/home/blousy/.config/desktop/theme",
            "apply",
            id
        ]);
    }

    IpcHandler {
        target: "theme"

        function toggle(): void {
            root.toggle();
        }

        function apply(id: string): void {
            root.apply(id);
        }

        function current(): string {
            return root.theme.currentId;
        }

        function list(): string {
            return root.theme.themes
                .map(candidate => candidate.id)
                .join("\n");
        }
    }

    Process {
        id: applyProcess

        property string pendingId: ""

        stderr: StdioCollector {
            id: applyError
            waitForEnd: true
        }

        onExited: exitCode => {
            root.applying = false;
            if (exitCode === 0) {
                root.theme.accept(pendingId);
                root.opened = false;
            } else {
                root.errorMessage = applyError.text.trim()
                    || "Could not apply this theme";
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 1
        onTriggered: keySurface.forceActiveFocus()
    }

    PanelWindow {
        id: overlay

        screen: root.targetScreen
        visible: root.opened
        color: "transparent"
        focusable: true
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "blousy-theme-switcher"

        Rectangle {
            anchors.fill: parent
            color: "#24000000"

            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        FocusScope {
            id: keySurface

            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left
                        || event.key === Qt.Key_H) {
                    root.move(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right
                        || event.key === Qt.Key_L) {
                    root.move(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return
                        || event.key === Qt.Key_Enter
                        || event.key === Qt.Key_Space) {
                    const selected = root.theme.themes[carousel.currentIndex];
                    if (selected)
                        root.apply(selected.id);
                    event.accepted = true;
                }
            }

            MouseArea {
                anchors.fill: carousel
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    root.move(wheel.angleDelta.y > 0 ? -1 : 1);
                    wheel.accepted = true;
                }
            }

            Rectangle {
                id: palettePill

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.max(132, parent.height * 0.14)
                width: paletteRow.implicitWidth + 44
                height: 62
                radius: 31
                color: "#e6110e0b"
                border.width: 1
                border.color: root.theme.accentMuted

                Row {
                    id: paletteRow

                    anchors.centerIn: parent
                    spacing: 13

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰏘"
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: 25
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "THEME"
                        color: root.theme.foregroundMuted
                        font.family: root.theme.monoFontFamily
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 26
                        color: root.theme.divider
                    }

                    Repeater {
                        model: root.theme.paletteChips

                        Rectangle {
                            required property var modelData

                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            radius: 9
                            color: modelData
                            border.width: 1
                            border.color: "#66ffffff"

                            Behavior on color {
                                ColorAnimation { duration: 220 }
                            }
                        }
                    }
                }
            }

            ListView {
                id: carousel

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 740
                orientation: ListView.Horizontal
                spacing: -150
                clip: false
                interactive: !root.applying
                boundsBehavior: Flickable.StopAtBounds
                maximumFlickVelocity: 2600
                flickDeceleration: 3500
                snapMode: ListView.SnapOneItem
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: width / 2 - 250
                preferredHighlightEnd: width / 2 - 250
                highlightMoveDuration: 360
                model: root.theme.themes

                header: Item {
                    width: Math.max(
                        0,
                        (carousel.width - 500) / 2 - carousel.spacing
                    )
                    height: 1
                }

                footer: Item {
                    width: Math.max(
                        0,
                        (carousel.width - 500) / 2 - carousel.spacing
                    )
                    height: 1
                }

                onCurrentIndexChanged: {
                    const selected = root.theme.themes[currentIndex];
                    if (root.opened && selected)
                        root.theme.preview(selected.id);
                }

                delegate: Item {
                    id: cardSlot

                    required property var modelData
                    required property int index
                    readonly property int distance: index - carousel.currentIndex
                    readonly property bool selected: distance === 0

                    width: 500
                    height: carousel.height
                    z: 100 - Math.abs(distance)
                    scale: selected ? 1 : 0.82
                    opacity: Math.abs(distance) > 2 ? 0 : selected ? 1 : 0.82

                    Behavior on scale {
                        NumberAnimation {
                            duration: 360
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 240 }
                    }

                    Shape {
                        id: card

                        property real slant: 84
                        readonly property real outline: cardSlot.selected ? 4 : 2

                        anchors.centerIn: parent
                        width: 460
                        height: 600
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeWidth: card.outline
                            strokeColor: cardSlot.selected
                                ? root.theme.accent : "#66ffffff"
                            joinStyle: ShapePath.RoundJoin
                            fillItem: Image {
                                width: card.width
                                height: card.height
                                source: root.theme.resolveAsset(
                                    cardSlot.modelData.previewWallpaper
                                        || cardSlot.modelData.wallpaper
                                )
                                sourceSize.width: card.width
                                sourceSize.height: card.height
                                asynchronous: true
                                cache: true
                                fillMode: Image.PreserveAspectCrop
                            }

                            startX: card.slant + card.outline / 2
                            startY: card.outline / 2
                            PathLine {
                                x: card.width - card.outline / 2
                                y: card.outline / 2
                            }
                            PathLine {
                                x: card.width - card.slant - card.outline / 2
                                y: card.height - card.outline / 2
                            }
                            PathLine {
                                x: card.outline / 2
                                y: card.height - card.outline / 2
                            }
                            PathLine {
                                x: card.slant + card.outline / 2
                                y: card.outline / 2
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 26
                            anchors.right: parent.right
                            anchors.rightMargin: card.slant + 26
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 22
                            spacing: 3

                            Text {
                                width: parent.width
                                text: cardSlot.modelData.name
                                color: "#ffffffff"
                                font.family: root.theme.fontFamily
                                font.pixelSize: 29
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: cardSlot.modelData.subtitle
                                color: "#b8ffffff"
                                font.family: root.theme.fontFamily
                                font.pixelSize: 18
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 18
                            width: 38
                            height: 38
                            radius: 19
                            visible: cardSlot.modelData.id === root.theme.currentId
                            color: root.theme.accent

                            Text {
                                anchors.centerIn: parent
                                text: "󰄬"
                                color: root.theme.backgroundRaised
                                font.family: root.theme.fontFamily
                                font.pixelSize: 22
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.applying
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (cardSlot.selected)
                                    root.apply(cardSlot.modelData.id);
                                else
                                    carousel.currentIndex = cardSlot.index;
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.max(118, parent.height * 0.12)
                width: hintRow.implicitWidth + 34
                height: 46
                radius: 23
                color: "#c9110e0b"
                border.width: 1
                border.color: root.errorMessage ? "#99ff6b5f"
                    : root.theme.accentSoft

                Row {
                    id: hintRow

                    anchors.centerIn: parent
                    spacing: 11

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.applying ? "APPLYING"
                            : root.errorMessage ? root.errorMessage
                            : "←  →  BROWSE    ENTER  APPLY    ESC  CLOSE"
                        color: root.errorMessage ? "#ffffa49c"
                            : root.theme.foregroundMuted
                        font.family: root.theme.monoFontFamily
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }
}
