import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray

// Menú desplegable propio para los iconos de la bandeja (Steam, Discord...).
// Lee las entradas reales del menú DBus de la app y las dibuja con nuestro estilo.
Scope {
    id: tm

    property var item: null            // SystemTrayItem abierto
    property string screenName: ""
    property real anchorX: 0           // centro y del icono (sidebar izquierda), en coordenadas de pantalla
    property var stack: []             // submenús abiertos (QsMenuEntry)

    readonly property var current: stack.length > 0 ? stack[stack.length - 1]
                                   : (item ? item.menu : null)
    readonly property bool isOpen: item !== null
    // ¿alguna entrada tiene icono o marca? si no, no reservamos la columna
    readonly property bool hasLeading: opener.children.values.some(e =>
        !e.isSeparator && (e.icon !== "" || e.buttonType !== QsMenuButtonType.None))

    // ── Steam: juegos jugados recientemente (miniaturas) ──
    readonly property bool isSteam: item !== null && (item.id + " " + item.title).toLowerCase().includes("steam")
    property var games: []
    // acciones del menú de Steam (todo lo que va tras el primer separador;
    // lo anterior son los juegos recientes, que ya mostramos como portadas)
    readonly property var steamActions: {
        const all = opener.children.values
        const first = all.findIndex(e => e.isSeparator)
        return all.slice(first + 1).filter(e => !e.isSeparator)
    }
    readonly property var steamIcons: ({
        "store": "web-browser", "library": "view-app-grid", "community": "system-users",
        "friends": "avatar-default", "settings": "preferences-system",
        "big picture": "view-fullscreen", "steamvr": "audio-headset", "exit steam": "system-shutdown"
    })

    function ago(ts) {
        const d = Math.max(0, Date.now() / 1000 - ts)
        if (d < 3600) return "hace " + Math.max(1, Math.floor(d / 60)) + " min"
        if (d < 86400) return "hace " + Math.floor(d / 3600) + " h"
        if (d < 86400 * 30) return "hace " + Math.floor(d / 86400) + " d"
        return "hace " + Math.floor(d / 86400 / 30) + " m"
    }

    Process {
        id: recentProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/bar/steam-recent.py", "5"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { tm.games = JSON.parse(text) } catch (e) { tm.games = [] }
            }
        }
    }
    Process { id: launchProc }
    // Steam: pide la ventana principal y salta a su workspace (activate() del tray no lo hace)
    Process {
        id: focusProc
        command: ["sh", "-c", "steam steam://open/main >/dev/null 2>&1 & sleep 0.4; hyprctl dispatch 'hl.dsp.focus({ window = \"class:steam\" })'"]
    }

    // Spotify: vive oculto en special:spotify; enfocarlo muestra ese workspace
    readonly property bool isSpotify: item !== null && (item.id + " " + item.title).toLowerCase().includes("spotify")
    Process {
        id: spotifyProc
        command: ["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({ window = \"class:Spotify\" })' >/dev/null 2>&1 || /var/lib/snapd/snap/bin/spotify"]
    }
    function openSpotify() { spotifyProc.running = true; close() }

    function launch(appid) {
        launchProc.command = ["steam", "steam://rungameid/" + appid]
        launchProc.running = true
        close()
    }

    function openFor(it, screen, x) {
        stack = []
        screenName = screen
        anchorX = x
        item = it
        if (isSteam) { games = []; recentProc.running = true }
    }
    function close() { item = null; stack = [] }
    function back() { stack = stack.slice(0, -1) }

    QsMenuOpener { id: opener; menu: tm.current }

    // qs ipc call traymenu list | open <texto>: abrir el menú de un icono por nombre
    IpcHandler {
        target: "traymenu"
        function list(): string {
            return SystemTray.items.values.map(i => i.id + " | " + i.title + " | menu=" + i.hasMenu).join("\n")
        }
        function open(name: string): void {
            const q = name.toLowerCase()
            const it = SystemTray.items.values.find(i =>
                (i.id + " " + i.title).toLowerCase().includes(q))
            if (it) tm.openFor(it, Hyprland.focusedMonitor?.name ?? "", 400)
        }
        function hide(): void { tm.close() }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            visible: tm.isOpen && tm.screenName === modelData.name

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onVisibleChanged: if (visible) keys.forceActiveFocus()

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: tm.close()
            }

            FocusScope {
                id: keys
                anchors.fill: parent
                Keys.onEscapePressed: { if (tm.stack.length > 0) tm.back(); else tm.close() }
            }

            SideClip { id: sideClip }

            GrowPanel {
                id: card
                parent: sideClip
                panelWidth: tm.isSteam && tm.stack.length === 0 ? 416 : 270
                panelHeight: col.implicitHeight + 16
                radius: 22
                Behavior on panelWidth { Anim { kind: "fastSpatial" } }
                x: 0
                y: Math.max(Theme.frameW + Theme.frameR + Theme.flare, Math.min(win.height - height - Theme.frameW - Theme.frameR - Theme.flare, tm.anchorX - 24))
                property real off: win.visible ? 0 : 1
                Behavior on off { Anim { kind: "fastSpatial" } }
                reveal: 1 - off
                Behavior on panelHeight { Anim { kind: "fastSpatial" } }

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: col
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                    spacing: 2

                    // ── Cabecera: app (o "atrás" en un submenú) ──
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: 16
                        color: headM.containsMouse ? Theme.bgHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Icon {   // flecha atrás (solo en submenús)
                                visible: tm.stack.length > 0
                                name: "pan-down"; size: 14; color: Theme.dim
                                rotation: 90
                            }
                            Image {
                                visible: tm.stack.length === 0 && source != ""
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                sourceSize: Qt.size(48, 48)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                source: tm.item ? String(tm.item.icon).replace("path=/snap/", "path=/var/lib/snapd/snap/") : ""
                            }
                            Text {
                                Layout.fillWidth: true
                                text: tm.stack.length > 0 ? tm.stack[tm.stack.length - 1].text
                                      : (tm.item ? (tm.item.tooltipTitle || tm.item.title || tm.item.id) : "")
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {   // acción de abrir la ventana principal
                                visible: tm.stack.length === 0 && tm.item && !tm.item.onlyMenu
                                text: "Abrir"
                                color: Theme.accent
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                        }
                        MouseArea {
                            id: headM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (tm.stack.length > 0) { tm.back(); return }
                                if (tm.isSteam) focusProc.running = true
                                else if (tm.isSpotify) { tm.openSpotify(); return }
                                else if (tm.item && !tm.item.onlyMenu) tm.item.activate()
                                tm.close()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        implicitHeight: 1
                        color: Theme.stroke
                    }

                    // ── Steam: portadas + acciones ──────────
                    ColumnLayout {
                        id: steamView
                        visible: tm.isSteam && tm.stack.length === 0
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        spacing: 10

                        // portadas de los últimos juegos
                        RowLayout {
                            visible: tm.games.length > 0
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                            spacing: 8

                            Repeater {
                                model: tm.games

                                delegate: Item {
                                    id: gcard
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: width * 1.5

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.topMargin: gm.containsMouse ? 0 : 4
                                        Behavior on anchors.topMargin { NumberAnimation { duration: Theme.dur(140); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard } }
                                        radius: 10
                                        color: Theme.bgSoft
                                        clip: true
                                        border.width: 1
                                        border.color: gm.containsMouse ? Theme.accent : Theme.stroke
                                        Behavior on border.color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }

                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            source: gcard.modelData.art ? "file://" + gcard.modelData.art : ""
                                            sourceSize: Qt.size(360, 540)
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            smooth: true
                                        }
                                    }
                                    MouseArea {
                                        id: gm
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: tm.launch(gcard.modelData.id)
                                    }
                                }
                            }
                        }

                        // acciones como botones con icono
                        GridLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                            columns: 4
                            columnSpacing: 8
                            rowSpacing: 8

                            Repeater {
                                model: tm.steamActions

                                delegate: Item {
                                    id: abtn
                                    required property var modelData
                                    readonly property bool danger: modelData.text.toLowerCase().startsWith("exit")
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 80

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 18
                                        color: am.containsMouse ? (abtn.danger ? Qt.alpha(Theme.danger, 0.16) : Theme.accentSoft) : Theme.bgSoft
                                        border.width: 1
                                        border.color: am.containsMouse ? (abtn.danger ? Theme.danger : Theme.accentLine) : Theme.stroke
                                        Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                                        Behavior on border.color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 5
                                            Icon {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                name: tm.steamIcons[abtn.modelData.text.toLowerCase()] ?? "applications-games"
                                                size: 26
                                                color: abtn.danger ? Theme.danger : (am.containsMouse ? Theme.accent : Theme.text)
                                            }
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: abtn.modelData.text
                                                color: abtn.danger ? Theme.danger : Theme.dim
                                                font.family: Theme.font
                                                font.pixelSize: 12
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: am
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { abtn.modelData.triggered(); tm.close() }
                                    }
                                }
                            }
                        }
                    }

                    // ── Spotify: abrir el cliente ───────────
                    Rectangle {
                        visible: tm.isSpotify && tm.stack.length === 0
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 14
                        color: spm.containsMouse ? Theme.bgHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            Icon { name: "view-fullscreen"; size: 16; color: Theme.accent }
                            Text {
                                Layout.fillWidth: true
                                text: "Abrir cliente de Spotify"
                                color: Theme.accent
                                font.family: Theme.font
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                        }
                        MouseArea {
                            id: spm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tm.openSpotify()
                        }
                    }

                    // ── Entradas ────────────────────────────
                    ListView {
                        id: list
                        visible: !(tm.isSteam && tm.stack.length === 0)
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(contentHeight, 440)
                        clip: true
                        spacing: 1
                        boundsBehavior: Flickable.StopAtBounds
                        model: opener.children

                        delegate: Item {
                            id: row
                            required property var modelData
                            readonly property bool sep: modelData.isSeparator
                            width: list.width
                            height: sep ? 9 : 38

                            Rectangle {   // separador
                                visible: row.sep
                                anchors.verticalCenter: parent.verticalCenter
                                x: 10; width: parent.width - 20; height: 1
                                color: Theme.stroke
                            }

                            Rectangle {
                                visible: !row.sep
                                anchors.fill: parent
                                radius: 14
                                color: rm.containsMouse && row.modelData.enabled ? Theme.bgHover : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10
                                    opacity: row.modelData.enabled ? 1 : 0.4

                                    Item {   // columna de icono / marca
                                        visible: tm.hasLeading
                                        Layout.preferredWidth: 18
                                        Layout.preferredHeight: 18
                                        Glyph {
                                            anchors.centerIn: parent
                                            visible: row.modelData.checkState === Qt.Checked
                                            kind: "check"
                                            color: Theme.accent
                                        }
                                        Image {
                                            anchors.fill: parent
                                            visible: row.modelData.checkState !== Qt.Checked && source != ""
                                            sourceSize: Qt.size(36, 36)
                                            fillMode: Image.PreserveAspectFit
                                            source: row.modelData.icon
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: row.modelData.text
                                        elide: Text.ElideRight
                                        color: row.modelData.checkState === Qt.Checked ? Theme.accent : Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                    }
                                    Icon {
                                        visible: row.modelData.hasChildren
                                        name: "pan-down"; size: 14; color: Theme.dim
                                        rotation: -90
                                    }
                                }

                                MouseArea {
                                    id: rm
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: row.modelData.enabled
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (row.modelData.hasChildren) {
                                            tm.stack = tm.stack.concat([row.modelData])
                                        } else {
                                            row.modelData.triggered()
                                            tm.close()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
