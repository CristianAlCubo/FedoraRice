import QtQuick

// Slider minimalista. value va de 0 a 1; emite moved(v) al arrastrar.
Item {
    id: s
    property real value: 0
    property color fill: Theme.accent
    property bool interactive: true
    signal moved(real v)

    implicitHeight: 22
    readonly property real clamped: Math.max(0, Math.min(1, value))

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.s3

        Rectangle {
            width: s.clamped * parent.width
            height: parent.height
            radius: 3
            color: s.fill
            Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: Theme.dur(90) } }
        }
    }

    Rectangle {
        visible: s.interactive && (ma.containsMouse || ma.pressed)
        x: s.clamped * track.width - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 14; height: 14; radius: 7
        color: Theme.text
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: s.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function setFrom(mx) { s.moved(Math.max(0, Math.min(1, mx / width))) }
        onPressed: m => setFrom(m.x)
        onPositionChanged: m => { if (pressed) setFrom(m.x) }
    }
}
