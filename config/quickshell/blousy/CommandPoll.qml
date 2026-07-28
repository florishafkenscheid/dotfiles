import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var command: []
    property int interval: 2000
    property bool enabled: true
    property string output: ""

    signal updated(string text)

    function refresh(): void {
        if (root.enabled && !process.running)
            process.running = true;
    }

    Process {
        id: process

        command: root.command

        stdout: StdioCollector {
            id: collector

            waitForEnd: true

            onStreamFinished: {
                const value = collector.text.trim();
                root.output = value;
                root.updated(value);
            }
        }
    }

    Timer {
        interval: root.interval
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
