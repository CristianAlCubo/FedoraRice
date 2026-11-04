import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// Panel de Ajustes → Fondos. Elige una imagen y aplícala al escritorio, al bloqueo y al login.
// Se abre con $mod+I o `qs -p ~/.config/quickshell/bar ipc call settings toggle`.
// La lógica de verdad está en ~/.config/hypr/scripts/wallpaper.sh.
Scope {
    id: st

    property bool open: false
    readonly property string home: Quickshell.env("HOME")
    readonly property string script: home + "/.config/hypr/scripts/wallpaper.sh"

    property var cfg: ({})              // estado actual (DESKTOP, LOCK, LOGIN...)
    property int sel: 0
    property bool tDesktop: true
    property bool tLock: true
    property bool tLogin: false
    property real shiftPct: 0
    property string status: ""
    property bool statusErr: false
    property bool busy: false
    property bool loading: false
    property bool importing: false
    property string pendingSelect: ""

    ListModel { id: wallModel }
    ListModel { id: recentModel }

    readonly property var cur: (sel >= 0 && sel < wallModel.count) ? wallModel.get(sel) : null
    readonly property bool isImage: cur !== null && cur.kind === "image"
    readonly property bool canApply: cur !== null && !busy &&
        (tDesktop || (isImage && (tLock || tLogin)))

    IpcHandler {
        target: "settings"
        function toggle(): void { st.open = !st.open }
        function hide(): void   { st.open = false }
    }

    onOpenChanged: {
        if (open) {
            status = ""; importing = false; loading = true
            statusProc.running = true
        }
    }

    function move(d) {
        if (wallModel.count === 0) return
        sel = Math.max(0, Math.min(wallModel.count - 1, sel + d))
    }

    function apply() {
        if (!canApply) return
        const q = n => "'" + String(n).replace(/'/g, "") + "'"
        const cmds = []
        if (tDesktop) cmds.push(q(script) + " set-desktop " + cur.kind + " " + q(cur.name))
        if (isImage && tLock) cmds.push(q(script) + " set-lock " + q(cur.name) + " " + Math.round(shiftPct))
        if (isImage && tLogin) cmds.push(q(script) + " set-login " + q(cur.name))
        busy = true
        status = tLogin && isImage ? "Aplicando… (el login pedirá tu contraseña)" : "Aplicando…"
        statusErr = false
        applyProc.command = ["sh", "-c", cmds.join("; ")]
        applyProc.running = true
    }

    // ── Procesos ────────────────────────────────────────────
    Process {
        id: statusProc
        command: [st.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const c = {}
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0) c[line.slice(0, i)] = line.slice(i + 1)
                }
                st.cfg = c
                if (st.open) st.shiftPct = parseFloat(c.LOCK_SHIFT || "0") || 0
                listProc.running = true
            }
        }
    }
    Process {
        id: listProc
        command: [st.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const keep = st.pendingSelect !== "" ? st.pendingSelect
                           : (st.cur ? st.cur.name : (st.cfg.DESKTOP || ""))
                wallModel.clear()
                for (const line of text.split("\n")) {
                    const p = line.split("|")
                    if (p.length === 3) wallModel.append({ kind: p[0], name: p[1], thumb: p[2] })
                }
                let idx = 0
                for (let i = 0; i < wallModel.count; i++)
                    if (wallModel.get(i).name === keep) { idx = i; break }
                st.sel = idx
                st.pendingSelect = ""
                st.loading = false
            }
        }
    }
    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: {
                st.busy = false
                const lines = text.split("\n").filter(l => l.length > 0)
                const errs = lines.filter(l => l.startsWith("ERR")).map(l => l.slice(4))
                const oks = lines.filter(l => l.startsWith("OK")).map(l => l.slice(3))
                if (errs.length > 0) {
                    st.status = errs.join(" · "); st.statusErr = true
                } else {
                    st.status = oks.length > 0 ? "Aplicado: " + oks.join(", ") : "Nada que aplicar"
                    st.statusErr = false
                }
                statusProc.running = true
            }
        }
    }
    Process {
        id: recentProc
        command: ["sh", "-c",
            "ls -t \"$HOME\"/Descargas/*.png \"$HOME\"/Descargas/*.jpg \"$HOME\"/Descargas/*.jpeg " +
            "\"$HOME\"/Descargas/*.webp \"$HOME\"/Descargas/*.PNG \"$HOME\"/Descargas/*.JPG 2>/dev/null | head -14"]
        stdout: StdioCollector {
            onStreamFinished: {
                recentModel.clear()
                for (const line of text.split("\n"))
                    if (line.length > 0) recentModel.append({ path: line })
            }
        }
    }
    Process {
        id: importProc
        stdout: StdioCollector {
            onStreamFinished: {
                st.busy = false
                const l = text.split("\n").filter(x => x.length > 0)
                const ok = l.find(x => x.startsWith("NAME "))
                const er = l.find(x => x.startsWith("ERR"))
                if (ok) {
                    st.pendingSelect = ok.slice(5)
                    st.importing = false
                    st.status = "Importado como «" + ok.slice(5) + "»"; st.statusErr = false
                    statusProc.running = true
                } else {
                    st.status = er ? er.slice(4) : "No se pudo importar"; st.statusErr = true
                }
            }
        }
    }

    // ── Ventana ─────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            visible: st.open && Hyprland.focusedMonitor?.name === modelData.name

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onVisibleChanged: if (visible) keys.forceActiveFocus()

            Rectangle {
                anchors.fill: parent
                color: Theme.scrim(0.42)
                opacity: win.visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.dur(200) } }
            }
            MouseArea { anchors.fill: parent; onClicked: st.open = false }

            FocusScope {
                id: keys
                anchors.fill: parent
                Keys.onPressed: ev => {
                    const k = ev.key
                    ev.accepted = true
                    if (k === Qt.Key_Escape) {
                        if (st.importing) st.importing = false
                        else st.open = false
                    } else if (st.importing) {
                        ev.accepted = false
                    } else if (k === Qt.Key_Left) st.move(-1)
                    else if (k === Qt.Key_Right) st.move(1)
                    else if (k === Qt.Key_Up) st.move(-3)
                    else if (k === Qt.Key_Down) st.move(3)
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) st.apply()
                    else if (k === Qt.Key_1) st.tDesktop = !st.tDesktop
                    else if (k === Qt.Key_2) st.tLock = !st.tLock
                    else if (k === Qt.Key_3) st.tLogin = !st.tLogin
                    else ev.accepted = false
                    if (ev.accepted && !st.importing) grid.positionViewAtIndex(st.sel, GridView.Contain)
                }
            }

            Rectangle {
                id: card
                width: 1080
                height: 668
                anchors.centerIn: parent
                radius: 30
                color: Theme.bg
                border.width: 1
                border.color: Theme.stroke
                opacity: win.visible ? 1 : 0
                scale: win.visible ? 1 : 0.97
                Behavior on opacity { NumberAnimation { duration: Theme.dur(180) } }
                Behavior on scale { NumberAnimation { duration: Theme.dur(240); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard } }

                MouseArea { anchors.fill: parent }

                // Fila de destino (Escritorio / Bloqueo / Login)
                component TargetRow: Rectangle {
                    id: tr
                    property string label
                    property string sub
                    property bool checked: false
                    property bool allowed: true
                    property string key
                    signal toggled()

                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: 18
                    opacity: allowed ? 1 : 0.38
                    color: checked && allowed ? Theme.accentSoft : (trm.containsMouse && allowed ? Theme.bgHover : Theme.bgSoft)
                    border.width: 1
                    border.color: checked && allowed ? Theme.accentLine : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        spacing: 12
                        Rectangle {
                            implicitWidth: 22; implicitHeight: 22; radius: 11
                            color: tr.checked && tr.allowed ? Theme.accent : "transparent"
                            border.width: 2
                            border.color: tr.checked && tr.allowed ? Theme.accent : Theme.fade(0.25)
                            Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                            Canvas {
                                anchors.centerIn: parent
                                width: 12; height: 12
                                visible: tr.checked && tr.allowed
                                onVisibleChanged: requestPaint()
                                onPaint: {
                                    const c = getContext("2d"); c.reset()
                                    c.strokeStyle = Theme.ink; c.lineWidth = 2.2
                                    c.lineCap = "round"; c.lineJoin = "round"
                                    c.beginPath(); c.moveTo(2, 6.5); c.lineTo(5, 9.5); c.lineTo(10, 3); c.stroke()
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: tr.label
                                color: tr.checked && tr.allowed ? Theme.accent : Theme.text
                                font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Medium
                            }
                            Text {
                                text: tr.sub
                                color: Theme.dim
                                font.family: Theme.font; font.pixelSize: 11
                            }
                        }
                        Rectangle {
                            implicitWidth: 22; implicitHeight: 22; radius: 7
                            color: Theme.s2
                            Text {
                                anchors.centerIn: parent
                                text: tr.key
                                color: Theme.dim
                                font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Medium
                            }
                        }
                    }
                    MouseArea {
                        id: trm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: tr.allowed ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (tr.allowed) tr.toggled()
                    }
                }

                // ── Cabecera ────────────────────────────────
                Item {
                    id: header
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 72

                    Column {
                        anchors { left: parent.left; leftMargin: 28; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        Text {
                            text: "Fondos"
                            color: Theme.text
                            font.family: Theme.font; font.pixelSize: 22; font.weight: Font.DemiBold
                        }
                        Text {
                            text: "Elige una imagen y dónde usarla"
                            color: Theme.dim
                            font.family: Theme.font; font.pixelSize: 13
                        }
                    }

                    Row {
                        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 8

                        Rectangle {
                            height: 40; width: impRow.implicitWidth + 32; radius: 20
                            color: st.importing ? Theme.accent : (impM.containsMouse ? Theme.bgHover : Theme.bgSoft)
                            Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                            Row {
                                id: impRow
                                anchors.centerIn: parent
                                spacing: 8
                                Canvas {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14; height: 14
                                    property color col: st.importing ? Theme.ink : Theme.text
                                    onColChanged: requestPaint()
                                    onPaint: {
                                        const c = getContext("2d"); c.reset()
                                        c.strokeStyle = col; c.lineWidth = 2; c.lineCap = "round"
                                        c.beginPath(); c.moveTo(7, 2); c.lineTo(7, 12); c.moveTo(2, 7); c.lineTo(12, 7); c.stroke()
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Importar"
                                    color: st.importing ? Theme.ink : Theme.text
                                    font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium
                                }
                            }
                            MouseArea {
                                id: impM; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { st.importing = !st.importing; if (st.importing) recentProc.running = true }
                            }
                        }

                        Rectangle {
                            width: 40; height: 40; radius: 20
                            color: clM.containsMouse ? Theme.bgHover : Theme.bgSoft
                            Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                            Icon { anchors.centerIn: parent; name: "window-close"; size: 15
                                   color: clM.containsMouse ? Theme.text : Theme.dim }
                            MouseArea { id: clM; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: st.open = false }
                        }
                    }
                }

                // ── Cuerpo ──────────────────────────────────
                Item {
                    id: body
                    anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom
                              leftMargin: 20; rightMargin: 20; bottomMargin: 20 }

                    // Cuadrícula de fondos
                    GridView {
                        id: grid
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: parent.width - 356
                        cellWidth: Math.floor(width / 3)
                        cellHeight: 156
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: wallModel
                        currentIndex: st.sel

                        delegate: Item {
                            id: cell
                            required property int index
                            required property string kind
                            required property string name
                            required property string thumb
                            width: grid.cellWidth
                            height: grid.cellHeight

                            readonly property bool selected: st.sel === index
                            readonly property bool onDesk: st.cfg.DESKTOP === name && st.cfg.DESKTOP_KIND === kind
                            readonly property bool onLock: kind === "image" && st.cfg.LOCK === name
                            readonly property bool onLogin: kind === "image" && st.cfg.LOGIN === name

                            Item {
                                id: tile
                                anchors { fill: parent; margins: 6 }
                                scale: cellM.containsMouse && !cell.selected ? 1.02 : 1
                                Behavior on scale { NumberAnimation { duration: Theme.dur(140); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard } }

                                RoundClip {
                                    id: thumbClip
                                    width: parent.width
                                    height: Math.round(width * 9 / 16)
                                    radius: 14
                                    Rectangle { anchors.fill: parent; color: Theme.bgSoft }
                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + cell.thumb
                                        sourceSize: Qt.size(480, 270)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                    // Etiquetas de dónde se usa
                                    Row {
                                        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 7; bottomMargin: 7 }
                                        spacing: 4
                                        Repeater {
                                            model: [
                                                { on: cell.onDesk,  txt: "Escritorio" },
                                                { on: cell.onLock,  txt: "Bloqueo" },
                                                { on: cell.onLogin, txt: "Login" }
                                            ]
                                            delegate: Rectangle {
                                                required property var modelData
                                                visible: modelData.on
                                                height: 18; width: bt.implicitWidth + 12; radius: 9
                                                color: Theme.scrim(0.78)
                                                border.width: 1; border.color: Theme.accentLine
                                                Text {
                                                    id: bt
                                                    anchors.centerIn: parent
                                                    text: modelData.txt
                                                    color: Theme.accent
                                                    font.family: Theme.font; font.pixelSize: 10; font.weight: Font.Medium
                                                }
                                            }
                                        }
                                    }
                                    Rectangle {   // video
                                        visible: cell.kind === "video"
                                        anchors { right: parent.right; top: parent.top; rightMargin: 7; topMargin: 7 }
                                        height: 18; width: vt.implicitWidth + 12; radius: 9
                                        color: Theme.scrim(0.78)
                                        Text { id: vt; anchors.centerIn: parent; text: "Animado"
                                            color: Theme.text; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.Medium }
                                    }
                                }
                                // Aro de selección
                                Rectangle {
                                    anchors { fill: thumbClip; margins: -3 }
                                    radius: 17
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Theme.accent
                                    opacity: cell.selected ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: Theme.dur(140) } }
                                }
                                Text {
                                    anchors { top: thumbClip.bottom; topMargin: 6; left: parent.left; right: parent.right }
                                    text: cell.name
                                    elide: Text.ElideRight
                                    color: cell.selected ? Theme.accent : Theme.dim
                                    font.family: Theme.font; font.pixelSize: 12
                                    font.weight: cell.selected ? Font.Medium : Font.Normal
                                }
                            }
                            MouseArea {
                                id: cellM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: st.sel = cell.index
                                onDoubleClicked: { st.sel = cell.index; st.apply() }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: grid
                        visible: st.loading && wallModel.count === 0
                        text: "Preparando miniaturas…"
                        color: Theme.dim
                        font.family: Theme.font; font.pixelSize: 14
                    }

                    // ── Panel derecho ───────────────────────
                    Rectangle {
                        id: side
                        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                        width: 340
                        radius: 26
                        color: Theme.bgSoft
                        border.width: 1
                        border.color: Theme.stroke

                        ColumnLayout {
                            anchors { fill: parent; margins: 16 }
                            spacing: 10

                            // Vista previa (con el panel del bloqueo simulado)
                            RoundClip {
                                id: pv
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(width * 9 / 16)
                                radius: 16
                                Rectangle { anchors.fill: parent; color: Theme.scrim(0.3) }
                                readonly property real off: (st.tLock && st.isImage) ? st.shiftPct / 100 * width : 0
                                Image {
                                    x: pv.off; width: pv.width; height: pv.height
                                    source: st.cur ? "file://" + st.cur.thumb : ""
                                    sourceSize: Qt.size(480, 270)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                Image {
                                    visible: pv.off > 0
                                    x: pv.off - pv.width; width: pv.width; height: pv.height
                                    source: st.cur ? "file://" + st.cur.thumb : ""
                                    sourceSize: Qt.size(480, 270)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                Rectangle {   // panel del bloqueo
                                    visible: st.tLock && st.isImage
                                    width: pv.width * 0.30; height: pv.height
                                    color: Theme.scrim(0.84)
                                    Text {
                                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 22 }
                                        text: "12:34"
                                        color: Theme.fade(0.85)
                                        font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Light
                                    }
                                    Rectangle {
                                        width: parent.width - 18; height: 9; radius: 4.5
                                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 58 }
                                        color: Theme.fade(0.12)
                                    }
                                    Rectangle {
                                        width: parent.width - 18; height: 9; radius: 4.5
                                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 72 }
                                        color: Theme.fade(0.12)
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 4
                                Text {
                                    Layout.fillWidth: true
                                    text: st.cur ? st.cur.name : "—"
                                    elide: Text.ElideRight
                                    color: Theme.text
                                    font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold
                                }
                                Text {
                                    text: st.cur ? (st.cur.kind === "video" ? "Video animado" : "Imagen") : ""
                                    color: Theme.dim
                                    font.family: Theme.font; font.pixelSize: 12
                                }
                            }

                            TargetRow {
                                label: "Escritorio"; sub: "Fondo de pantalla"; key: "1"
                                checked: st.tDesktop
                                onToggled: st.tDesktop = !st.tDesktop
                            }
                            TargetRow {
                                label: "Bloqueo"; sub: st.isImage || !st.cur ? "Win + L" : "Solo imágenes"; key: "2"
                                allowed: st.isImage
                                checked: st.tLock
                                onToggled: st.tLock = !st.tLock
                            }
                            TargetRow {
                                label: "Login"; sub: st.isImage || !st.cur ? "SDDM · pide tu contraseña" : "Solo imágenes"; key: "3"
                                allowed: st.isImage
                                checked: st.tLogin
                                onToggled: st.tLogin = !st.tLogin
                            }

                            // Desplazamiento del arte (solo para el bloqueo)
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 4
                                Layout.rightMargin: 4
                                spacing: 0
                                visible: st.tLock && st.isImage
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Mover el arte"
                                        color: Theme.dim
                                        font.family: Theme.font; font.pixelSize: 12
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: Math.round(st.shiftPct) + "%"
                                        color: Theme.text
                                        font.family: Theme.font; font.pixelSize: 12; font.features: { "tnum": 1 }
                                    }
                                }
                                Slider {
                                    Layout.fillWidth: true
                                    value: st.shiftPct / 40
                                    onMoved: v => st.shiftPct = v * 40
                                }
                            }

                            Item { Layout.fillHeight: true }

                            Text {
                                Layout.fillWidth: true
                                Layout.leftMargin: 4
                                visible: st.status !== ""
                                text: st.status
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                color: st.statusErr ? Theme.danger : Theme.dim
                                font.family: Theme.font; font.pixelSize: 12
                            }

                            // Botón aplicar
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: 26
                                color: st.canApply ? Theme.accent : Theme.s2
                                scale: applyM.pressed && st.canApply ? 0.97 : 1
                                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                                Behavior on scale { NumberAnimation { duration: Theme.dur(100) } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 10
                                    Canvas {
                                        id: spin
                                        visible: st.busy
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 18; height: 18
                                        onPaint: {
                                            const c = getContext("2d"); c.reset()
                                            c.strokeStyle = Theme.ink; c.lineWidth = 2.4; c.lineCap = "round"
                                            c.beginPath(); c.arc(9, 9, 6.5, 0, Math.PI * 1.5); c.stroke()
                                        }
                                        RotationAnimator on rotation {
                                            from: 0; to: 360; duration: Theme.dur(800)
                                            loops: Animation.Infinite; running: st.busy
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: st.busy ? "Aplicando…" : "Aplicar"
                                        color: st.canApply ? Theme.ink : Theme.dim
                                        font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
                                    }
                                }
                                MouseArea {
                                    id: applyM
                                    anchors.fill: parent
                                    cursorShape: st.canApply ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: st.apply()
                                }
                            }
                        }
                    }

                    // ── Importar desde Descargas ────────────
                    Rectangle {
                        anchors.fill: parent
                        visible: opacity > 0.01
                        opacity: st.importing ? 1 : 0
                        radius: 24
                        color: Theme.bg
                        Behavior on opacity { NumberAnimation { duration: Theme.dur(160) } }
                        MouseArea { anchors.fill: parent }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 12
                            Text {
                                Layout.leftMargin: 8
                                text: "Importar desde Descargas"
                                color: Theme.text
                                font.family: Theme.font; font.pixelSize: 17; font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.leftMargin: 8
                                text: "Se convierte a 1440p y 1080p y se añade a la lista. Mejor si el original es 4K."
                                color: Theme.dim
                                font.family: Theme.font; font.pixelSize: 12
                            }
                            ListView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 6
                                boundsBehavior: Flickable.StopAtBounds
                                model: recentModel
                                delegate: Rectangle {
                                    id: rrow
                                    required property string path
                                    width: ListView.view.width
                                    height: 76
                                    radius: 20
                                    color: rm.containsMouse ? Theme.bgHover : Theme.bgSoft
                                    Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 10; rightMargin: 16 }
                                        spacing: 14
                                        RoundClip {
                                            implicitWidth: 112; implicitHeight: 63; radius: 12
                                            Image {
                                                anchors.fill: parent
                                                source: "file://" + rrow.path
                                                sourceSize: Qt.size(224, 126)
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: rrow.path.split("/").pop()
                                            elide: Text.ElideMiddle
                                            color: Theme.text
                                            font.family: Theme.font; font.pixelSize: 13
                                        }
                                        Rectangle {
                                            implicitWidth: 92; implicitHeight: 36; radius: 18
                                            color: Theme.accent
                                            Text { anchors.centerIn: parent; text: "Importar"
                                                color: Theme.ink; font.family: Theme.font
                                                font.pixelSize: 13; font.weight: Font.DemiBold }
                                        }
                                    }
                                    MouseArea {
                                        id: rm
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            st.busy = true
                                            st.status = "Convirtiendo…"; st.statusErr = false
                                            importProc.command = [st.script, "import", rrow.path]
                                            importProc.running = true
                                        }
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: recentModel.count === 0
                                    text: "No hay imágenes en ~/Descargas"
                                    color: Theme.dim
                                    font.family: Theme.font; font.pixelSize: 14
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
