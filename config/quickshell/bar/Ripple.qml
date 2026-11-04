import QtQuick
import QtQuick.Effects

// Onda de pulsación (como el StateLayer de Caelestia). Poner como ÚLTIMO hijo del botón (con radius):
// no consume el clic, solo dibuja la onda desde el punto pulsado, recortada a la forma del botón.
Item {
    id: r
    anchors.fill: parent
    property real radius: parent && parent.radius !== undefined ? parent.radius : 12
    property color tint: Theme.text

    layer.enabled: true
    layer.effect: MultiEffect { maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle { anchors.fill: parent; radius: r.radius }
    }

    Rectangle {
        id: wave
        property real cx: 0
        property real cy: 0
        x: cx - width / 2; y: cy - height / 2
        width: 0; height: width; radius: width / 2
        color: Qt.alpha(r.tint, 0.16)
        opacity: 0
    }
    ParallelAnimation {
        id: go
        Anim { target: wave; property: "width"; from: 0; to: Math.hypot(r.width, r.height) * 2.1; kind: "slowEffects" }
        SequentialAnimation {
            NumberAnimation { target: wave; property: "opacity"; to: 1; duration: Theme.dur(60) }
            Anim { target: wave; property: "opacity"; to: 0; kind: "slowEffects" }
        }
    }

    function trigger(x, y) { wave.cx = x; wave.cy = y; go.restart() }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => { r.trigger(mouse.x, mouse.y); mouse.accepted = false }
    }
}
