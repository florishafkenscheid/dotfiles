import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    required property var theme

    readonly property string helperDir:
        Quickshell.env("HOME") + "/.config/quickshell/blousy/scripts"
    property int cpuPercent: 0
    property int gpuPercent: 0
    property int memoryPercent: 0
    property double previousCpuTotal: 0
    property double previousCpuIdle: 0
    property var hyprClients: []
    property bool hyprClientsReady: false
    property int hyprEmptyClientPolls: 0
    property var prismIconData: ({
        "processes": {},
        "versions": {}
    })
    property var steamIconData: ({})
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

    function focusHyprWorkspace(id): void {
        if (!hyprAction.running) {
            hyprAction.exec([
                "hyprctl",
                "dispatch",
                "hl.dsp.focus({ workspace = " + String(id) + " })"
            ]);
        }
    }

    function hyprAppId(toplevel) {
        if (!toplevel)
            return "";

        if (toplevel.initialClass || toplevel.class)
            return toplevel.initialClass || toplevel.class;

        const details = toplevel.lastIpcObject || {};
        if (details.initialClass || details.class)
            return details.initialClass || details.class;
        return toplevel.wayland ? toplevel.wayland.appId : "";
    }

    function hyprWorkspaceApps(workspace) {
        if (!workspace || !workspace.toplevels)
            return [];

        const apps = [];
        const seen = {};
        const workspaceClients = root.hyprClients.filter(client =>
            client.workspace
            && client.workspace.id === workspace.id
            && client.mapped !== false
        );
        const toplevels = root.hyprClientsReady
            ? workspaceClients : workspace.toplevels.values;

        for (let i = 0; i < toplevels.length && apps.length < 3; ++i) {
            const toplevel = toplevels[i];
            const appId = root.hyprAppId(toplevel);
            const key = (appId || toplevel.address || String(i)).toLowerCase();

            if (seen[key])
                continue;

            seen[key] = true;
            apps.push(toplevel);
        }

        return apps;
    }

    function windowIcon(appId, pid) {
        const minecraftMatch = String(appId || "").match(
            /^minecraft\*?\s*(.*)$/i
        );
        if (minecraftMatch) {
            const processes = root.prismIconData.processes || {};
            const versions = root.prismIconData.versions || {};
            const processIcon = processes[String(pid || "")];
            if (processIcon)
                return processIcon;

            const version = minecraftMatch[1].trim().toLowerCase();
            if (version && versions[version])
                return versions[version];

            return Quickshell.iconPath("org.prismlauncher.PrismLauncher", true);
        }

        const entry = DesktopEntries.heuristicLookup(appId || "");
        if (entry && entry.icon)
            return Quickshell.iconPath(entry.icon, true);

        const steamIcon = root.steamIconData[String(pid || "")];
        if (steamIcon)
            return Quickshell.iconPath(steamIcon, true);

        return appId ? Quickshell.iconPath(appId, true) : "";
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
        id: hyprAction
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
        interval: 1500
        command: ["hyprctl", "-j", "clients"]

        onUpdated: text => {
            const value = root.parseJson(text, null);
            if (!Array.isArray(value))
                return;

            if (value.length === 0) {
                root.hyprEmptyClientPolls++;
                if (root.hyprEmptyClientPolls >= 2) {
                    root.hyprClients = [];
                    root.hyprClientsReady = true;
                }
            } else {
                root.hyprEmptyClientPolls = 0;
                root.hyprClients = value;
                root.hyprClientsReady = true;
            }
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
        interval: 5000
        command: [root.helperDir + "/get-lamzu-battery.py"]

        onUpdated: text => {
            root.mouseBattery = root.parseJson(text, root.mouseBattery);
        }
    }

    CommandPoll {
        interval: 5000
        command: [root.helperDir + "/get-prism-instance-icons.py"]

        onUpdated: text => {
            const value = root.parseJson(text, null);
            if (value && typeof value === "object")
                root.prismIconData = value;
        }
    }

    CommandPoll {
        interval: 2000
        // Steam exports the authoritative app ID into each game process.
        command: [root.helperDir + "/get-steam-app-icons.py"]

        onUpdated: text => {
            const value = root.parseJson(text, null);
            if (value && typeof value === "object")
                root.steamIconData = value;
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
            readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
            readonly property var hyprWorkspaces:
                hyprMonitor
                    ? Hyprland.workspaces.values
                        .filter(workspace =>
                            workspace.id > 0
                            && workspace.monitor
                            && workspace.monitor.name === hyprMonitor.name
                        )
                        .sort((left, right) => left.id - right.id)
                    : []

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

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        color: root.theme.accent
                        font.family: root.theme.fontFamily
                        font.pixelSize: 38
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
                        model: panel.hyprWorkspaces

                        delegate: Item {
                            id: hyprWorkspaceItem

                            required property var modelData

                            width: hyprWorkspaceContent.implicitWidth + 24
                            height: 58

                            Rectangle {
                                anchors.fill: parent
                                anchors.topMargin: 3
                                anchors.bottomMargin: 9
                                radius: 9
                                color: modelData.active
                                    ? root.theme.accentSoft
                                    : hyprWorkspaceMouse.containsMouse
                                        ? root.theme.surfaceHover : "transparent"

                                Behavior on color {
                                    ColorAnimation { duration: 160 }
                                }
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                width: parent.width - 12
                                height: 2
                                color: modelData.active
                                    ? root.theme.accent : "transparent"
                            }

                            Row {
                                id: hyprWorkspaceContent

                                anchors.centerIn: parent
                                spacing: 7

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.name
                                    color: modelData.active
                                        ? root.theme.accent
                                        : root.theme.foregroundMuted
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: 22
                                }

                                Repeater {
                                    model: root.hyprWorkspaceApps(modelData)

                                    delegate: Item {
                                        required property var modelData

                                        width: 28
                                        height: 32

                                        Image {
                                            id: hyprWorkspaceAppIcon

                                            anchors.centerIn: parent
                                            width: 26
                                            height: 26
                                            source: root.windowIcon(
                                                root.hyprAppId(modelData),
                                                modelData.pid
                                            )
                                            sourceSize.width: 26
                                            sourceSize.height: 26
                                            fillMode: Image.PreserveAspectFit
                                            opacity: modelData.activated ? 1 : 0.72
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰣆"
                                            color: modelData.activated
                                                ? root.theme.accent
                                                : root.theme.foregroundMuted
                                            visible:
                                                hyprWorkspaceAppIcon.status
                                                    === Image.Error
                                                || hyprWorkspaceAppIcon.status
                                                    === Image.Null
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: 22
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: hyprWorkspaceMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.focusHyprWorkspace(modelData.id)
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
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideLeft
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
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideLeft
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
                        width: 126
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
