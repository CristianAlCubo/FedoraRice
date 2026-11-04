import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Tarjeta de perfil: avatar, usuario@equipo, distro, WM y tiempo encendido.
Rectangle {
    id: pc
    property bool active: false
    radius: 22
    color: Theme.s2

    readonly property string home: Quickshell.env("HOME")
    property string distro: "Linux"
    property string host: ""
    property real upSecs: 0

    FileView { id: osr; path: "/etc/os-release"; printErrors: false
        onLoaded: { const m = text().match(/^PRETTY_NAME="?([^"\n]*)"?/m); if (m) pc.distro = m[1].replace(/\s*\(.*\)/, "") } }
    FileView { id: hn; path: "/proc/sys/kernel/hostname"; printErrors: false
        onLoaded: pc.host = text().trim() }
    FileView { id: up; path: "/proc/uptime"; printErrors: false
        onLoaded: pc.upSecs = Number(text().split(" ")[0]) }
    Timer { interval: 30000; running: pc.active; repeat: true; triggeredOnStart: true
        onTriggered: { up.reload(); osr.reload(); hn.reload() } }

    function fmt(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        return (d > 0 ? d + " d " : "") + (h > 0 ? h + " h " : "") + m + " min"
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        RoundClip {
            Layout.preferredWidth: 54; Layout.preferredHeight: 54
            radius: 27
            Image {
                anchors.fill: parent
                source: "file://" + pc.home + "/.config/hypr/avatar.png"
                sourceSize: Qt.size(108, 108)
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: Quickshell.env("USER"); color: Theme.text
                font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold
                elide: Text.ElideRight; Layout.fillWidth: true }
            Row { spacing: 6
                Text { text: ""; font.family: Theme.mono; font.pixelSize: 11; color: Theme.accent }
                Text { text: pc.distro; color: Theme.dim; font.family: Theme.font; font.pixelSize: 11 } }
            Row { spacing: 6
                Text { text: ""; font.family: Theme.mono; font.pixelSize: 11; color: Theme.accent2 }
                Text { text: Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 11 } }
            Row { spacing: 6
                Text { text: ""; font.family: Theme.mono; font.pixelSize: 11; color: Theme.green }
                Text { text: pc.fmt(pc.upSecs); color: Theme.dim; font.family: Theme.font; font.pixelSize: 11 } }
        }
    }
}
