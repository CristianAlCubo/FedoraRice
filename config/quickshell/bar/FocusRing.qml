import QtQuick

// Aro de foco para la navegación con teclado (se pone como hijo del elemento).
Rectangle {
    property bool shown: false
    anchors.fill: parent
    anchors.margins: -4
    radius: Math.min(width, height) / 2
    color: "transparent"
    border.width: 2
    border.color: Theme.accent
    opacity: shown ? 1 : 0
    visible: opacity > 0.01
    z: 20
    Behavior on opacity { NumberAnimation { duration: Theme.dur(140) } }
}
