//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

ShellRoot {
    id: root

    // ── Tema (Tokyo Night, ver Theme.qml) ───────────────────
    readonly property color bg:      Theme.bgBar
    readonly property color stroke:  Theme.stroke
    readonly property color text:    Theme.text
    readonly property color dim:     Theme.dim
    readonly property color accent:  Theme.accent
    readonly property string font:   Theme.font

    // ── Datos del sistema ───────────────────────────────────
    property real cpu: 0
    property real mem: 0
    property var _prev: null

    FileView { id: statFile; path: "/proc/stat"
        onLoaded: {
            const p = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            const idle = p[3] + p[4]
            const total = p.reduce((a, b) => a + b, 0)
            if (root._prev) {
                const dt = total - root._prev.total
                const di = idle - root._prev.idle
                if (dt > 0) root.cpu = 1 - di / dt
            }
            root._prev = { total: total, idle: idle }
        }
    }
    FileView { id: memFile; path: "/proc/meminfo"
        onLoaded: {
            const m = {}
            text().split("\n").forEach(l => {
                const x = l.match(/^(\w+):\s+(\d+)/)
                if (x) m[x[1]] = Number(x[2])
            })
            if (m.MemTotal) root.mem = 1 - m.MemAvailable / m.MemTotal
        }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { statFile.reload(); memFile.reload() }
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink?.audio ?? null

    // ── Micrófono: estado para el botón de la barra (solo encendido/apagado) ──
    PwObjectTracker { objects: [Pipewire.defaultAudioSource] }
    readonly property var mic: Pipewire.defaultAudioSource?.audio ?? null

    SystemClock { id: clock; precision: SystemClock.Seconds }

    Launcher { id: launcher }
    Notifications { id: notifs }
    Recorder { id: rec }
    Dashboard { id: nc; notifs: notifs; rec: rec }
    Settings { id: settingsPanel }
    Widgets {}
    TrayMenu { id: tray }
    Osd {}
    Frame {}
    SessionMenu {}
    GameMode { id: gamemode }
    Toasts { id: toasts; notifs: notifs; gamemode: gamemode }
    Popouts { id: pop }
    RightPanel { id: controls; notifs: notifs; rec: rec; dash: nc }

    // ── Una barra por monitor ───────────────────────────────
    // ── Sidebar izquierda (una por monitor) ─────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            readonly property var hyprMon: Hyprland.monitorFor(modelData)
            function hov(kind, item, ws) { pop.hover(kind, item.mapToItem(null, 0, item.height / 2).y, modelData.name, ws ?? null) }
            Process { id: hyprProc }
            function wsStep(dir) { hyprProc.command = ["hyprctl", "dispatch", 'hl.dsp.focus({ workspace = "e' + dir + '1" })']; hyprProc.running = true }

            anchors { top: true; left: true; bottom: true }
            implicitWidth: Theme.sidebarW
            color: "transparent"

            Item {      // el fondo lo dibuja Frame.qml (la sidebar es parte del marco)
                anchors.fill: parent

                // ── Arriba: lanzador, workspaces ──
                Column {
                    anchors { top: parent.top; topMargin: 10; horizontalCenter: parent.horizontalCenter }
                    spacing: 14

                    // Lanzador (sube desde abajo)
                    Rectangle {
                        width: 40; height: 40; radius: 20
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: launcher.open ? Theme.accentSoft : lnM.containsMouse ? Theme.bgHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                        Text {
                            anchors.centerIn: parent
                            text: ""          // Fedora
                            font.family: Theme.mono
                            font.pixelSize: 22
                            color: Theme.accent
                        }
                        MouseArea { id: lnM; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launcher.open = !launcher.open }
                    }

                    // Workspaces (vertical): icono de la app (o número); rueda = cambiar; hover = lista de ventanas
                    Item {
                        id: wsWrap
                        width: 36
                        height: wsCol.implicitHeight
                        anchors.horizontalCenter: parent.horizontalCenter
                        // Resalte único que se desliza (con resorte leve) hacia el workspace activo
                        property var activeWs: null   // lo fija el delegado activo
                        Rectangle {
                            id: wsInd
                            width: 36; height: 36; radius: 12
                            visible: wsWrap.activeWs !== null
                            y: wsWrap.activeWs ? wsWrap.activeWs.y : 0
                            color: Theme.accentSoft
                            border.width: 1
                            border.color: Theme.accentLine
                            Behavior on y { Anim { kind: "fastSpatial" } }
                        }
                    Column {
                        id: wsCol
                        spacing: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        Repeater {
                            model: Hyprland.workspaces
                            delegate: Rectangle {
                                id: ws
                                required property var modelData
                                readonly property bool active: modelData.focused
                                    || (bar.hyprMon && bar.hyprMon.activeWorkspace === modelData)
                                readonly property int nwin: modelData.toplevels.values.length
                                readonly property string cls: nwin > 0 ? (modelData.toplevels.values[0].lastIpcObject?.class ?? "") : ""
                                readonly property string icon: Apps.icon(cls)
                                visible: modelData.id > 0 && modelData.monitor === bar.hyprMon
                                    && (active || nwin > 0)
                                width: 36
                                height: visible ? 36 : 0
                                radius: 12
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: !active && wsMouse.containsMouse ? Theme.bgHover : "transparent"
                                onActiveChanged: if (active) wsWrap.activeWs = ws
                                Component.onCompleted: if (active) wsWrap.activeWs = ws
                                scale: wsMouse.containsMouse ? 1.06 : 1
                                Behavior on scale { NumberAnimation { duration: Theme.tFast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard } }
                                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }

                                Image {
                                    anchors.centerIn: parent
                                    width: 22; height: 22
                                    visible: ws.icon !== "" && status === Image.Ready
                                    source: ws.icon
                                    sourceSize: Qt.size(44, 44)
                                    smooth: true
                                    opacity: ws.active ? 1 : 0.8
                                }
                                Text {   // sin icono: número del espacio
                                    anchors.centerIn: parent
                                    visible: ws.icon === "" || wsIcon2.status !== Image.Ready
                                    text: ws.modelData.name.replace(/^\D*/, "") || ws.modelData.name
                                    color: ws.active ? Theme.accent : Theme.dim
                                    font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold
                                }
                                Image { id: wsIcon2; visible: false; source: ws.icon; sourceSize: Qt.size(44, 44) }
                                Rectangle {   // varias ventanas
                                    visible: ws.nwin > 1
                                    anchors { right: parent.right; bottom: parent.bottom; rightMargin: 1; bottomMargin: 1 }
                                    width: 14; height: 14; radius: 7; color: Theme.accent
                                    Text { anchors.centerIn: parent; text: ws.nwin; color: Theme.ink; font.family: Theme.font; font.pixelSize: 9; font.weight: Font.Bold }
                                }

                                MouseArea {
                                    id: wsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ws.modelData.activate()
                                    onContainsMouseChanged: containsMouse ? bar.hov("workspace", ws, ws.modelData) : pop.cancelHover()
                                }
                            }
                        }
                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: e => bar.wsStep(e.angleDelta.y > 0 ? "-" : "+")
                        }
                    }
                    }

                    // Ventana activa (icono; el título va en el tooltip del ratón)
                    Image {
                        id: winIcon
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 22; height: 22
                        readonly property string cls: (Hyprland.activeToplevel?.lastIpcObject?.class ?? "").toLowerCase()
                        visible: cls !== "" && status === Image.Ready
                        source: Apps.icon(cls)
                        sourceSize: Qt.size(44, 44)
                        smooth: true
                        opacity: 0.9
                        HoverHandler { onHoveredChanged: hovered ? bar.hov("window", winIcon) : pop.cancelHover() }
                    }
                }

                // ── Centro: bandeja del sistema ──
                Column {
                    anchors { centerIn: parent }
                    spacing: 12
                    Repeater {
                        model: SystemTray.items
                        delegate: Image {
                            id: trayIcon
                            required property var modelData
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 18; height: 18
                            // Fedora: los snaps viven en /var/lib/snapd/snap, no en /snap
                            source: String(modelData.icon).replace("path=/snap/", "path=/var/lib/snapd/snap/")
                            sourceSize: Qt.size(36, 36)
                            smooth: true
                            opacity: trayMouse.containsMouse ? 1 : 0.75
                            Behavior on opacity { NumberAnimation { duration: Theme.dur(120) } }
                            MouseArea {
                                id: trayMouse
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.MiddleButton) {
                                        trayIcon.modelData.secondaryActivate()
                                    } else if (trayIcon.modelData.hasMenu) {
                                        // y del centro del icono en pantalla (la sidebar ocupa toda la altura)
                                        const g = trayIcon.mapToItem(null, 0, trayIcon.height / 2)
                                        tray.openFor(trayIcon.modelData, bar.modelData.name, g.y)
                                    } else {
                                        trayIcon.modelData.activate()
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Abajo: grabación, métricas, volumen, reloj, controles ──
                Column {
                    anchors { bottom: parent.bottom; bottomMargin: 10; horizontalCenter: parent.horizontalCenter }
                    spacing: 12

                    // Grabación de pantalla: punto, tiempo, pausa y detener
                    Rectangle {
                        id: recPill
                        visible: rec.active
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 44
                        height: recCol.implicitHeight + 12
                        radius: 14
                        color: rec.paused ? Qt.alpha(Theme.yellow, 0.16) : Qt.alpha(Theme.danger, 0.16)
                        border.width: 1
                        border.color: rec.paused ? Qt.alpha(Theme.yellow, 0.5) : Qt.alpha(Theme.danger, 0.55)

                        Column {
                            id: recCol
                            anchors.centerIn: parent
                            spacing: 5
                            Rectangle {   // punto: parpadea al grabar, fijo en pausa
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 8; height: 8; radius: 4
                                color: rec.paused ? Theme.yellow : Theme.danger
                                property real blink: 1
                                SequentialAnimation on blink {
                                    running: recPill.visible && !rec.paused
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.25; duration: Theme.dur(700) }
                                    NumberAnimation { to: 1; duration: Theme.dur(700) }
                                }
                                opacity: rec.paused ? 1 : blink
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: rec.fmt(rec.elapsed)
                                color: root.text
                                font.family: root.font
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                            Item {   // pausar / reanudar
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 18; height: 18
                                Icon {
                                    anchors.centerIn: parent
                                    name: rec.paused ? "media-playback-start" : "media-playback-pause"
                                    size: 14
                                    color: rpM.containsMouse ? root.accent : root.text
                                }
                                MouseArea { id: rpM; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor; onClicked: rec.toggle() }
                            }
                            Item {   // detener
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 18; height: 18
                                Icon {
                                    anchors.centerIn: parent
                                    name: "media-playback-stop"
                                    size: 14
                                    color: rsM.containsMouse ? Theme.danger : root.text
                                }
                                MouseArea { id: rsM; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor; onClicked: rec.stop() }
                            }
                        }
                    }

                    // Métrica reutilizable (vertical)
                    component Metric: Column {
                        property string label
                        property real value
                        property color tint: root.text
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.label
                            color: root.dim
                            font.family: root.font
                            font.pixelSize: 9
                            font.letterSpacing: 0.8
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.round(parent.value * 100) + "%"
                            color: parent.tint
                            font.family: root.font
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                        }
                    }

                    Item {   // CPU/RAM: hover = estadísticas del sistema
                        id: statsBox
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitWidth: Theme.sidebarW - 16
                        implicitHeight: statsCol.implicitHeight + 6
                        Column {
                            id: statsCol
                            anchors.centerIn: parent
                            spacing: 12
                            Metric { label: "CPU"; value: root.cpu
                                tint: root.cpu > 0.85 ? Theme.danger : root.text }
                            Metric { label: "RAM"; value: root.mem
                                tint: root.mem > 0.9 ? Theme.danger : root.text }
                        }
                        HoverHandler { onHoveredChanged: hovered ? bar.hov("stats", statsBox) : pop.cancelHover() }
                    }

                    // Micrófono: un solo botón, click silencia/activa. Ganancia y entrada: centro de control.
                    // OFF rojo = silenciado · ON verde = activo · N/A gris = sin dispositivo
                    Item {
                        id: micBox
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitWidth: Theme.sidebarW - 16
                        implicitHeight: 44
                        readonly property bool has: root.mic !== null
                        readonly property bool muted: root.mic?.muted ?? false
                        readonly property color tone: !has ? Theme.dim : muted ? Theme.danger : Theme.green

                        Rectangle {
                            id: micPill
                            anchors.centerIn: parent
                            width: 40; height: 40; radius: 14
                            color: micMouse.containsMouse ? Qt.alpha(micBox.tone, 0.22) : Qt.alpha(micBox.tone, micBox.has ? 0.12 : 0)
                            border.width: micBox.muted ? 1 : 0
                            border.color: Qt.alpha(micBox.tone, 0.55)
                            Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }

                            Icon {
                                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 6 }
                                name: micBox.muted || !micBox.has ? "microphone-sensitivity-muted" : "microphone-sensitivity-high"
                                color: micBox.tone; size: 18
                            }
                            Text {
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 4 }
                                text: !micBox.has ? "N/A" : micBox.muted ? "OFF" : "ON"
                                color: micBox.tone
                                font.family: root.font; font.pixelSize: 8; font.letterSpacing: 0.6; font.weight: Font.Medium
                            }
                        }
                        MouseArea {
                            id: micMouse
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.mic) root.mic.muted = !root.mic.muted
                        }
                    }

                    // Volumen: scroll para ajustar, click para silenciar
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitWidth: Theme.sidebarW - 16
                        implicitHeight: volRow.implicitHeight + 6
                        Metric {
                            id: volRow
                            anchors.centerIn: parent
                            label: root.sink?.muted ? "MUTE" : "VOL"
                            value: root.sink?.volume ?? 0
                            tint: root.sink?.muted ? root.dim : root.accent
                        }
                        HoverHandler { id: volHover; onHoveredChanged: hovered ? bar.hov("volume", volHover.parent) : pop.cancelHover() }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.sink) root.sink.muted = !root.sink.muted
                            onWheel: w => {
                                if (!root.sink) return
                                const d = w.angleDelta.y > 0 ? 0.05 : -0.05
                                root.sink.volume = Math.max(0, Math.min(1, root.sink.volume + d))
                            }
                        }
                    }

                    // Reloj → abre el centro de control (cae desde arriba)
                    Item {
                        id: clockBox
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 48
                        height: clockCol.implicitHeight + 14

                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: nc.open ? Theme.bgHover
                                 : clockMouse.containsMouse ? Theme.bgSoft : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                        }
                        Column {
                            id: clockCol
                            anchors.centerIn: parent
                            spacing: -2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatDateTime(clock.date, "HH")
                                color: root.text
                                font.family: root.font
                                font.pixelSize: 17
                                font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatDateTime(clock.date, "mm")
                                color: Theme.accent
                                font.family: root.font
                                font.pixelSize: 17
                                font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                topPadding: 4
                                text: Qt.formatDateTime(clock.date, "d MMM")
                                color: root.dim
                                font.family: root.font
                                font.pixelSize: 9
                            }
                        }
                        Rectangle {   // hay notificaciones guardadas
                            visible: notifs.count > 0
                            anchors { top: parent.top; right: parent.right; topMargin: 2; rightMargin: 2 }
                            width: 7; height: 7; radius: 4
                            color: notifs.dnd ? root.dim : root.accent
                        }
                        MouseArea {
                            id: clockMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: containsMouse ? bar.hov("clock", clockBox) : pop.cancelHover()
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: m => {
                                if (m.button === Qt.RightButton) { pop.pinned = false; pop.shown = false; nc.open = !nc.open; return }
                                // clic: calendario junto a la sidebar, fijo hasta volver a hacer clic
                                if (pop.pinned && pop.kind === "clock") { pop.pinned = false; pop.shown = false }
                                else { nc.open = false; bar.hov("clock", clockBox); pop.pinned = true }
                            }
                        }
                    }

                    // Panel de controles (se abre junto a la sidebar, abajo)
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 40; height: 40; radius: 20
                        color: controls.open ? Theme.accentSoft : ctM.containsMouse ? Theme.bgHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                        Text {
                            anchors.centerIn: parent
                            text: ""          // engranaje
                            font.family: Theme.mono
                            font.pixelSize: 18
                            color: controls.open ? Theme.accent : root.text
                        }
                        MouseArea { id: ctM; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controls.open = !controls.open }
                    }
                }
            }
        }
    }
}
