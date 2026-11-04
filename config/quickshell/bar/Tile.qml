import QtQuick

// Botón de ajustes rápidos estilo GNOME: píldora, sólida cuando está activa.
Rectangle {
    id: t
    property string icon
    property string title
    property string sub
    property bool on: false
    signal clicked()

    readonly property color fg:  on ? Theme.ink : Theme.text
    readonly property color fg2: on ? Qt.alpha(Theme.ink, 0.62) : Theme.dim

    implicitHeight: 56
    radius: height / 2
    color: on ? Theme.accent : (m.containsMouse ? Theme.bgHover : Theme.bgSoft)
    Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }

    Icon {
        id: ico
        x: 20
        anchors.verticalCenter: parent.verticalCenter
        name: t.icon
        size: 20
        color: t.fg
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: ico.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 16
        spacing: 1
        Text {
            width: parent.width
            text: t.title
            elide: Text.ElideRight
            color: t.fg
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
            Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
        }
        Text {
            width: parent.width
            visible: t.sub !== ""
            text: t.sub
            elide: Text.ElideRight
            color: t.fg2
            font.family: Theme.font
            font.pixelSize: 11
            Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
        }
    }

    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: t.clicked()
    }

    Ripple {}
}
