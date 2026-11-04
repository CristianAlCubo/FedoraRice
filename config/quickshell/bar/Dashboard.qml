import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// Dashboard con pestañas bajo el reloj: Inicio · Multimedia · Sistema · Avisos.
// Se abre con click en el reloj, con `qs ipc call dashboard toggle` o `openTab <id>`.
Scope {
    id: dash

    required property var notifs
    property bool open: false
    property int tab: 0
    property bool inContent: false      // teclado dentro del contenido de la pestaña
    onTabChanged: inContent = false
    onOpenChanged: { inContent = false; capOpen = false }

    // ── Captura de pantalla / grabación ──
    property bool capOpen: false
    required property var rec               // Recorder (estado de la grabación)
    readonly property bool recording: rec.active
    readonly property string capScript: Quickshell.env("HOME") + "/.config/hypr/scripts/capture.sh"
    function capture(mode) {
        console.log("[captura] modo=" + mode)
        capOpen = false
        open = false
        capProc.command = ["sh", capScript, mode]
        capProc.running = true
    }
    Process { id: capProc }

    readonly property var tabs: [
        { id: "home",   label: "Inicio",     icon: "go-home" },
        { id: "media",  label: "Multimedia", icon: "multimedia-player" },
        { id: "system", label: "Sistema",    icon: "computer" },
        { id: "alerts", label: "Avisos",     icon: "preferences-system-notifications" }
    ]

    IpcHandler {
        target: "dashboard"
        function toggle(): void { dash.open = !dash.open }
        function hide(): void   { dash.open = false }
        function capture(mode: string): void { dash.capture(mode) }
        function content(on: bool): void { dash.inContent = on }
        function openTab(name: string): void {
            const i = dash.tabs.findIndex(t => t.id === name)
            if (i >= 0) dash.tab = i
            dash.open = true
        }
    }

    Stats { id: sysStats; active: dash.open }
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            // La ventana queda creada (transparente y sin captura) para que abrir no espere a crear la superficie
            readonly property bool shown: dash.open && Hyprland.focusedMonitor?.name === modelData.name
            visible: true
            mask: shown ? null : emptyMask
            Region { id: emptyMask }

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onShownChanged: if (shown) keys.forceActiveFocus()

            MouseArea { anchors.fill: parent; onClicked: dash.open = false }

            FocusScope {
                id: keys
                anchors.fill: parent
                Keys.onPressed: ev => {
                    const n = dash.tabs.length
                    const k = ev.key
                    ev.accepted = true
                    if (dash.capOpen && k === Qt.Key_Escape) { dash.capOpen = false; return }
                    if (k >= Qt.Key_1 && k < Qt.Key_1 + n) { dash.tab = k - Qt.Key_1; return }

                    // Dentro del contenido: la pestaña maneja la tecla; ↑/Esc devuelven a la barra
                    if (dash.inContent) {
                        const cur = [homeTab, mediaTab, sysTab, alertsTab][dash.tab]
                        if (cur.handleKey(k, ev.modifiers)) return
                        if (k === Qt.Key_Escape || k === Qt.Key_Up) { dash.inContent = false; return }
                        ev.accepted = false
                        return
                    }

                    const here = [homeTab, mediaTab, sysTab, alertsTab][dash.tab]
                    if (here.quickKey && here.quickKey(ev.key, ev.modifiers)) return

                    if (k === Qt.Key_Escape) dash.open = false
                    else if (k === Qt.Key_Right || k === Qt.Key_Tab) dash.tab = (dash.tab + 1) % n
                    else if (k === Qt.Key_Left || k === Qt.Key_Backtab) dash.tab = (dash.tab + n - 1) % n
                    else if (k === Qt.Key_Down || k === Qt.Key_Return || k === Qt.Key_Enter) {
                        if ([homeTab, mediaTab, sysTab, alertsTab][dash.tab].interactive) dash.inContent = true
                    }
                    else ev.accepted = false
                }
            }

            Rectangle {
                id: card
                width: 740
                height: 16 + 46 + 12 + 372 + 16
                x: (parent.width - width) / 2 + (Theme.sidebarW - Theme.frameW) / 2
                y: Theme.frameW
                color: "transparent"
                visible: opacity > 0.01
                // Como Caelestia: el panel sale del borde con curva espacial (leve sobreimpulso) y fundido
                property real off: win.shown ? 0 : 1
                Behavior on off { Anim { kind: "spatial" } }
                opacity: Math.max(0, Math.min(1, 1 - off * 1.2))
                transform: Translate { y: -card.off * (card.height + Theme.frameW) }

                Fused { edge: "top"; r: 30 }

                MouseArea { anchors.fill: parent }

                // Borde que marca que el teclado está dentro del contenido de la pestaña
                Rectangle {
                    x: 16 + pages.x - 5
                    y: 16 + pages.y - 5
                    width: pages.width + 10
                    height: pages.height + 10
                    radius: 28
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.accent
                    opacity: dash.inContent ? 1 : 0
                    visible: opacity > 0.01
                    z: 5
                    Behavior on opacity { NumberAnimation { duration: Theme.dur(160) } }
                }


                // ── Botón de captura (esquina superior derecha) ──
                Rectangle {
                    id: capBtn
                    x: card.width - 16 - 46
                    y: 16
                    width: 46; height: 46; radius: 23
                    z: 10
                    color: dash.recording ? Qt.alpha(Theme.danger, 0.18)
                           : (capM.containsMouse || dash.capOpen ? Theme.accentSoft : Theme.bgSoft)
                    border.width: 1
                    border.color: dash.recording ? Theme.danger : (dash.capOpen ? Theme.accentLine : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                    Icon {
                        anchors.centerIn: parent
                        name: dash.recording ? "media-record" : "camera-photo"
                        size: 20
                        color: dash.recording ? Theme.danger : (capM.containsMouse || dash.capOpen ? Theme.accent : Theme.text)
                    }
                    MouseArea {
                        id: capM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dash.capOpen = !dash.capOpen
                    }
                }

                // Menú de captura
                Rectangle {
                    id: capMenu
                    visible: opacity > 0.01
                    opacity: dash.capOpen ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.dur(120) } }
                    z: 11
                    width: 250
                    height: capCol.implicitHeight + 12
                    x: card.width - 16 - width
                    y: 16 + 46 + 8
                    radius: 20
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.stroke

                    MouseArea { anchors.fill: parent }

                    Column {
                        id: capCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                        spacing: 2

                        Repeater {
                            model: dash.recording
                                ? [ { l: dash.rec.paused ? "Reanudar grabación" : "Pausar grabación",
                                      m: dash.rec.paused ? "rec-resume" : "rec-pause",
                                      i: dash.rec.paused ? "media-playback-start" : "media-playback-pause", sep: false },
                                    { l: "Detener grabación", m: "rec-stop", i: "media-playback-stop", danger: true, sep: false } ]
                                : [ { l: "Captura de pantalla completa", m: "shot-full",   i: "camera-photo", sep: false },
                                    { l: "Captura de una región",       m: "shot-region", i: "selection-mode", sep: false },
                                    { l: "Grabar pantalla completa",    m: "rec-full",    i: "camera-video", sep: true },
                                    { l: "Grabar una región",           m: "rec-region",  i: "media-record", sep: false } ]
                            delegate: Column {
                                id: cr
                                required property var modelData
                                width: capCol.width
                                Rectangle {
                                    visible: cr.modelData.sep
                                    x: 10; width: parent.width - 20; height: 1
                                    color: Theme.stroke
                                }
                                Item { visible: cr.modelData.sep; width: 1; height: 4 }
                                Rectangle {
                                    width: parent.width; height: 38; radius: 14
                                    color: crm.containsMouse ? Theme.bgHover : "transparent"
                                    Row {
                                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                        spacing: 10
                                        Icon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: cr.modelData.i; size: 16
                                            color: cr.modelData.danger ? Theme.danger : (crm.containsMouse ? Theme.accent : Theme.dim)
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: cr.modelData.l
                                            color: cr.modelData.danger ? Theme.danger : Theme.text
                                            font.family: Theme.font; font.pixelSize: 13
                                        }
                                    }
                                    MouseArea {
                                        id: crm
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { console.log("[captura] click " + cr.modelData.m); dash.capture(cr.modelData.m) }
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    anchors { fill: parent; margins: 16 }
                    spacing: 12

                    // ── Barra de pestañas ───────────────────
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: tabRow.implicitWidth + 12
                        implicitHeight: 46
                        radius: 23
                        color: Theme.bgSoft

                        Rectangle {   // indicador deslizante
                            readonly property var cur: rep.count > 0 ? rep.itemAt(dash.tab) : null
                            y: 5; height: 36; radius: 18
                            x: cur ? 6 + cur.x : 6
                            width: cur ? cur.width : 0
                            color: Theme.accentSoft
                            border.width: 1
                            border.color: Theme.accentLine
                            opacity: dash.inContent ? 0.45 : 1
                            Behavior on opacity { NumberAnimation { duration: Theme.dur(160) } }
                            Behavior on x { Anim { kind: "fastSpatial" } }
                            Behavior on width { Anim { kind: "fastSpatial" } }
                        }

                        Row {
                            id: tabRow
                            x: 6; y: 5
                            spacing: 2
                            Repeater {
                                id: rep
                                model: dash.tabs
                                delegate: Item {
                                    id: tb
                                    required property var modelData
                                    required property int index
                                    readonly property bool cur: dash.tab === index
                                    width: tbRow.implicitWidth + 36
                                    height: 36

                                    Row {
                                        id: tbRow
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Icon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: tb.modelData.icon; size: 16
                                            color: tb.cur ? Theme.accent : (tbM.containsMouse ? Theme.text : Theme.dim)
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: tb.modelData.label
                                            color: tb.cur ? Theme.accent : (tbM.containsMouse ? Theme.text : Theme.dim)
                                            font.family: Theme.font
                                            font.pixelSize: 13
                                            font.weight: tb.cur ? Font.DemiBold : Font.Medium
                                        }
                                        Rectangle {   // hay avisos
                                            visible: tb.modelData.id === "alerts" && dash.notifs.count > 0
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 6; height: 6; radius: 3
                                            color: dash.notifs.dnd ? Theme.dim : Theme.accent
                                        }
                                    }
                                    MouseArea {
                                        id: tbM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: dash.tab = tb.index
                                    }
                                }
                            }
                        }
                    }

                    // ── Páginas con transición deslizante ───
                    Item {
                        id: pages
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        component Page: Item {
                            required property int idx
                            width: pages.width
                            height: pages.height
                            x: (idx - dash.tab) * pages.width
                            opacity: idx === dash.tab ? 1 : 0
                            visible: opacity > 0.01
                            Behavior on x { Anim { kind: "fastSpatial" } }
                            Behavior on opacity { NumberAnimation { duration: Theme.dur(220) } }
                        }

                        Page { idx: 0; TabHome   { id: homeTab; focused: dash.inContent && dash.tab === 0; anchors.fill: parent; notifs: dash.notifs; now: clock.date
                                                      active: dash.open && dash.tab === 0 } }
                        Page { idx: 1; TabMedia  { id: mediaTab; onFocusBack: keys.forceActiveFocus(); focused: dash.inContent && dash.tab === 1; anchors.fill: parent; active: dash.open && dash.tab === 1 } }
                        Page { idx: 2; TabSystem { id: sysTab; focused: dash.inContent && dash.tab === 2; anchors.fill: parent; stats: sysStats } }
                        Page { idx: 3; TabAlerts { id: alertsTab; focused: dash.inContent && dash.tab === 3; anchors.fill: parent; notifs: dash.notifs } }
                    }
                }
            }
        }
    }
}
