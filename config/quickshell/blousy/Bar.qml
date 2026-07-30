import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    required property var theme

    readonly property bool isHyprland:
        Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== ""
    readonly property bool isNiri: Quickshell.env("NIRI_SOCKET") !== ""
    readonly property string helperDir:
        Quickshell.env("HOME") + "/.config/quickshell/blousy/scripts"
    property int cpuPercent: 0
    property int gpuPercent: 0
    property int memoryPercent: 0
    property double previousCpuTotal: 0
    property double previousCpuIdle: 0
    property var outputs: ({})
    property var workspaces: []
    property var windows: []
    property var mediaData: ({
        "title": "Nothing Playing",
        "artist": ""
    })
    property var volumeData: ({
        "target": "system",
        "percent": 0,
        "muted": false,
        "icon": "󰖀"
    })
    property var mouseBattery: ({
        "available": false,
        "percent": 0,
        "icon": "󰂑",
        "class": "unavailable"
    })
    property string vpnState: "disconnected"

    function parseJson(text, fallback) {
        try {
            return JSON.parse(text);
        } catch (error) {
            return fallback;
        }
    }

    function switchDesktop(): void {
        if (!switchProcess.running)
            switchProcess.running = true;
    }

    function focusNiriWindow(id): void {
        if (!niriAction.running)
            niriAction.exec(["niri", "msg", "action", "focus-window", "--id", String(id)]);
    }

    function focusHyprWindow(toplevel): void {
        if (!toplevel)
            return;

        if (toplevel.wayland) {
            toplevel.wayland.activate();
        } else if (toplevel.address) {
            Hyprland.dispatch("focuswindow address:" + toplevel.address);
        }
    }

    function hyprAppId(toplevel) {
        if (!toplevel)
            return "";

        const details = toplevel.lastIpcObject || {};
        if (details.initialClass || details.class)
            return details.initialClass || details.class;
        return toplevel.wayland ? toplevel.wayland.appId : "";
    }

    function windowIcon(appId) {
        const entry = DesktopEntries.heuristicLookup(appId || "");
        return entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : "";
    }

    function windowsForOutput(outputName) {
        const workspace = root.workspaces.find(candidate =>
            candidate.output === outputName && candidate.is_active
        );
        if (!workspace)
            return [];

        const ordered = root.windows
            .filter(window => window.workspace_id === workspace.id)
            .sort((left, right) => {
                const leftPosition = left.layout && left.layout.pos_in_scrolling_layout
                    ? left.layout.pos_in_scrolling_layout : [9999, left.id];
                const rightPosition = right.layout && right.layout.pos_in_scrolling_layout
                    ? right.layout.pos_in_scrolling_layout : [9999, right.id];
                return leftPosition[0] - rightPosition[0]
                    || leftPosition[1] - rightPosition[1]
                    || left.id - right.id;
            });

        const activeWindow = ordered.find(window => window.id === workspace.active_window_id);
        const activePosition = activeWindow && activeWindow.layout
            ? activeWindow.layout.pos_in_scrolling_layout : null;
        const activeColumn = activePosition ? activePosition[0] : -1;

        return ordered.map((window, index) => {
            const position = window.layout && window.layout.pos_in_scrolling_layout
                ? window.layout.pos_in_scrolling_layout : null;
            const previous = index > 0 ? ordered[index - 1] : null;
            const previousPosition = previous && previous.layout
                ? previous.layout.pos_in_scrolling_layout : null;

            return {
                "window": window,
                "output": outputName,
                "columnStart": index > 0 && (
                    !position || !previousPosition || position[0] !== previousPosition[0]
                ),
                "activeWindow": window.id === workspace.active_window_id,
                "activeColumn": position && position[0] === activeColumn
            };
        });
    }

    function combinedWindows() {
        const outputNames = Object.keys(root.outputs).sort((left, right) => {
            const leftLogical = root.outputs[left].logical || {};
            const rightLogical = root.outputs[right].logical || {};
            return (leftLogical.x || 0) - (rightLogical.x || 0)
                || (leftLogical.y || 0) - (rightLogical.y || 0)
                || left.localeCompare(right);
        });

        let combined = [];
        outputNames.forEach(outputName => {
            const outputWindows = root.windowsForOutput(outputName);
            outputWindows.forEach((entry, index) => {
                entry.outputStart = combined.length > 0 && index === 0;
                combined.push(entry);
            });
        });
        return combined;
    }

    function changeVolume(action, value): void {
        if (!volumeAction.running) {
            const command = [root.helperDir + "/set-volume.sh", action];
            if (value !== undefined)
                command.push(String(value));
            volumeAction.exec(command);
        }
    }

    function toggleVpn(): void {
        if (!vpnAction.running) {
            const action = root.vpnState === "connected" ? "disconnect" : "connect";
            vpnAction.exec(["mullvad", action]);
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Process {
        id: switchProcess
        command: ["/home/blousy/.config/desktop/switch"]
    }

    Process {
        id: niriAction
    }

    Process {
        id: volumeAction

        stdout: StdioCollector {
            id: volumeActionOutput
            waitForEnd: true

            onStreamFinished: {
                root.volumeData = root.parseJson(volumeActionOutput.text, root.volumeData);
            }
        }
    }

    Process {
        id: vpnAction
        onExited: vpnPoll.refresh()
    }

    CommandPoll {
        command: ["sh", "-c", "awk '/^cpu / { total=0; for (i=2; i<=NF; i++) total+=$i; print total, $5+$6 }' /proc/stat"]

        onUpdated: text => {
            const values = text.split(/\s+/).map(Number);
            if (values.length < 2 || values.some(value => !Number.isFinite(value)))
                return;

            const total = values[0];
            const idle = values[1];
            if (root.previousCpuTotal > 0) {
                const totalDelta = total - root.previousCpuTotal;
                const idleDelta = idle - root.previousCpuIdle;
                if (totalDelta > 0)
                    root.cpuPercent = Math.round(100 * (totalDelta - idleDelta) / totalDelta);
            }
            root.previousCpuTotal = total;
            root.previousCpuIdle = idle;
        }
    }

    CommandPoll {
        command: ["cat", "/sys/bus/pci/devices/0000:03:00.0/gpu_busy_percent"]

        onUpdated: text => {
            const value = Number(text);
            if (Number.isFinite(value))
                root.gpuPercent = Math.round(value);
        }
    }

    CommandPoll {
        command: ["sh", "-c", "awk '/MemTotal/{total=$2} /MemAvailable/{available=$2} END { printf \"%.0f\", 100*(total-available)/total }' /proc/meminfo"]

        onUpdated: text => {
            const value = Number(text);
            if (Number.isFinite(value))
                root.memoryPercent = Math.round(value);
        }
    }

    CommandPoll {
        interval: 2000
        enabled: root.isNiri
        command: ["niri", "msg", "-j", "outputs"]

        onUpdated: text => {
            const value = root.parseJson(text, null);
            if (value && typeof value === "object")
                root.outputs = value;
        }
    }

    CommandPoll {
        interval: 750
        enabled: root.isNiri
        command: ["niri", "msg", "-j", "workspaces"]

        onUpdated: text => {
            const value = root.parseJson(text, null);
            if (Array.isArray(value))
                root.workspaces = value;
        }
    }

    CommandPoll {
        interval: 500
        enabled: root.isNiri
        command: ["niri", "msg", "-j", "windows"]

        onUpdated: text => {
            const value = root.parseJson(text, null);
            if (Array.isArray(value))
                root.windows = value;
        }
    }

    CommandPoll {
        command: [root.helperDir + "/get-now-playing.sh"]

        onUpdated: text => {
            root.mediaData = root.parseJson(text, root.mediaData);
        }
    }

    CommandPoll {
        id: volumePoll
        interval: 1000
        command: [root.helperDir + "/get-volume.sh"]

        onUpdated: text => {
            root.volumeData = root.parseJson(text, root.volumeData);
        }
    }

    CommandPoll {
        interval: 120000
        command: [root.helperDir + "/get-lamzu-battery.py"]

        onUpdated: text => {
            root.mouseBattery = root.parseJson(text, root.mouseBattery);
        }
    }

    CommandPoll {
        id: vpnPoll
        interval: 5000
        command: ["sh", "-c", "mullvad status -j 2>/dev/null | jq -r '.state // \"disconnected\"'"]

        onUpdated: text => {
            root.vpnState = text || "disconnected";
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property var modelData
            readonly property var outputWindows:
                root.isNiri ? root.combinedWindows() : []
            readonly property var hyprMonitor:
                root.isHyprland ? Hyprland.monitorFor(modelData) : null
            readonly property var hyprWorkspace:
                hyprMonitor ? hyprMonitor.activeWorkspace : null

            screen: modelData
            color: "transparent"
            implicitHeight: 96

            anchors {
                top: true
                left: true
                right: true
            }

            Rectangle {
                anchors.fill: parent

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: root.theme.background
                    }
                    GradientStop {
                        position: 1
                        color: root.theme.backgroundRaised
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 2
                    color: root.theme.accent
                }

                Row {
                    id: leftSection

                    anchors.left: parent.left
                    anchors.leftMargin: 36
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 20

                    Item {
                        width: 54
                        height: 56

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: logoMouse.containsMouse
                                ? root.theme.surfaceHover : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }
                        }

                        Text {
                            id: logo

                            anchors.centerIn: parent
                            text: ""
                            color: logoMouse.containsMouse ? root.theme.foreground : root.theme.accent
                            font.family: root.theme.fontFamily
                            font.pixelSize: 38

                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }
                        }

                        MouseArea {
                            id: logoMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchDesktop()
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍛 " + root.cpuPercent + "%"
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: 28
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.gpuPercent + "% 󰾲"
                        color: root.theme.accentBright
                        font.family: root.theme.fontFamily
                        font.pixelSize: 28
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 34
                        color: root.theme.divider
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: " " + root.memoryPercent + "%"
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: 28
                    }
                }

                Row {
                    id: windowStrip

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: root.isNiri ? panel.outputWindows : []

                        delegate: Item {
                            id: windowItem

                            required property var modelData

                            width: 52
                                + (modelData.columnStart ? 12 : 0)
                                + (modelData.outputStart ? 20 : 0)
                            height: 58

                            Behavior on x {
                                NumberAnimation {
                                    duration: 190
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: 34
                                visible: modelData.outputStart
                                color: root.theme.divider
                            }

                            Rectangle {
                                id: windowSurface

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 52
                                height: 52
                                radius: 10
                                color: modelData.window.is_focused
                                    ? root.theme.accentMuted
                                    : modelData.activeWindow
                                        ? root.theme.surfaceHover
                                        : windowMouse.containsMouse
                                            ? root.theme.surfaceHover : "transparent"
                                border.width: modelData.activeColumn ? 2 : 0
                                border.color: modelData.activeColumn
                                    ? root.theme.accent : "transparent"

                                Behavior on color {
                                    ColorAnimation { duration: 160 }
                                }

                                Behavior on border.width {
                                    NumberAnimation {
                                        duration: 160
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Image {
                                    id: appIcon

                                    anchors.centerIn: parent
                                    width: 30
                                    height: 30
                                    source: root.windowIcon(modelData.window.app_id)
                                    sourceSize.width: 30
                                    sourceSize.height: 30
                                    fillMode: Image.PreserveAspectFit
                                    opacity: modelData.activeColumn ? 1 : 0.72
                                    scale: modelData.window.is_focused ? 1.08 : 1

                                    Behavior on opacity {
                                        NumberAnimation { duration: 150 }
                                    }

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 180
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰣆"
                                    color: modelData.activeColumn
                                        ? root.theme.accent : root.theme.foregroundMuted
                                    visible: appIcon.status === Image.Error
                                        || appIcon.status === Image.Null
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: 28
                                }
                            }

                            MouseArea {
                                id: windowMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.focusNiriWindow(modelData.window.id)
                            }
                        }
                    }

                    Repeater {
                        model: root.isHyprland && panel.hyprWorkspace
                            ? panel.hyprWorkspace.toplevels : 0

                        delegate: Item {
                            required property var modelData

                            width: 52
                            height: 58

                            Rectangle {
                                anchors.centerIn: parent
                                width: 52
                                height: 52
                                radius: 10
                                color: modelData.activated
                                    ? root.theme.accentMuted
                                    : hyprWindowMouse.containsMouse
                                        ? root.theme.surfaceHover : "transparent"
                                border.width: modelData.activated ? 2 : 0
                                border.color: modelData.activated
                                    ? root.theme.accent : "transparent"

                                Behavior on color {
                                    ColorAnimation { duration: 160 }
                                }

                                Image {
                                    id: hyprAppIcon

                                    anchors.centerIn: parent
                                    width: 30
                                    height: 30
                                    source: root.windowIcon(root.hyprAppId(modelData))
                                    sourceSize.width: 30
                                    sourceSize.height: 30
                                    fillMode: Image.PreserveAspectFit
                                    opacity: modelData.activated ? 1 : 0.72
                                    scale: modelData.activated ? 1.08 : 1

                                    Behavior on opacity {
                                        NumberAnimation { duration: 150 }
                                    }

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 180
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰣆"
                                    color: modelData.activated
                                        ? root.theme.accent : root.theme.foregroundMuted
                                    visible: hyprAppIcon.status === Image.Error
                                        || hyprAppIcon.status === Image.Null
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: 28
                                }
                            }

                            MouseArea {
                                id: hyprWindowMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.focusHyprWindow(modelData)
                            }
                        }
                    }
                }

                Row {
                    id: rightSection

                    anchors.right: parent.right
                    anchors.rightMargin: 36
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 20

                    Item {
                        id: mediaContainer

                        property bool hasMedia: root.mediaData.title !== "Nothing Playing"

                        width: 360
                        height: 58
                        opacity: 1
                        clip: true

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            spacing: 2

                            Text {
                                width: parent.width
                                text: root.mediaData.title
                                color: mediaContainer.hasMedia
                                    ? root.theme.foreground
                                    : root.theme.foregroundMuted
                                elide: Text.ElideRight
                                font.family: root.theme.fontFamily
                                font.pixelSize: 20

                                Behavior on color {
                                    ColorAnimation { duration: 180 }
                                }
                            }

                            Text {
                                width: parent.width
                                text: root.mediaData.artist
                                color: root.theme.foregroundMuted
                                elide: Text.ElideRight
                                visible: text.length > 0
                                font.family: root.theme.fontFamily
                                font.pixelSize: 16
                            }
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 34
                        color: root.theme.divider
                    }

                    Item {
                        width: root.mouseBattery.available
                            ? mouseBatteryRow.implicitWidth + 20 : 0
                        height: 54
                        visible: root.mouseBattery.available

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: mouseBatteryMouse.containsMouse
                                ? root.theme.surfaceHover : "transparent"
                        }

                        Row {
                            id: mouseBatteryRow

                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: root.mouseBattery.icon
                                color: root.mouseBattery.percent <= 20
                                    ? root.theme.accentBright
                                    : root.theme.foregroundMuted
                                font.family: root.theme.fontFamily
                                font.pixelSize: 28
                            }

                            Text {
                                text: root.mouseBattery.percent + "%"
                                visible: mouseBatteryMouse.containsMouse
                                    || root.mouseBattery.percent <= 20
                                color: root.theme.foregroundMuted
                                font.family: root.theme.monoFontFamily
                                font.pixelSize: 18
                            }
                        }

                        MouseArea {
                            id: mouseBatteryMouse

                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.mouseBattery.available ? 1 : 0
                        height: 34
                        visible: root.mouseBattery.available
                        color: root.theme.divider
                    }

                    Item {
                        width: 52
                        height: 54

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: vpnMouse.containsMouse
                                ? root.theme.surfaceHover : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.vpnState === "connected" ? "󰳌"
                                : root.vpnState === "connecting" ? "󰻍" : "󰦜"
                            color: root.vpnState === "connected"
                                ? root.theme.accent
                                : root.theme.foregroundMuted
                            font.family: root.theme.fontFamily
                            font.pixelSize: 30

                            Behavior on color {
                                ColorAnimation { duration: 160 }
                            }
                        }

                        MouseArea {
                            id: vpnMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleVpn()
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 34
                        color: root.theme.divider
                    }

                    Item {
                        width: volumeRow.implicitWidth + 20
                        height: 54

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: volumeMouse.containsMouse
                                ? root.theme.surfaceHover : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }
                        }

                        Row {
                            id: volumeRow

                            anchors.centerIn: parent
                            spacing: 9

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.volumeData.icon
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: 30
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.volumeData.percent + "%"
                                color: root.theme.foreground
                                font.family: root.theme.monoFontFamily
                                font.pixelSize: 22
                            }

                            Text {
                                width: volumeMouse.containsMouse ? implicitWidth : 0
                                opacity: volumeMouse.containsMouse ? 1 : 0
                                clip: true
                                text: root.volumeData.target === "player" ? "T" : "S"
                                color: root.theme.foregroundMuted
                                font.family: root.theme.monoFontFamily
                                font.pixelSize: 17

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 170
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation { duration: 140 }
                                }
                            }
                        }

                        MouseArea {
                            id: volumeMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton
                            onClicked: root.changeVolume("toggle-mute")
                            onWheel: wheel => root.changeVolume(
                                "scroll",
                                wheel.angleDelta.y > 0 ? "up" : "down"
                            )
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 34
                        color: root.theme.divider
                    }

                    Item {
                        width: clockBlock.implicitWidth + 20
                        height: 54

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: clockMouse.containsMouse
                                ? root.theme.surfaceHover : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }
                        }

                        Row {
                            id: clockBlock

                            anchors.centerIn: parent
                            spacing: 0

                            Text {
                                text: Qt.formatDateTime(clock.date, "HH:mm")
                                color: root.theme.foreground
                                font.family: root.theme.monoFontFamily
                                font.pixelSize: 29
                                font.weight: Font.Medium
                            }

                            Text {
                                text: Qt.formatDateTime(clock.date, ":ss")
                                color: root.theme.foregroundMuted
                                width: clockMouse.containsMouse ? implicitWidth : 0
                                opacity: clockMouse.containsMouse ? 1 : 0
                                clip: true
                                font.family: root.theme.monoFontFamily
                                font.pixelSize: 21

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 170
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation { duration: 140 }
                                }
                            }
                        }

                        MouseArea {
                            id: clockMouse

                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }
        }
    }
}
