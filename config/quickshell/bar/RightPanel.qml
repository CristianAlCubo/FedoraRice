import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// Panel de controles a la derecha (estilo caelestia): ajustes rápidos, captura,
// accesos a Ajustes y sesión (bloquear, salir, reiniciar, apagar).
// Se abre desde el engranaje de la sidebar o con `qs ipc call controls toggle`.
Scope {
    id: cp

    required property var notifs
    required property var rec
    required property var dash
    property bool open: false

    readonly property string home: Quickshell.env("HOME")
    Process { id: sh }

    // ── Temas (presets en ~/.config/rice/themes) ──
    property bool themesOpen: false
    FileView { id: themeIdx; path: cp.home + "/.config/rice/themes/index.json"; blockLoading: true }
    readonly property var themeList: { try { return JSON.parse(themeIdx.text()) } catch (e) { return [] } }
    function setTheme(id) { run("python3 " + home + "/.config/rice/apply.py set " + id) }
    function run(cmd) { sh.command = ["sh", "-c", cmd]; sh.running = true }
    function act(cmd) { cp.open = false; run(cmd) }

    IpcHandler {
        target: "controls"
        function toggle(): void { cp.open = !cp.open }
        function hide(): void   { cp.open = false }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            visible: cp.open && Hyprland.focusedMonitor?.name === modelData.name
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            onVisibleChanged: if (visible) keys.forceActiveFocus()

            MouseArea { anchors.fill: parent; onClicked: cp.open = false }
            FocusScope { id: keys; anchors.fill: parent; Keys.onEscapePressed: cp.open = false }

            Rectangle {
                id: card
                width: 380
                height: Math.min(win.height - 2 * (Theme.frameW + Theme.frameR + Theme.flare), col.implicitHeight + 36)
                y: (win.height - height) / 2
                x: win.width - width - Theme.frameW
                property real off: win.visible ? 0 : 1
                Behavior on off { Anim { kind: "spatial" } }
                opacity: Math.max(0, Math.min(1, 1 - off * 1.2))
                transform: Translate { x: card.off * (card.width + Theme.frameW + 10) }
                color: "transparent"
                Fused { edge: "right"; r: 28 }
                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: col
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                    spacing: 14

                    Text {
                        text: "Controles"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }

                    QuickSettings {
                        Layout.fillWidth: true
                        notifs: cp.notifs
                        active: win.visible
                    }

                    // ── Captura ──
                    Text { text: "Captura"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
                    GridLayout {
                        columns: 2; columnSpacing: 8; rowSpacing: 8
                        Layout.fillWidth: true
                        Repeater {
                            model: [
                                { t: "Pantalla",         g: "", m: "shot-full" },
                                { t: "Región",           g: "", m: "shot-region" },
                                { t: "Grabar pantalla",  g: "", m: "rec-full" },
                                { t: "Grabar región",    g: "", m: "rec-region" }
                            ]
                            delegate: Rectangle {
                                id: cb
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 44
                                radius: 16
                                color: cm.containsMouse ? Theme.bgHover : Theme.bgSoft
                                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text { text: cb.modelData.g; font.family: Theme.mono; font.pixelSize: 15
                                        color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: cb.modelData.t; font.family: Theme.font; font.pixelSize: 13
                                        color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
                                }
                                MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { cp.open = false; cp.dash.capture(cb.modelData.m) } }
                                Ripple {}
                            }
                        }
                    }

                    // ── Accesos ──
                    Text { text: "Accesos"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Repeater {
                            model: [
                                { t: "Fondos",    g: "", k: "settings" },
                                { t: "Widgets",   g: "", k: "widgets" },
                                { t: "Juego",     g: "", k: "game" }
                            ]
                            delegate: Rectangle {
                                id: ab
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 62
                                radius: 18
                                color: am.containsMouse ? Theme.bgHover : Theme.bgSoft
                                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: ab.modelData.g; font.family: Theme.mono; font.pixelSize: 18
                                        color: Theme.accent2; anchors.horizontalCenter: parent.horizontalCenter }
                                    Text { text: ab.modelData.t; font.family: Theme.font; font.pixelSize: 11
                                        color: Theme.text; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                                MouseArea { id: am; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        cp.open = false
                                        const q = "qs -p " + cp.home + "/.config/quickshell/bar ipc call "
                                        if (ab.modelData.k === "settings") cp.run(q + "settings toggle")
                                        else if (ab.modelData.k === "widgets") cp.run(q + "widgets edit")
                                        else if (ab.modelData.k === "game") cp.run(q + "gamemode toggle")
                                    } }
                                Ripple {}
                            }
                        }
                    }

                    // ── Tema ──
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 44
                        radius: 16
                        color: thM.containsMouse ? Theme.bgHover : Theme.bgSoft
                        Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                        Row {
                            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            spacing: 10
                            Text { text: "\udb80\udfd8"; font.family: Theme.mono; font.pixelSize: 16; color: Theme.accent2
                                anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Tema"; font.family: Theme.font; font.pixelSize: 13; color: Theme.text
                                anchors.verticalCenter: parent.verticalCenter }
                            Text { text: Theme.themeName; font.family: Theme.font; font.pixelSize: 12; color: Theme.dim
                                anchors.verticalCenter: parent.verticalCenter }
                        }
                        Text { anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            text: cp.themesOpen ? "\uf077" : "\uf078"; font.family: Theme.mono; font.pixelSize: 12; color: Theme.dim }
                        MouseArea { id: thM; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: cp.themesOpen = !cp.themesOpen }
                        Ripple {}
                    }
                    GridLayout {
                        visible: cp.themesOpen
                        columns: 2; columnSpacing: 8; rowSpacing: 8
                        Layout.fillWidth: true
                        Repeater {
                            model: cp.themeList
                            delegate: Rectangle {
                                id: tc
                                required property var modelData
                                readonly property bool current: modelData.id === Theme.themeId
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: 14
                                color: modelData.base            // vista previa con los colores reales del tema
                                border.width: current ? 2 : 1
                                border.color: current ? modelData.accent : Qt.alpha(modelData.text, 0.15)
                                opacity: tm2.containsMouse ? 1 : 0.88
                                Behavior on opacity { NumberAnimation { duration: Theme.dur(120) } }
                                Column {
                                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                    spacing: 6
                                    Text { text: tc.modelData.name; font.family: Theme.font; font.pixelSize: 12
                                        font.weight: tc.current ? Font.DemiBold : Font.Normal; color: tc.modelData.text }
                                    Row {
                                        spacing: 5
                                        Repeater {
                                            model: [tc.modelData.accent, tc.modelData.accent2, tc.modelData.green, tc.modelData.yellow, tc.modelData.red]
                                            delegate: Rectangle { required property var modelData; width: 10; height: 10; radius: 5; color: modelData }
                                        }
                                    }
                                }
                                MouseArea { id: tm2; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor; onClicked: cp.setTheme(tc.modelData.id) }
                            }
                        }
                    }

                    // ── Animaciones: Sutil / Normal / Dinámico (escala de tiempos del shell, theme.json → scale.anim) ──
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: "Animaciones"; font.family: Theme.font; font.pixelSize: 12; color: Theme.dim
                            Layout.rightMargin: 4 }
                        Repeater {
                            model: [ { t: "Sutil", v: 0.6 }, { t: "Normal", v: 1.0 }, { t: "Dinámico", v: 1.3 } ]
                            delegate: Rectangle {
                                id: an
                                required property var modelData
                                readonly property bool cur: Math.abs(Theme.animScale - modelData.v) < 0.05
                                Layout.fillWidth: true; implicitHeight: 34; radius: 12
                                color: cur ? Theme.accentSoft : anM.containsMouse ? Theme.bgHover : Theme.bgSoft
                                border.width: cur ? 1 : 0; border.color: Theme.accentLine
                                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                                Text { anchors.centerIn: parent; text: an.modelData.t; font.family: Theme.font; font.pixelSize: 12
                                    color: an.cur ? Theme.accent : Theme.text }
                                MouseArea { id: anM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: cp.run("python3 -c \"import json,os;p=os.path.expanduser('~/.config/rice/theme.json');d=json.load(open(p));d.setdefault('scale',{})['anim']=" + an.modelData.v + ";json.dump(d,open(p,'w'),indent=2,ensure_ascii=False)\"") }
                                Ripple {}
                            }
                        }
                    }

                    // ── Sincronizar Archivos (Nautilus/GTK) con el tema: solo bajo demanda, nunca automático ──
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: 14
                        color: syM.containsMouse ? Theme.bgHover : Theme.bgSoft
                        Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                        Row {
                            anchors.centerIn: parent
                            spacing: 10
                            Text { text: "\uf07b"; font.family: Theme.mono; font.pixelSize: 15; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Sincronizar Archivos con el tema"; font.family: Theme.font; font.pixelSize: 13; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: syM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: cp.run("python3 ~/.config/rice/apply.py gtk >/dev/null 2>&1 && qs -p @HOME@/.config/quickshell/bar ipc call toasts push \"\uf07b\" \"Archivos sincronizado con el tema (reábrelo para verlo)\"") }
                        Ripple {}
                    }

                    // ── Sesión ──
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Repeater {
                            model: [
                                { t: "Bloquear",  g: "", c: "@HOME@/.config/hypr/scripts/lock.sh", col: Theme.accent },
                                { t: "Salir",     g: "", c: "qs -p @HOME@/.config/quickshell/bar ipc call session open logout", col: Theme.yellow },
                                { t: "Reiniciar", g: "", c: "qs -p @HOME@/.config/quickshell/bar ipc call session open reboot", col: Theme.orange },
                                { t: "Apagar",    g: "", c: "qs -p @HOME@/.config/quickshell/bar ipc call session open shutdown", col: Theme.danger }
                            ]
                            delegate: Rectangle {
                                id: pb
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 50
                                radius: 18
                                color: pm.containsMouse ? Qt.alpha(pb.modelData.col, 0.2) : Theme.bgSoft
                                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                                Text { anchors.centerIn: parent; text: pb.modelData.g; font.family: Theme.mono
                                    font.pixelSize: 18; color: pb.modelData.col }
                                MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: cp.act(pb.modelData.c) }
                                Ripple {}
                            }
                        }
                    }
                }
            }
        }
    }
}
