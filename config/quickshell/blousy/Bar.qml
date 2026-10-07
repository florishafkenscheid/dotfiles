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
    property bool hyprClientsRefreshPending: false
    property bool vpnListenerReady: false
    readonly property bool needsPrismIcons: hyprClients.some(client =>
        /^minecraft/i.test(hyprAppId(client))
    )
    // Steam game classes are arbitrary; only probe clients needing the fallback.
    readonly property bool needsSteamIcons: hyprClients.some(client => {
        const appId = hyprAppId(client);
        const entry = DesktopEntries.heuristicLookup(appId);
        return !/^minecraft/i.test(appId) && !(entry && entry.icon);
    })
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
    property var pendingVolumeSteps: []
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

    function normalizedAddress(address) {
        return String(address || "").toLowerCase().replace(/^0x/, "");
    }

    function isActiveClient(client) {
        const active = Hyprland.activeToplevel;
        const address = normalizedAddress(client.address);
        return !!active && !!address
            && address === normalizedAddress(active.address);
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
        if (action === "scroll") {
            root.pendingVolumeSteps.push(value);
            flushVolumeSteps();
        } else if (!volumeAction.running) {
            const command = [root.helperDir + "/set-volume.sh", action];
            if (value !== undefined)
                command.push(String(value));
            volumeAction.exec(command);
        }
    }

    function flushVolumeSteps(): void {
        if (!volumeAction.running && root.pendingVolumeSteps.length > 0)
            volumeAction.exec([
                root.helperDir + "/set-volume.sh", "scroll",
                root.pendingVolumeSteps.shift()
            ]);
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
        onExited: root.flushVolumeSteps()

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
        onExited: { if (!root.vpnListenerReady) vpnPoll.refresh(); }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuFile.reload();
            memoryFile.reload();
            gpuFile.reload();
        }
    }

    FileView {
        id: cpuFile
        path: "/proc/stat"

        onLoaded: {
            const line = text().split("\n").find(line => /^cpu\s/.test(line));
            if (!line)
                return;
            const values = line.trim().split(/\s+/).slice(1).map(Number);
            if (values.length < 5 || values.some(value => !Number.isFinite(value)))
                return;

            const total = values.reduce((sum, value) => sum + value, 0);
            const idle = values[3] + values[4];
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

    FileView {
        id: gpuFile
        path: "/sys/bus/pci/devices/0000:03:00.0/gpu_busy_percent"

        onLoaded: {
            const value = Number(text().trim());
            if (Number.isFinite(value))
                root.gpuPercent = Math.round(value);
        }
    }

    FileView {
        id: memoryFile
        path: "/proc/meminfo"

        onLoaded: {
            const totalMatch = text().match(/^MemTotal:\s+(\d+)/m);
            const availableMatch = text().match(/^MemAvailable:\s+(\d+)/m);
            if (!totalMatch || !availableMatch)
                return;
            const total = Number(totalMatch[1]);
            const available = Number(availableMatch[1]);
            if (total <= 0)
                return;
            const percent = 100 * (total - available) / total;
            // Match awk printf's rounding, including ties to even.
            const floor = Math.floor(percent);
            root.memoryPercent = percent - floor === 0.5
                ? floor + (floor % 2) : Math.round(percent);
        }
    }

    function refreshHyprClients(): void {
        root.hyprClientsRefreshPending = true;
        clientsRefreshTimer.restart();
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (["openwindow", "closewindow", "movewindow", "movewindowv2",
                 "windowtitle", "windowtitlev2", "windowclass", "windowclassv2",
                 "activewindow", "activewindowv2", "moveworkspace",
                 "moveworkspacev2", "configreloaded"].includes(event.name))
                root.refreshHyprClients();
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshHyprClients()
    }

    Timer {
        id: clientsRefreshTimer
        interval: 80
        onTriggered: {
            if (!clientsProcess.running) {
                root.hyprClientsRefreshPending = false;
                clientsProcess.running = true;
            }
        }
    }

    Process {
        id: clientsProcess
        command: ["hyprctl", "-j", "clients"]
        onExited: {
            if (root.hyprClientsRefreshPending)
                clientsRefreshTimer.restart();
        }

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const value = root.parseJson(text, null);
                if (!Array.isArray(value))
                    return;

                if (value.length === 0) {
                    root.hyprEmptyClientPolls++;
                    if (root.hyprEmptyClientPolls >= 2) {
                        root.hyprClients = [];
                        root.hyprClientsReady = true;
                    } else {
                        // Confirm an empty result promptly, rather than waiting 10s.
                        root.refreshHyprClients();
                    }
                } else {
                    root.hyprEmptyClientPolls = 0;
                    root.hyprClients = value;
                    root.hyprClientsReady = true;
                }
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
        enabled: root.needsPrismIcons
        onEnabledChanged: { if (enabled) refresh(); }
        command: [root.helperDir + "/get-prism-instance-icons.py"]

        onUpdated: text => {
            const value = root.parseJson(text, null);
            if (value && typeof value === "object")
                root.prismIconData = value;
        }
    }

    CommandPoll {
        interval: 2000
        enabled: root.needsSteamIcons
        onEnabledChanged: { if (enabled) refresh(); }
        // Steam exports the authoritative app ID into each game process.
        command: [root.helperDir + "/get-steam-app-icons.py"]

        onUpdated: text => {
            const value = root.parseJson(text, null);
            if (value && typeof value === "object")
                root.steamIconData = value;
        }
    }

    Process {
        id: vpnListener
        command: ["mullvad", "status", "-j", "listen"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                const value = root.parseJson(data, null);
                if (value && typeof value.state === "string") {
                    root.vpnState = value.state;
                    root.vpnListenerReady = true;
                }
            }
        }

        onExited: {
            root.vpnListenerReady = false;
            vpnPoll.refresh();
            vpnRetryTimer.restart();
        }
    }

    Timer {
        id: vpnRetryTimer
        interval: 10000
        onTriggered: vpnListener.running = true
    }

    CommandPoll {
        id: vpnPoll
        enabled: !root.vpnListenerReady
        interval: 5000
        command: ["sh", "-c", "mullvad status -j 2>/dev/null | jq -r '.state // \"disconnected\"'"]

        onUpdated: text => {
            if (!root.vpnListenerReady)
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

                Item {
                    id: workspaceIndicator

                    property bool ready: false
                    visible: windowStrip.activeItem !== null
                    x: windowStrip.x + (windowStrip.activeItem ? windowStrip.activeItem.x : 0)
                    y: windowStrip.y
                    width: windowStrip.activeItem ? windowStrip.activeItem.width : 0
                    height: windowStrip.height

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 3
                        anchors.bottomMargin: 9
                        radius: 9
                        color: root.theme.accentSoft
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: Math.max(0, parent.width - 12)
                        height: 2
                        color: root.theme.accent
                    }

                    Behavior on x {
                        enabled: workspaceIndicator.ready
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Behavior on width {
                        enabled: workspaceIndicator.ready
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }

                Row {
                    id: windowStrip

                    property Item activeItem: null
                    onActiveItemChanged: {
                        if (!activeItem)
                            workspaceIndicator.ready = false;
                        else if (!workspaceIndicator.ready)
                            Qt.callLater(() => { workspaceIndicator.ready = activeItem !== null; });
                    }

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: panel.hyprWorkspaces

                        delegate: Item {
                            id: hyprWorkspaceItem

                            required property var modelData
                            readonly property bool isActive: modelData.active
                            onIsActiveChanged: {
                                if (isActive)
                                    windowStrip.activeItem = hyprWorkspaceItem;
                            }
                            Component.onCompleted: {
                                if (isActive)
                                    windowStrip.activeItem = hyprWorkspaceItem;
                            }
                            Component.onDestruction: {
                                if (windowStrip.activeItem === hyprWorkspaceItem)
                                    windowStrip.activeItem = null;
                            }

                            width: hyprWorkspaceContent.implicitWidth + 24
                            height: 58

                            Rectangle {
                                anchors.fill: parent
                                anchors.topMargin: 3
                                anchors.bottomMargin: 9
                                radius: 9
                                color: !hyprWorkspaceItem.isActive && hyprWorkspaceMouse.containsMouse
                                    ? root.theme.surfaceHover : "transparent"

                                Behavior on color {
                                    ColorAnimation { duration: 160; easing.type: Easing.OutCubic }
                                }
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

                                    Behavior on color {
                                        ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                                    }
                                }

                                Repeater {
                                    model: root.hyprWorkspaceApps(modelData)

                                    delegate: Item {
                                        required property var modelData

                                        readonly property bool isActive: root.isActiveClient(modelData)

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
                                            opacity: isActive ? 1 : 0.72
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰣆"
                                            color: isActive
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

                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.horizontalCenterOffset: volumeMouse.containsMouse
                                ? -(volumeTag.implicitWidth + 9) / 2 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 9

                            Behavior on anchors.horizontalCenterOffset {
                                NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
                            }

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
                        }

                        Text {
                            id: volumeTag

                            anchors.left: volumeRow.right
                            anchors.leftMargin: 9
                            anchors.top: volumeRow.top
                            opacity: volumeMouse.containsMouse ? 1 : 0
                            text: root.volumeData.target === "player" ? "T" : "S"
                            color: root.theme.foregroundMuted
                            font.family: root.theme.monoFontFamily
                            font.pixelSize: 17

                            Behavior on opacity {
                                NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
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
                        id: clockDivider
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 34
                        color: root.theme.divider
                    }

                    Item {
                        id: clockContainer

                        readonly property real expandedWidth: clockBlock.implicitWidth + 20
                        // Center the full hover block between the divider and screen edge.
                        readonly property real expandedOffset:
                            (clockDivider.x + clockDivider.width + panel.width
                                - rightSection.x - expandedWidth) / 2 - x

                        width: clockHours.implicitWidth + 20
                        height: 54

                        Rectangle {
                            x: clockContainer.expandedOffset
                            anchors.verticalCenter: parent.verticalCenter
                            width: clockContainer.expandedWidth
                            height: parent.height
                            radius: 9
                            color: clockMouse.containsMouse
                                ? root.theme.surfaceHover : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }
                        }

                        Row {
                            id: clockBlock

                            anchors.left: parent.left
                            anchors.leftMargin: 10 + (clockMouse.containsMouse
                                ? clockContainer.expandedOffset : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            Behavior on anchors.leftMargin {
                                NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
                            }

                            Text {
                                id: clockHours
                                text: Qt.formatDateTime(clock.date, "HH:mm")
                                color: root.theme.foreground
                                font.family: root.theme.monoFontFamily
                                font.pixelSize: 29
                                font.weight: Font.Medium
                            }

                            Text {
                                id: clockSeconds
                                text: Qt.formatDateTime(clock.date, ":ss")
                                color: root.theme.foregroundMuted
                                opacity: clockMouse.containsMouse ? 1 : 0
                                clip: true
                                font.family: root.theme.monoFontFamily
                                font.pixelSize: 21

                                Behavior on opacity {
                                    NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        MouseArea {
                            id: clockMouse

                            x: clockContainer.expandedOffset
                            anchors.verticalCenter: parent.verticalCenter
                            width: clockContainer.expandedWidth
                            height: parent.height
                            hoverEnabled: true
                        }
                    }
                }
            }
        }
    }
}
