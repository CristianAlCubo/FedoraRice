import QtQuick
import QtQuick.Effects

// Recorta su contenido con esquinas redondeadas.
// Uso: RoundClip { radius: 14; Image { anchors.fill: parent; ... } }
Item {
    id: rc
    property real radius: 16
    default property alias content: holder.data

    Item {
        id: holder
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }
    Rectangle { id: mask; anchors.fill: parent; radius: rc.radius; visible: false; layer.enabled: true }
}
