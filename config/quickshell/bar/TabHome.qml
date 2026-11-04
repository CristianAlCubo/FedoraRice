import QtQuick
import QtQuick.Layouts

// Pestaña Inicio: reloj, ajustes rápidos (volumen + interruptores) y calendario.
Item {
    id: tab
    required property var notifs
    property bool active: false
    property bool focused: false
    readonly property bool interactive: true
    function handleKey(k) { return settings.handleKey(k) }
    property date now: new Date()

    RowLayout {
        anchors.fill: parent
        spacing: 16

        // ── Izquierda: reloj + ajustes rápidos ──────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 6
            spacing: 0

            Text {
                text: Qt.formatDateTime(tab.now, "HH:mm")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 62
                font.weight: Font.Light
                font.features: { "tnum": 1 }
            }
            Text {
                text: {
                    const s = Qt.locale().toString(tab.now, "dddd, d 'de' MMMM")
                    return s.charAt(0).toUpperCase() + s.slice(1)
                }
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 15
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                Layout.bottomMargin: 10
                spacing: 10
                ProfileCard { Layout.fillWidth: true; Layout.fillHeight: true; active: tab.active }
                WeatherCard { Layout.preferredWidth: 156; Layout.fillHeight: true }
            }

            QuickSettings {
                id: settings
                focused: tab.focused
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                notifs: tab.notifs
                active: tab.active
            }
        }

        // ── Derecha: calendario ─────────────────────────────
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 7 * 38 + 36
            radius: 26
            color: Theme.bgSoft
            border.width: 1
            border.color: Theme.stroke

            Calendar {
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                now: tab.now
            }
        }
    }
}
