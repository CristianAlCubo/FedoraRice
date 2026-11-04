import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

// Widgets de escritorio (capa de fondo): visualizador de audio + panel de resumen.
// Se pueden mover: `ipc call widgets edit` (o Super+W), arrastra y pulsa «Listo».
// Posiciones y visibilidad se guardan en ~/.config/hypr/widgets.json.
Scope {
    id: st

    property string screenName: "DP-2"
    property bool editing: false
    property bool vizOn: true
    property bool panelOn: true
    property bool srvOn: true
    property bool mktOn: true
    property var pos: ({})
    property var scales: ({})
    readonly property string file: Quickshell.env("HOME") + "/.config/hypr/widgets.json"

    readonly property bool playing: Mpris.players.values.some(p => p.isPlaying)
    readonly property bool vizActive: vizOn && playing
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    property var target: new Array(40).fill(0)
    property var vals: new Array(40).fill(0)

    IpcHandler {
        target: "widgets"
        function edit(): void { st.editing = !st.editing }
        function toggleViz(): void { st.vizOn = !st.vizOn; st.save() }
        function togglePanel(): void { st.panelOn = !st.panelOn; st.save() }
        function toggleServers(): void { st.srvOn = !st.srvOn; st.save() }
        function toggleMarkets(): void { st.mktOn = !st.mktOn; st.save() }
        function reset(): void { st.pos = {}; st.scales = {}; st.save() }
    }

    function defaults(sw, sh) {
        return { viz: { x: sw - 700, y: sh - 380 }, panel: { x: sw - 400, y: 84 },
                 srv: { x: sw - 400, y: 560 }, mkt: { x: sw - 780, y: 84 } }
    }
    function place(id, sw, sh) {
        const d = defaults(sw, sh)[id], p = pos[id]
        return p ? { x: Math.max(0, Math.min(sw - 100, p.x)), y: Math.max(0, Math.min(sh - 100, p.y)) } : d
    }
    function setPos(id, x, y) {
        const n = Object.assign({}, pos); n[id] = { x: Math.round(x), y: Math.round(y) }
        pos = n; save()
    }
    function setScale(id, v) {
        const n = Object.assign({}, scales); n[id] = Math.round(Math.max(0.6, Math.min(1.8, v)) * 20) / 20
        scales = n
    }
    function save() {
        store.setText(JSON.stringify({ vizOn: vizOn, panelOn: panelOn, srvOn: srvOn, mktOn: mktOn, pos: pos, scales: scales }, null, 1))
    }

    FileView {
        id: store
        path: st.file
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text())
                st.vizOn = d.vizOn !== false; st.panelOn = d.panelOn !== false
                st.srvOn = d.srvOn !== false; st.mktOn = d.mktOn !== false
                st.pos = d.pos || {}; st.scales = d.scales || {}
            } catch (e) {}
        }
    }

    Process {
        running: st.vizActive
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/cava/quickshell.conf"]
        stdout: SplitParser {
            onRead: line => {
                const p = line.split(";")
                if (p.length < 40) return
                const t = new Array(40)
                for (let i = 0; i < 40; i++) t[i] = Math.min(1, (parseInt(p[i]) || 0) / 100)
                st.target = t
            }
        }
    }

    // ── Servidores (hosts de ~/.ssh/config) ─────────────────
    property var servers: []
    Process {
        id: srvProc
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/servers.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = []
                for (const line of text.split("\n")) {
                    const p = line.split("|")
                    if (p.length >= 6) l.push({ alias: p[1], host: p[2], user: p[3], up: p[4] === "up", ms: parseInt(p[5]) })
                }
                st.servers = l
            }
        }
    }
    Timer { interval: 60000; repeat: true; running: st.srvOn; triggeredOnStart: true; onTriggered: srvProc.running = true }
    Process { id: launch }
    function term(args) { launch.command = ["kitty"].concat(args); launch.running = true }

    // ── Mercados: dólar (COP) y bitcoin (USD) ───────────────
    property var usd: ({ price: 0, change: 0, hist: [] })
    property var btc: ({ price: 0, change: 0, hist: [] })
    Process {
        id: usdProc
        command: ["curl", "-s", "-m", "12", "https://www.datos.gov.co/resource/32sa-8pi3.json?$order=vigenciadesde%20DESC&$limit=20"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text).map(x => parseFloat(x.valor)).reverse()
                    st.usd = { price: s[s.length - 1], change: s[s.length - 1] / s[s.length - 2] - 1, hist: s }
                } catch (e) {}
            }
        }
    }
    Process {
        id: btcProc
        command: ["curl", "-s", "-m", "12", "https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const all = JSON.parse(text).prices.map(x => x[1])
                    const step = Math.max(1, Math.floor(all.length / 36))
                    const h = all.filter((_, i) => i % step === 0)
                    st.btc = { price: all[all.length - 1], change: all[all.length - 1] / all[0] - 1, hist: h }
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 300000; repeat: true; running: st.mktOn; triggeredOnStart: true
        onTriggered: { usdProc.running = true; btcProc.running = true }
    }

    Stats { id: wStats; active: st.panelOn }
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Variants {
        model: Quickshell.screens.filter(s => s.name === st.screenName)

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: st.editing ? WlrLayer.Overlay : WlrLayer.Bottom
            WlrLayershell.namespace: "widgets"
            WlrLayershell.keyboardFocus: st.editing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            mask: st.editing ? fullMask : liveMask
            Region {
                id: liveMask
                Region { item: srvHit }
            }
            Region { id: fullMask; item: root }

            Item {
                id: root
                anchors.fill: parent
                focus: st.editing
                Keys.onEscapePressed: st.editing = false

                Item { id: srvHit; x: srvBox.x; y: srvBox.y; width: srvBox.width * srvBox.sc; height: srvBox.height * srvBox.sc }

                // Icono pequeño dibujado a mano
                component MiniIcon: Canvas {
                    id: mi
                    property string kind
                    property color color: Theme.dim
                    width: 14; height: 14
                    onKindChanged: requestPaint()
                    onColorChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d"); c.reset()
                        c.strokeStyle = color; c.fillStyle = color
                        c.lineWidth = 1.5; c.lineCap = "round"; c.lineJoin = "round"
                        if (kind === "cpu") {
                            c.strokeRect(3.5, 3.5, 7, 7)
                            c.beginPath()
                            for (const v of [5.5, 8.5]) {
                                c.moveTo(v, 0.8); c.lineTo(v, 3.5); c.moveTo(v, 10.5); c.lineTo(v, 13.2)
                                c.moveTo(0.8, v); c.lineTo(3.5, v); c.moveTo(10.5, v); c.lineTo(13.2, v)
                            }
                            c.stroke()
                        } else if (kind === "ram") {
                            c.strokeRect(1, 3.5, 12, 7)
                            for (const x of [3.2, 6.2, 9.2]) c.fillRect(x, 5.8, 1.6, 2.6)
                        } else if (kind === "gpu") {
                            c.strokeRect(1, 2.5, 12, 9)
                            c.beginPath(); c.arc(7, 7, 2.4, 0, Math.PI * 2); c.stroke()
                        } else if (kind === "disk") {
                            c.strokeRect(1.5, 3, 11, 8)
                            c.beginPath(); c.moveTo(1.5, 8); c.lineTo(12.5, 8); c.stroke()
                            c.beginPath(); c.arc(10, 9.6, 0.7, 0, Math.PI * 2); c.fill()
                        } else if (kind === "server") {
                            c.strokeRect(1.5, 1.5, 11, 4.5); c.strokeRect(1.5, 8, 11, 4.5)
                            c.beginPath(); c.arc(4, 3.75, 0.8, 0, Math.PI * 2); c.fill()
                            c.beginPath(); c.arc(4, 10.25, 0.8, 0, Math.PI * 2); c.fill()
                        } else if (kind === "terminal") {
                            c.beginPath(); c.moveTo(2.5, 3.5); c.lineTo(6, 7); c.lineTo(2.5, 10.5)
                            c.moveTo(7.5, 11); c.lineTo(11.5, 11); c.stroke()
                        } else if (kind === "net") {
                            c.beginPath(); c.moveTo(4.5, 12); c.lineTo(4.5, 2); c.moveTo(2, 4.5); c.lineTo(4.5, 2); c.lineTo(7, 4.5)
                            c.moveTo(9.5, 2); c.lineTo(9.5, 12); c.moveTo(7, 9.5); c.lineTo(9.5, 12); c.lineTo(12, 9.5); c.stroke()
                        }
                    }
                }

                // Caja movible
                component Box: Item {
                    id: bx
                    property string wid
                    property bool on: true
                    visible: on || st.editing
                    opacity: on ? 1 : 0.35
                    property real sc: st.scales[wid] ?? 1
                    scale: sc
                    transformOrigin: Item.TopLeft
                    // Posición declarativa: se recalcula al cargar el archivo o al conocerse el tamaño de la pantalla
                    readonly property point home: st.place(wid, root.width, root.height)
                    Binding { target: bx; property: "x"; value: bx.home.x; when: !drag.drag.active }
                    Binding { target: bx; property: "y"; value: bx.home.y; when: !drag.drag.active }

                    Rectangle {
                        anchors { fill: parent; margins: -6 }
                        visible: st.editing
                        radius: 24
                        color: Qt.alpha(Theme.accent, drag.drag.active ? 0.10 : 0.04)
                        border.width: 2
                        border.color: Theme.accentLine
                    }
                    MouseArea {
                        id: drag
                        anchors.fill: parent
                        z: 10
                        enabled: st.editing
                        cursorShape: st.editing ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
                        drag.target: bx
                        drag.minimumX: 0; drag.maximumX: root.width - bx.width * bx.sc
                        drag.minimumY: 0; drag.maximumY: root.height - bx.height * bx.sc
                        onReleased: st.setPos(bx.wid, bx.x, bx.y)
                        onWheel: wheel => { st.setScale(bx.wid, bx.sc + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)); st.save() }
                    }
                    Rectangle {   // tirador de tamaño
                        visible: st.editing
                        x: bx.width - 14; y: bx.height - 14
                        width: 26; height: 26; radius: 13
                        z: 20
                        color: hm.pressed || hm.containsMouse ? Theme.accent : Theme.bg
                        border.width: 2; border.color: Theme.accent
                        Canvas {
                            anchors.centerIn: parent; width: 12; height: 12
                            property bool hot: hm.pressed || hm.containsMouse
                            onHotChanged: requestPaint()
                            onPaint: {
                                const c = getContext("2d"); c.reset()
                                c.strokeStyle = hot ? Theme.ink : Theme.accent; c.lineWidth = 1.8; c.lineCap = "round"
                                c.beginPath(); c.moveTo(2, 10); c.lineTo(10, 2); c.moveTo(6, 10); c.lineTo(10, 6); c.stroke()
                            }
                        }
                        MouseArea {
                            id: hm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.SizeFDiagCursor
                            onPositionChanged: mouse => {
                                if (!pressed) return
                                const p = mapToItem(root, mouse.x, mouse.y)
                                st.setScale(bx.wid, (p.x - bx.x) / bx.width)
                            }
                            onReleased: st.save()
                        }
                    }
                }

                // ── Visualizador ────────────────────────────
                Box {
                    id: vizBox
                    wid: "viz"; on: st.vizOn
                    width: 620; height: 300

                    Item {
                        anchors.fill: parent
                        opacity: st.vizActive || st.editing ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.dur(700) } }

                        Canvas {
                            id: cv
                            anchors.fill: parent
                            renderTarget: Canvas.FramebufferObject
                            property real t: 0
                            property real bass: 0

                            Timer {
                                interval: 16; repeat: true
                                running: st.vizOn && (st.vizActive || cv.parent.opacity > 0.01)
                                onTriggered: {
                                    const v = st.vals, g = st.target
                                    for (let i = 0; i < 40; i++) v[i] += (g[i] - v[i]) * 0.35
                                    let b = 0
                                    for (let i = 0; i < 5; i++) b += v[i]
                                    cv.bass += (b / 5 - cv.bass) * 0.25
                                    cv.t += 0.016
                                    cv.requestPaint()
                                }
                            }

                            property var peaks: new Array(40).fill(0)

                            function rr(c, x, y, w, h, r) {
                                r = Math.min(r, w / 2, h / 2)
                                c.moveTo(x + r, y); c.lineTo(x + w - r, y); c.arc(x + w - r, y + r, r, -Math.PI / 2, 0)
                                c.lineTo(x + w, y + h - r); c.arc(x + w - r, y + h - r, r, 0, Math.PI / 2)
                                c.lineTo(x + r, y + h); c.arc(x + r, y + h - r, r, Math.PI / 2, Math.PI)
                                c.lineTo(x, y + r); c.arc(x + r, y + r, r, Math.PI, Math.PI * 1.5); c.closePath()
                            }

                            onPaint: {
                                const c = getContext("2d")
                                const W = width, H = height
                                c.globalCompositeOperation = "source-over"
                                c.clearRect(0, 0, W, H)
                                const v = st.vals, N = 40
                                const gap = 5, bw = (W - gap * (N - 1)) / N
                                const base = H * 0.68, maxH = H * 0.62
                                const hue0 = (t * 14) % 360
                                for (let i = 0; i < N; i++) {
                                    const x = i * (bw + gap)
                                    const h = 4 + v[i] * maxH
                                    const hue = Math.round(185 + i / N * 115 + Math.sin(t * 0.6) * 18)
                                    if (v[i] > peaks[i]) peaks[i] = v[i]; else peaks[i] = Math.max(0, peaks[i] - 0.006)
                                    // barra
                                    const g = c.createLinearGradient(0, base - h, 0, base)
                                    g.addColorStop(0, "hsla(" + hue + ",100%,70%,1)")
                                    g.addColorStop(1, "hsla(" + hue + ",100%,48%,0.85)")
                                    c.fillStyle = g
                                    c.beginPath(); rr(c, x, base - h, bw, h, bw / 2); c.fill()
                                    // reflejo
                                    const rg = c.createLinearGradient(0, base + 4, 0, base + 4 + h * 0.45)
                                    rg.addColorStop(0, "hsla(" + hue + ",100%,60%,0.28)")
                                    rg.addColorStop(1, "hsla(" + hue + ",100%,60%,0)")
                                    c.fillStyle = rg
                                    c.beginPath(); rr(c, x, base + 4, bw, h * 0.45, bw / 2); c.fill()
                                    // pico que cae
                                    const py = base - 4 - peaks[i] * maxH - 8
                                    c.fillStyle = "hsla(" + hue + ",100%,85%,0.9)"
                                    c.beginPath(); rr(c, x, py, bw, 3, 1.5); c.fill()
                                }
                            }
                        }
                    }
                }

                // ── Panel de resumen ────────────────────────
                Box {
                    id: panelBox
                    wid: "panel"; on: st.panelOn
                    width: 340; height: col.implicitHeight + 40

                    Rectangle {
                        anchors.fill: parent
                        radius: 28
                        color: Qt.alpha(Theme.base, 0.72)
                        border.width: 1
                        border.color: Theme.stroke
                    }

                    ColumnLayout {
                        id: col
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 22; topMargin: 20 }
                        spacing: 14

                        // Reloj
                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: Qt.formatDateTime(clock.date, "HH:mm")
                                color: Theme.text
                                font.family: Theme.font; font.pixelSize: 56; font.weight: Font.Light
                                font.features: { "tnum": 1 }
                            }
                            Text {
                                text: {
                                    const s = Qt.locale().toString(clock.date, "dddd, d 'de' MMMM")
                                    return s.charAt(0).toUpperCase() + s.slice(1)
                                }
                                color: Theme.dim
                                font.family: Theme.font; font.pixelSize: 14
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.stroke }

                        // Métricas
                        component Meter: ColumnLayout {
                            property string label
                            property string kind
                            property real value: 0
                            property string text
                            Layout.fillWidth: true
                            spacing: 5
                            RowLayout {
                                Layout.fillWidth: true
                                MiniIcon { kind: parent.parent.kind; color: Theme.accent; Layout.rightMargin: 4 }
                                Text { text: parent.parent.label; color: Theme.dim
                                    font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium }
                                Item { Layout.fillWidth: true }
                                Text { text: parent.parent.text; color: Theme.text
                                    font.family: Theme.font; font.pixelSize: 12; font.features: { "tnum": 1 } }
                            }
                            Rectangle {
                                Layout.fillWidth: true; height: 5; radius: 2.5
                                color: Theme.fade(0.08)
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, parent.parent.value))
                                    height: parent.height; radius: 2.5
                                    color: parent.parent.value > 0.85 ? Theme.danger : Theme.accent
                                    Behavior on width { NumberAnimation { duration: Theme.dur(400); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard } }
                                }
                            }
                        }
                        Meter { label: "CPU"; kind: "cpu"; value: wStats.cpu / 100
                                text: Math.round(wStats.cpu) + "%  ·  " + Math.round(wStats.cpuTemp) + "°" }
                        Meter { label: "RAM"; kind: "ram"; value: wStats.mem / 100
                                text: wStats.memUsedGb.toFixed(1) + " / " + wStats.memTotalGb.toFixed(0) + " GB" }
                        Meter { label: "GPU"; kind: "gpu"; value: wStats.gpu / 100
                                text: Math.round(wStats.gpu) + "%  ·  " + Math.round(wStats.gpuTemp) + "°" }
                        Meter { label: "Disco"; kind: "disk"; value: wStats.diskTotalGb > 0 ? wStats.diskUsedGb / wStats.diskTotalGb : 0
                                text: Math.round(wStats.diskUsedGb) + " / " + Math.round(wStats.diskTotalGb) + " GB" }

                        RowLayout {
                            Layout.fillWidth: true
                            function rate(b) { return b > 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : Math.round(b / 1024) + " KB/s" }
                            MiniIcon { kind: "net"; color: Theme.accent; Layout.rightMargin: 6 }
                            Text { text: "↓ " + parent.rate(wStats.netDown); color: Theme.accent
                                font.family: Theme.font; font.pixelSize: 12; font.features: { "tnum": 1 } }
                            Item { Layout.fillWidth: true }
                            Text { text: "↑ " + parent.rate(wStats.netUp); color: Theme.dim
                                font.family: Theme.font; font.pixelSize: 12; font.features: { "tnum": 1 } }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.stroke }

                        // Sonando
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: st.player && st.player.isPlaying ? "SONANDO" : "EN PAUSA"
                                color: st.player && st.player.isPlaying ? Theme.accent : Theme.dim
                                font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold
                                font.letterSpacing: 1.5
                                visible: st.player !== null
                            }
                            Text {
                                Layout.fillWidth: true
                                text: st.player ? (st.player.trackTitle || "—") : "Nada reproduciéndose"
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Medium
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: st.player !== null
                                text: st.player ? (st.player.trackArtist || "") : ""
                                elide: Text.ElideRight
                                color: Theme.dim
                                font.family: Theme.font; font.pixelSize: 12
                            }
                        }
                    }
                }


                // ── Servidores ──────────────────────────────
                Box {
                    id: srvBox
                    wid: "srv"; on: st.srvOn
                    width: 340; height: srvCol.implicitHeight + 36

                    Rectangle {
                        anchors.fill: parent; radius: 28
                        color: Qt.alpha(Theme.base, 0.72)
                        border.width: 1; border.color: Theme.stroke
                    }
                    ColumnLayout {
                        id: srvCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18; topMargin: 16 }
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            MiniIcon { kind: "server"; color: Theme.accent; Layout.rightMargin: 6 }
                            Text {
                                text: "SERVIDORES"
                                color: Theme.dim
                                font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold
                                font.letterSpacing: 1.5
                            }
                            Text {
                                text: st.servers.filter(s => s.up).length + "/" + st.servers.length
                                color: st.servers.length > 0 && st.servers.every(s => s.up) ? Theme.accent : Theme.danger
                                font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Medium
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 28; width: lz.implicitWidth + 40; radius: 14
                                color: lzm.containsMouse ? Theme.accent : Theme.accentSoft
                                border.width: 1; border.color: Theme.accentLine
                                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                                MiniIcon { kind: "terminal"; x: 10; anchors.verticalCenter: parent.verticalCenter
                                           color: lzm.containsMouse ? Theme.ink : Theme.accent }
                                Text {
                                    id: lz
                                    anchors { verticalCenter: parent.verticalCenter; horizontalCenterOffset: 8; horizontalCenter: parent.horizontalCenter }
                                    text: "lazyssh"
                                    color: lzm.containsMouse ? Theme.ink : Theme.accent
                                    font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium
                                }
                                MouseArea { id: lzm; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor; onClicked: st.term(["lazyssh"]) }
                            }
                        }

                        Repeater {
                            model: st.servers
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 46; radius: 16
                                color: rm.containsMouse ? Theme.bgHover : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
                                    spacing: 10
                                    Rectangle {
                                        implicitWidth: 9; implicitHeight: 9; radius: 4.5
                                        color: modelData.up ? Theme.green : Theme.danger
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 17; height: 17; radius: 8.5
                                            color: parent.color; opacity: 0.18
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.alias
                                            elide: Text.ElideRight
                                            color: Theme.text
                                            font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: (modelData.user ? modelData.user + "@" : "") + modelData.host
                                            elide: Text.ElideRight
                                            color: Theme.dim
                                            font.family: Theme.font; font.pixelSize: 11
                                        }
                                    }
                                    Text {
                                        text: modelData.up ? modelData.ms + " ms" : "sin respuesta"
                                        color: modelData.up ? Theme.dim : Theme.danger
                                        font.family: Theme.font; font.pixelSize: 11; font.features: { "tnum": 1 }
                                    }
                                }
                                MouseArea {
                                    id: rm
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: st.term(["ssh", modelData.alias])
                                }
                            }
                        }
                        Text {
                            visible: st.servers.length === 0
                            Layout.leftMargin: 4
                            text: "Comprobando…"
                            color: Theme.dim
                            font.family: Theme.font; font.pixelSize: 12
                        }
                    }
                }

                // ── Mercados ────────────────────────────────
                Box {
                    id: mktBox
                    wid: "mkt"; on: st.mktOn
                    width: 340; height: 232

                    Rectangle {
                        anchors.fill: parent; radius: 28
                        color: Qt.alpha(Theme.base, 0.72)
                        border.width: 1; border.color: Theme.stroke
                    }

                    component Quote: Item {
                        id: q
                        property string label
                        property string prefix
                        property var info
                        property int decimals: 0
                        property string badge
                        readonly property bool upTrend: info.change >= 0
                        readonly property color tint: upTrend ? Theme.green : Theme.danger

                        function fmt(v) {
                            const s = v.toFixed(decimals)
                            const parts = s.split(".")
                            parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ".")
                            return parts.join(",")
                        }

                        Rectangle {
                            x: 0; y: 6; width: 34; height: 34; radius: 17
                            color: Qt.alpha(q.tint, 0.14)
                            border.width: 1; border.color: Qt.alpha(q.tint, 0.4)
                            Text { anchors.centerIn: parent; text: q.badge; color: q.tint
                                font.family: Theme.font; font.pixelSize: 17; font.weight: Font.DemiBold }
                        }
                        Column {
                            anchors { left: parent.left; leftMargin: 46; top: parent.top }
                            spacing: 1
                            Text {
                                text: q.label
                                color: Theme.dim
                                font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold
                                font.letterSpacing: 1.5
                            }
                            Text {
                                text: q.info.price > 0 ? q.prefix + q.fmt(q.info.price) : "—"
                                color: Theme.text
                                font.family: Theme.font; font.pixelSize: 26; font.weight: Font.Light
                                font.features: { "tnum": 1 }
                            }
                            Text {
                                visible: q.info.price > 0
                                text: (q.upTrend ? "▲ " : "▼ ") + Math.abs(q.info.change * 100).toFixed(2) + "%"
                                color: q.tint
                                font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium
                            }
                        }
                        Canvas {
                            id: spark
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 96; height: 46
                            property var pts: q.info.hist
                            onPtsChanged: requestPaint()
                            onPaint: {
                                const c = getContext("2d"); c.reset()
                                const h = pts
                                if (!h || h.length < 2) return
                                let mn = Math.min.apply(null, h), mx = Math.max.apply(null, h)
                                if (mx === mn) { mx += 1; mn -= 1 }
                                const X = i => i / (h.length - 1) * (width - 4) + 2
                                const Y = v => height - 4 - (v - mn) / (mx - mn) * (height - 8)
                                const col = q.upTrend ? "77,255,159" : "255,107,122"
                                const g = c.createLinearGradient(0, 0, 0, height)
                                g.addColorStop(0, "rgba(" + col + ",0.28)"); g.addColorStop(1, "rgba(" + col + ",0)")
                                c.beginPath(); c.moveTo(X(0), height)
                                for (let i = 0; i < h.length; i++) c.lineTo(X(i), Y(h[i]))
                                c.lineTo(X(h.length - 1), height); c.closePath(); c.fillStyle = g; c.fill()
                                c.beginPath()
                                for (let i = 0; i < h.length; i++) i === 0 ? c.moveTo(X(i), Y(h[i])) : c.lineTo(X(i), Y(h[i]))
                                c.strokeStyle = "rgb(" + col + ")"; c.lineWidth = 2; c.lineJoin = "round"; c.stroke()
                            }
                        }
                    }

                    ColumnLayout {
                        anchors { fill: parent; margins: 22 }
                        spacing: 14
                        Quote { Layout.fillWidth: true; Layout.preferredHeight: 76
                                badge: "$"; label: "DÓLAR · COP"; prefix: "$ "; info: st.usd; decimals: 2 }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.stroke }
                        Quote { Layout.fillWidth: true; Layout.preferredHeight: 76
                                badge: "₿"; label: "BITCOIN · USD"; prefix: "$ "; info: st.btc }
                    }
                }

                // ── Barra del modo edición ──────────────────
                Rectangle {
                    visible: st.editing
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 70 }
                    height: 52; radius: 26
                    width: bar.implicitWidth + 24
                    color: Theme.bg
                    border.width: 1; border.color: Theme.accentLine

                    component Chip: Rectangle {
                        id: chip
                        property string label
                        property bool active: false
                        property bool primary: false
                        signal clicked()
                        implicitHeight: 36; implicitWidth: lt.implicitWidth + 28; radius: 18
                        color: primary ? Theme.accent : active ? Theme.accentSoft : (cm.containsMouse ? Theme.bgHover : Theme.bgSoft)
                        border.width: active && !primary ? 1 : 0
                        border.color: Theme.accentLine
                        Text {
                            id: lt
                            anchors.centerIn: parent
                            text: chip.label
                            color: chip.primary ? Theme.ink : chip.active ? Theme.accent : Theme.text
                            font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium
                        }
                        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
                    }

                    Row {
                        id: bar
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Arrastra · esquina o rueda para el tamaño"
                            color: Theme.dim
                            font.family: Theme.font; font.pixelSize: 13
                            rightPadding: 6
                        }
                        Chip { label: "Visualizador"; active: st.vizOn; onClicked: { st.vizOn = !st.vizOn; st.save() } }
                        Chip { label: "Panel"; active: st.panelOn; onClicked: { st.panelOn = !st.panelOn; st.save() } }
                        Chip { label: "Servidores"; active: st.srvOn; onClicked: { st.srvOn = !st.srvOn; st.save() } }
                        Chip { label: "Mercados"; active: st.mktOn; onClicked: { st.mktOn = !st.mktOn; st.save() } }
                        Chip { label: "Restablecer"; onClicked: { st.pos = {}; st.scales = {}; st.save() } }
                        Chip { label: "Listo"; primary: true; onClicked: st.editing = false }
                    }
                }
            }
        }
    }
}
