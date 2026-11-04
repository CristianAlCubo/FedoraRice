import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// Popouts que salen de la sidebar al pasar el ratón (fusionados con el borde izquierdo):
// volume · clock (clima) · window · stats · workspace.
// Uso desde la sidebar: pop.hover(kind, yPantalla, nombrePantalla, ws) / pop.cancelHover()
Scope {
    id: pop

    property string kind: ""
    property real anchorY: 0
    property string screenName: ""
    property var ws: null
    property bool shown: false

    property var _pend: null
    function hover(k, y, scr, w) { _pend = { k: k, y: y, s: scr, w: w }; hideT.stop(); showT.restart() }
    function cancelHover() { showT.stop(); hideT.restart() }
    function enter() { hideT.stop() }
    function leave() { hideT.restart() }
    Timer { id: showT; interval: 140
        onTriggered: { if (!pop._pend) return
            pop.kind = pop._pend.k; pop.anchorY = pop._pend.y; pop.screenName = pop._pend.s
            pop.ws = pop._pend.w ?? null; pop.shown = true } }
    Timer { id: hideT; interval: 240; onTriggered: pop.shown = false }

    // qs ipc call popouts open <volume|clock|window|stats|workspace> <y> | close
    IpcHandler {
        target: "popouts"
        function open(k: string, y: int): void {
            pop.kind = k; pop.anchorY = y; pop.screenName = Hyprland.focusedMonitor?.name ?? ""
            pop.ws = Hyprland.focusedWorkspace; pop.shown = true; hideT.stop()
        }
        function close(): void { pop.shown = false }
    }

    Process { id: sh }
    function run(cmd) { sh.command = ["sh", "-c", cmd]; sh.running = true }
    function hypr(lua) { run("hyprctl dispatch '" + lua + "'") }

    Stats { id: pst; active: pop.shown && pop.kind === "stats" }

    // ── Contenidos ──────────────────────────────────────────
    Component {
        id: volumeC
        Column {
            id: vc
            spacing: 10
            PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
            readonly property var sink: Pipewire.defaultAudioSink
            readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
            readonly property real vol: sink?.audio?.volume ?? 0
            readonly property bool muted: sink?.audio?.muted ?? false
            Row {
                spacing: 8
                Text { text: "Volumen"; color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                Text { text: Math.round(vc.vol * 100) + "%"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 13 }
            }
            PillSlider {
                width: 268; showValue: false
                icon: vc.muted || vc.vol <= 0 ? "audio-volume-muted" : vc.vol < 0.34 ? "audio-volume-low" : vc.vol < 0.67 ? "audio-volume-medium" : "audio-volume-high"
                value: vc.vol; dimmed: vc.muted
                onMoved: v => { if (vc.sink?.audio) vc.sink.audio.volume = v }
                onIconClicked: { if (vc.sink?.audio) vc.sink.audio.muted = !vc.muted }
            }
            Text { text: "Salida"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
            Repeater {
                model: vc.sinks
                delegate: Rectangle {
                    id: dr
                    required property var modelData
                    readonly property bool cur: vc.sink && modelData.id === vc.sink.id
                    width: 268; height: 38; radius: 14
                    color: cur ? Theme.accentSoft : dm.containsMouse ? Theme.s3 : Theme.s2
                    Text { anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: dr.modelData.description || dr.modelData.name; elide: Text.ElideRight
                        color: dr.cur ? Theme.accent : Theme.text; font.family: Theme.font; font.pixelSize: 12 }
                    MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: Pipewire.preferredDefaultAudioSink = dr.modelData }
                }
            }
        }
    }

    Component {
        id: clockC
        Column {
            spacing: 10
            Row {
                spacing: 12
                Text { text: Weather.ok ? Weather.glyph : ""; font.family: Theme.mono; font.pixelSize: 46
                    color: Weather.isDay ? Theme.yellow : Theme.accent2; anchors.verticalCenter: parent.verticalCenter }
                Column { anchors.verticalCenter: parent.verticalCenter
                    Text { text: Weather.ok ? Math.round(Weather.temp) + "°C" : "—"; color: Theme.text
                        font.family: Theme.font; font.pixelSize: 28; font.weight: Font.Medium }
                    Text { text: Weather.ok ? Weather.desc : "Sin datos"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 } }
            }
            Text { text: Weather.city; color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
            GridLayout {
                columns: 2; columnSpacing: 20; rowSpacing: 6
                visible: Weather.ok
                Text { text: "Sensación"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
                Text { text: Math.round(Weather.feels) + "°C"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
                Text { text: "Mín / Máx"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
                Text { text: Math.round(Weather.lo) + "° / " + Math.round(Weather.hi) + "°"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
                Text { text: "Humedad"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
                Text { text: Weather.humidity + "%"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
                Text { text: "Viento"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
                Text { text: Math.round(Weather.wind) + " km/h"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
                Text { text: "Lluvia"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
                Text { text: Weather.rain + "%"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
            }
            Text { text: Qt.formatDateTime(new Date(), "dddd d 'de' MMMM"); color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
        }
    }

    Component {
        id: windowC
        Column {
            spacing: 10
            readonly property var tl: Hyprland.activeToplevel
            readonly property string cls: (tl?.lastIpcObject?.class ?? "")
            Row {
                spacing: 12
                Image { width: 36; height: 36; source: Apps.icon(cls)
                    sourceSize: Qt.size(72, 72); smooth: true; anchors.verticalCenter: parent.verticalCenter }
                Column { anchors.verticalCenter: parent.verticalCenter; spacing: 2
                    Text { width: 214; text: tl?.title ?? "Sin ventana"; elide: Text.ElideRight; color: Theme.text
                        font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                    Text { text: cls; color: Theme.dim; font.family: Theme.font; font.pixelSize: 11 } }
            }
            Row {
                spacing: 8
                Repeater {
                    model: [
                        { t: "Cerrar",   g: "", c: Theme.danger, l: 'hl.dsp.window.close()' },
                        { t: "Pantalla",  g: "", c: Theme.accent, l: 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })' },
                        { t: "Flotante",  g: "", c: Theme.accent2, l: 'hl.dsp.window.float({ action = "toggle" })' }
                    ]
                    delegate: Rectangle {
                        id: wb
                        required property var modelData
                        width: 84; height: 52; radius: 16
                        color: wm.containsMouse ? Qt.alpha(modelData.c, 0.22) : Theme.s2
                        Column { anchors.centerIn: parent; spacing: 3
                            Text { text: wb.modelData.g; font.family: Theme.mono; font.pixelSize: 15; color: wb.modelData.c; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: wb.modelData.t; font.family: Theme.font; font.pixelSize: 10; color: Theme.text; anchors.horizontalCenter: parent.horizontalCenter } }
                        MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { pop.shown = false; pop.hypr(wb.modelData.l) } }
                    }
                }
            }
        }
    }

    Component {
        id: statsC
        Column {
            spacing: 10
            function rate(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : b >= 1024 ? Math.round(b / 1024) + " KB/s" : Math.round(b) + " B/s" }
            component Bar: Column {
                property string label; property string val; property real ratio: 0; property color tint: Theme.accent
                spacing: 4; width: 252
                Row { width: parent.width
                    Text { text: parent.parent.label; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12; width: parent.width - vt.implicitWidth }
                    Text { id: vt; text: parent.parent.val; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.features: { "tnum": 1 } } }
                Rectangle { width: parent.width; height: 6; radius: 3; color: Theme.s3
                    Rectangle { width: parent.width * Math.max(0, Math.min(1, parent.parent.ratio)); height: 6; radius: 3; color: parent.parent.tint
                        Behavior on width { NumberAnimation { duration: Theme.dur(300) } } } }
            }
            Text { text: "Sistema"; color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
            Bar { label: "CPU" + (pst.cpuTemp > 0 ? "  " + Math.round(pst.cpuTemp) + " °C" : ""); val: Math.round(pst.cpu * 100) + "%"; ratio: pst.cpu }
            Bar { label: "Memoria"; val: pst.memUsedGb.toFixed(1) + " / " + pst.memTotalGb.toFixed(1) + " GB"; ratio: pst.mem; tint: Theme.green }
            Bar { label: "GPU" + (pst.gpuTemp > 0 ? "  " + Math.round(pst.gpuTemp) + " °C" : ""); val: Math.round(pst.gpu * 100) + "%"; ratio: pst.gpu; tint: Theme.accent2 }
            Bar { label: "VRAM"; val: pst.vramUsedGb.toFixed(1) + " / " + pst.vramTotalGb.toFixed(1) + " GB"; ratio: pst.vram; tint: Theme.accent2 }
            Bar { label: "Disco"; val: Math.round(pst.diskUsedGb) + " / " + Math.round(pst.diskTotalGb) + " GB"; ratio: pst.diskTotalGb > 0 ? pst.diskUsedGb / pst.diskTotalGb : 0; tint: Theme.yellow }
            Row { spacing: 16
                Text { text: "↓ " + rate(pst.netDown); color: Theme.green; font.family: Theme.font; font.pixelSize: 12 }
                Text { text: "↑ " + rate(pst.netUp); color: Theme.accent; font.family: Theme.font; font.pixelSize: 12 } }
        }
    }

    Component {
        id: wsC
        Column {
            spacing: 8
            readonly property var wins: pop.ws ? pop.ws.toplevels.values : []
            Text { text: "Espacio " + (pop.ws ? pop.ws.name : ""); color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
            Text { visible: wins.length === 0; text: "Sin ventanas"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
            Repeater {
                model: wins
                delegate: Rectangle {
                    id: wr
                    required property var modelData
                    readonly property string cls: (modelData.lastIpcObject?.class ?? "")
                    width: 268; height: 40; radius: 14; color: wrm.containsMouse ? Theme.s3 : Theme.s2
                    Row { anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } spacing: 10
                        Image { width: 22; height: 22; source: Apps.icon(wr.cls)
                            sourceSize: Qt.size(44, 44); smooth: true; anchors.verticalCenter: parent.verticalCenter }
                        Text { width: 218; text: wr.modelData.title; elide: Text.ElideRight; color: Theme.text
                            font.family: Theme.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { id: wrm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (pop.ws) pop.ws.activate(); pop.shown = false } }
                }
            }
        }
    }

    // ── Ventana (una por monitor, siempre creada; solo captura el ratón sobre la tarjeta) ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            readonly property bool mine: pop.shown && pop.screenName === modelData.name

            anchors { top: true; bottom: true; left: true }
            implicitWidth: Theme.sidebarW + 340
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            visible: true
            mask: mine ? liveMask : emptyMask
            Region { id: emptyMask }
            Region { id: liveMask; item: card }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "sidebar-popout"

            Item {
                id: card
                x: Theme.sidebarW
                width: 300
                height: (body.item ? body.item.implicitHeight : 0) + 28
                readonly property real top0: Theme.frameW + Theme.frameR + Theme.flare
                y: Math.max(top0, Math.min(win.height - height - top0, pop.anchorY - height / 2))
                visible: opacity > 0.01
                opacity: win.mine ? 1 : 0
                transform: Translate { x: win.mine ? 0 : -24; Behavior on x { Anim { kind: "fastSpatial" } } }
                Behavior on opacity { NumberAnimation { duration: Theme.dur(90) } }
                Behavior on y { enabled: win.mine; NumberAnimation { duration: Theme.dur(120); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard } }

                Fused { edge: "left"; r: 22 }
                HoverHandler { onHoveredChanged: hovered ? pop.enter() : pop.leave() }
                MouseArea { anchors.fill: parent }

                Loader {
                    id: body
                    x: 14; y: 14
                    sourceComponent: pop.kind === "volume" ? volumeC : pop.kind === "clock" ? clockC
                        : pop.kind === "window" ? windowC : pop.kind === "stats" ? statsC
                        : pop.kind === "workspace" ? wsC : null
                }
            }
        }
    }
}
