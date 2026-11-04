import QtQuick

// Slider en forma de píldora con icono dentro (estilo control center moderno).
Item {
    id: p
    property real value: 0
    property string icon
    property bool dimmed: false
    property bool showValue: true
    signal moved(real v)
    signal iconClicked()

    implicitHeight: 46
    readonly property real clamped: Math.max(0, Math.min(1, value))
    readonly property real fillW: clamped > 0 ? Math.max(height, clamped * width) : 0
    readonly property bool iconOnFill: fillW > 34 && !dimmed

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.bgSoft
        border.width: 1
        border.color: Theme.stroke

        Rectangle {
            width: p.fillW
            height: parent.height
            radius: height / 2
            visible: width > 0
            color: p.dimmed ? Theme.fade(0.16) : Theme.accent
            Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: Theme.dur(90) } }
            Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function setFrom(mx) { p.moved(Math.max(0, Math.min(1, mx / width))) }
        onPressed: m => setFrom(m.x)
        onPositionChanged: m => { if (pressed) setFrom(m.x) }
    }

    Icon {
        id: ico
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        name: p.icon
        size: 20
        color: p.iconOnFill ? Theme.ink : Theme.text
        Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
    }
    MouseArea {                         // click en el icono: silenciar
        x: 0; width: p.height; height: parent.height
        cursorShape: Qt.PointingHandCursor
        onClicked: p.iconClicked()
    }

    Text {
        visible: p.showValue
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(p.clamped * 100) + "%"
        color: p.fillW > p.width - 56 && !p.dimmed ? Theme.ink : Theme.dim
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
        Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
    }
}
