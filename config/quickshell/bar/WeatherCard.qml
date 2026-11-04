import QtQuick
import QtQuick.Layouts

// Tarjeta de clima: icono, temperatura, descripción y mínima/máxima.
Rectangle {
    id: wc
    radius: 22
    color: Theme.s2

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10
        Text {
            text: Weather.ok ? Weather.glyph : ""
            font.family: Theme.mono; font.pixelSize: 38
            color: Weather.isDay ? Theme.yellow : Theme.accent2
            Layout.alignment: Qt.AlignVCenter
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text { text: Weather.ok ? Math.round(Weather.temp) + "°C" : "—"; color: Theme.text
                font.family: Theme.font; font.pixelSize: 22; font.weight: Font.Medium; font.features: { "tnum": 1 } }
            Text { text: Weather.ok ? Weather.desc : "Sin datos"; color: Theme.dim
                font.family: Theme.font; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { visible: Weather.ok; text: "↓ " + Math.round(Weather.lo) + "°  ↑ " + Math.round(Weather.hi) + "°"
                color: Theme.dim; font.family: Theme.font; font.pixelSize: 11 }
        }
    }
}
