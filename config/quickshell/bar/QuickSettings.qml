import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

// Ajustes rápidos (volumen + interruptores). Vive dentro de la pestaña Inicio.
Item {
    id: qs

    required property var notifs
    property bool active: false          // panel visible → consulta la red
    property bool focused: false         // el teclado está dentro de este panel
    // 0 volumen · 1 selector de salida · 2..5 interruptores (2x2) · 6 lista de salidas
    property int sel: 0
    property int devIdx: 0
    onFocusedChanged: if (focused) { sel = 0; devIdx = 0 }

    function toggleTile(i) {
        if (i === 3 && bt) bt.enabled = !bt.enabled
        else if (i === 4 && source?.audio) source.audio.muted = !source.audio.muted
        else if (i === 5) notifs.dnd = !notifs.dnd
    }
    // Devuelve true si consumió la tecla; false deja que el dashboard saque el foco
    function handleKey(k) {
        const enter = k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space
        if (sel === 0) {
            if (k === Qt.Key_Left || k === Qt.Key_Right) {
                if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, vol + (k === Qt.Key_Right ? 0.05 : -0.05)))
                return true
            }
            if (enter) { if (sink?.audio) sink.audio.muted = !sink.audio.muted; return true }
            if (k === Qt.Key_Down) { sel = 1; return true }
            return false
        }
        if (sel === 1) {
            if (enter) { devicesOpen = !devicesOpen; return true }
            if (k === Qt.Key_Up) { sel = 0; return true }
            if (k === Qt.Key_Down) {
                if (devicesOpen && sinks.length > 0) { sel = 6; devIdx = Math.max(0, sinks.findIndex(n => sink && n.id === sink.id)) }
                else if (!devicesOpen) sel = 2
                return true
            }
            return true
        }
        if (sel === 6) {
            if (k === Qt.Key_Down) { devIdx = Math.min(sinks.length - 1, devIdx + 1); return true }
            if (k === Qt.Key_Up) { if (devIdx > 0) devIdx--; else sel = 1; return true }
            if (enter) { Pipewire.preferredDefaultAudioSink = sinks[devIdx]; devicesOpen = false; sel = 1; return true }
            return true
        }
        // interruptores
        const g = sel - 2
        if (k === Qt.Key_Left && g % 2 === 1) { sel--; return true }
        if (k === Qt.Key_Right && g % 2 === 0) { sel++; return true }
        if (k === Qt.Key_Down && g < 2) { sel += 2; return true }
        if (k === Qt.Key_Up) { if (g >= 2) sel -= 2; else sel = 1; return true }
        if (enter) { toggleTile(sel); return true }
        return k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Down
    }
    onDevicesOpenChanged: if (!devicesOpen && sel === 6) sel = 1

    implicitHeight: col.implicitHeight

    // ── Audio ───────────────────────────────────────────────
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    readonly property real vol: sink?.audio?.volume ?? 0
    readonly property bool volMuted: sink?.audio?.muted ?? false
    readonly property string volIcon: volMuted || vol <= 0 ? "audio-volume-muted"
        : vol < 0.34 ? "audio-volume-low" : vol < 0.67 ? "audio-volume-medium" : "audio-volume-high"
    property bool devicesOpen: false
    onActiveChanged: if (!active) devicesOpen = false

    // ── Bluetooth ───────────────────────────────────────────
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var btConnected: bt ? bt.devices.values.filter(d => d.connected) : []

    // ── Red (solo lectura) ──────────────────────────────────
    property bool netUp: false
    property string netType: "none"
    property string netSub: "Sin conexión"
    Process {
        id: netProc
        command: ["sh", "-c",
            "nmcli -t -f DEVICE,TYPE,STATE device 2>/dev/null | grep -E ':(ethernet|wifi):connected' | head -1; echo '|'; " +
            "ip -4 -o addr show scope global 2>/dev/null | grep -vE ' (br-|docker|veth)' | awk '{print $4}' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("|\n")
                const dev = (parts[0] || "").trim()
                const ip = (parts[1] || "").trim().split("/")[0]
                if (dev === "") { qs.netUp = false; qs.netType = "none"; qs.netSub = "Sin conexión"; return }
                qs.netUp = true
                qs.netType = dev.split(":")[1]
                qs.netSub = ip !== "" ? ip : "Conectado"
            }
        }
    }
    Timer {
        interval: 8000; repeat: true; triggeredOnStart: true
        running: qs.active
        onTriggered: netProc.running = true
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 10

        // ── Volumen + selector de salida ────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PillSlider {
                Layout.fillWidth: true
                showValue: false
                icon: qs.volIcon
                value: qs.vol
                dimmed: qs.volMuted
                onMoved: v => { if (qs.sink?.audio) qs.sink.audio.volume = v }
                onIconClicked: if (qs.sink?.audio) qs.sink.audio.muted = !qs.sink.audio.muted
                FocusRing { shown: qs.focused && qs.sel === 0 }
            }

            Rectangle {
                implicitWidth: 46; implicitHeight: 46; radius: 23
                color: qs.devicesOpen ? Theme.accent : (arrowM.containsMouse ? Theme.bgHover : Theme.bgSoft)
                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                Icon {
                    anchors.centerIn: parent
                    name: "pan-down"; size: 16
                    color: qs.devicesOpen ? Theme.ink : Theme.text
                    rotation: qs.devicesOpen ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: Theme.dur(180); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard } }
                }
                MouseArea { id: arrowM; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: qs.devicesOpen = !qs.devicesOpen }
                FocusRing { shown: qs.focused && qs.sel === 1 }
            }
        }

        // ── Interruptores (o lista de salidas) ──────────────
        Item {
            Layout.fillWidth: true
            implicitHeight: 2 * 56 + 8

            GridLayout {
                anchors.fill: parent
                visible: !qs.devicesOpen
                columns: 2
                rowSpacing: 8
                columnSpacing: 8

                Tile {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    icon: qs.netType === "wifi" ? "network-wireless" : qs.netUp ? "network-wired" : "network-offline"
                    title: qs.netType === "wifi" ? "WiFi" : "Ethernet"
                    sub: qs.netSub
                    on: qs.netUp
                    FocusRing { shown: qs.focused && qs.sel === 2 }
                }
                Tile {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    icon: !qs.bt || !qs.bt.enabled ? "bluetooth-disabled" : "bluetooth-active"
                    title: "Bluetooth"
                    sub: !qs.bt ? "No disponible" : !qs.bt.enabled ? "Apagado"
                         : qs.btConnected.length > 0 ? qs.btConnected[0].name : "Activado"
                    on: qs.bt ? qs.bt.enabled : false
                    onClicked: if (qs.bt) qs.bt.enabled = !qs.bt.enabled
                    FocusRing { shown: qs.focused && qs.sel === 3 }
                }
                Tile {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    icon: qs.source?.audio?.muted ? "microphone-sensitivity-muted" : "microphone-sensitivity-high"
                    title: "Micrófono"
                    sub: qs.source?.audio?.muted ? "Silenciado" : "Activo"
                    on: qs.source?.audio ? !qs.source.audio.muted : false
                    onClicked: if (qs.source?.audio) qs.source.audio.muted = !qs.source.audio.muted
                    FocusRing { shown: qs.focused && qs.sel === 4 }
                }
                Tile {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    icon: qs.notifs.dnd ? "notifications-disabled" : "preferences-system-notifications"
                    title: "No molestar"
                    sub: qs.notifs.dnd ? "Activado" : "Desactivado"
                    on: qs.notifs.dnd
                    onClicked: qs.notifs.dnd = !qs.notifs.dnd
                    FocusRing { shown: qs.focused && qs.sel === 5 }
                }
            }

            // Lista de salidas de audio, en el mismo espacio de los interruptores
            Rectangle {
                anchors.fill: parent
                visible: qs.devicesOpen
                radius: 24
                color: Theme.bgSoft

                ListView {
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: qs.sinks
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool kbd: qs.focused && qs.sel === 6 && qs.devIdx === index
                        readonly property bool current: qs.sink && qs.sink.id === modelData.id
                        width: ListView.view.width
                        height: 40
                        radius: 20
                        color: current ? Theme.accentSoft : ((rm.containsMouse || kbd) ? Theme.bgHover : "transparent")
                        border.width: kbd ? 2 : 0
                        border.color: Theme.accent
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            Text {
                                Layout.fillWidth: true
                                text: modelData.description || modelData.nickname || modelData.name
                                elide: Text.ElideRight
                                color: current ? Theme.accent : Theme.text
                                font.family: Theme.font
                                font.pixelSize: 13
                                font.weight: current ? Font.Medium : Font.Normal
                            }
                            Rectangle { visible: current; implicitWidth: 7; implicitHeight: 7; radius: 4; color: Theme.accent }
                        }
                        MouseArea {
                            id: rm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { Pipewire.preferredDefaultAudioSink = modelData; qs.devicesOpen = false }
                        }
                    }
                }
            }
        }
    }
}
