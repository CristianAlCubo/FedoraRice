import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// Menú de sesión: bloquear, suspender, cerrar sesión, reiniciar, apagar.
// Teclado: ←/→ o h/l mueven · Intro confirma · atajos L S E R P · Esc cierra.
// IPC: qs ipc call session toggle | open <lock|suspend|logout|reboot|shutdown> | close
Scope {
    id: sm

    property bool open: false
    property int sel: 2
    readonly property string home: Quickshell.env("HOME")
    readonly property var items: [
        { id: "lock",     t: "Bloquear",       g: "", k: Qt.Key_L, kt: "L", c: Theme.accent,
          cmd: sm.home + "/.config/hypr/scripts/lock.sh" },
        { id: "suspend",  t: "Suspender",      g: "", k: Qt.Key_S, kt: "S", c: Theme.accent2,
          cmd: "systemctl suspend" },
        { id: "logout",   t: "Cerrar sesión",  g: "", k: Qt.Key_E, kt: "E", c: Theme.yellow,
          cmd: "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'" },
        { id: "reboot",   t: "Reiniciar",      g: "", k: Qt.Key_R, kt: "R", c: Theme.orange,
          cmd: "systemctl reboot" },
        { id: "shutdown", t: "Apagar",         g: "", k: Qt.Key_P, kt: "P", c: Theme.danger,
          cmd: "systemctl poweroff" }
    ]
    Process { id: sh }
    function run(i) { open = false; sh.command = ["sh", "-c", items[i].cmd]; sh.running = true }

    IpcHandler {
        target: "session"
        function toggle(): void { sm.open = !sm.open }
        function close(): void { sm.open = false }
        function open(which: string): void {
            const i = sm.items.findIndex(x => x.id === which)
            if (i >= 0) sm.sel = i
            sm.open = true
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: sm.open && Hyprland.focusedMonitor?.name === modelData.name
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            onVisibleChanged: if (visible) keys.forceActiveFocus()

            MouseArea { anchors.fill: parent; onClicked: sm.open = false }
            Rectangle { anchors.fill: parent; color: Theme.scrim(0.45); opacity: win.visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.dur(160) } } }

            FocusScope {
                id: keys
                anchors.fill: parent
                Keys.onPressed: ev => {
                    const k = ev.key; ev.accepted = true
                    if (k === Qt.Key_Escape) sm.open = false
                    else if (k === Qt.Key_Left || k === Qt.Key_H) sm.sel = (sm.sel + sm.items.length - 1) % sm.items.length
                    else if (k === Qt.Key_Right || k === Qt.Key_Tab) sm.sel = (sm.sel + 1) % sm.items.length
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) sm.run(sm.sel)
                    else {
                        const i = sm.items.findIndex(x => x.k === k)
                        if (i >= 0) sm.sel = i
                        else ev.accepted = false
                    }
                }
            }

            Rectangle {
                id: card
                width: row.implicitWidth + 40
                height: 190
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: (Theme.sidebarW - Theme.frameW) / 2
                radius: 30
                color: Theme.bg
                border.width: 1
                border.color: Theme.stroke
                opacity: win.visible ? 1 : 0
                scale: win.visible ? 1 : 0.94
                Behavior on opacity { NumberAnimation { duration: Theme.dur(120) } }
                Behavior on scale { Anim { kind: "spatial" } }
                MouseArea { anchors.fill: parent }

                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: 12
                    Repeater {
                        model: sm.items
                        delegate: Rectangle {
                            id: it
                            required property var modelData
                            required property int index
                            readonly property bool cur: sm.sel === index
                            width: 116; height: 142; radius: 24
                            color: cur ? Qt.alpha(modelData.c, 0.2) : im.containsMouse ? Theme.s3 : Theme.s2
                            border.width: cur ? 2 : 0
                            border.color: modelData.c
                            Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                            Column {
                                anchors.centerIn: parent
                                spacing: 12
                                Text { text: it.modelData.g; font.family: Theme.mono; font.pixelSize: 38
                                    color: it.modelData.c; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: it.modelData.t; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium
                                    color: Theme.text; anchors.horizontalCenter: parent.horizontalCenter }
                                Rectangle { width: 22; height: 20; radius: 6; color: Theme.s4; anchors.horizontalCenter: parent.horizontalCenter
                                    Text { anchors.centerIn: parent; text: it.modelData.kt; font.family: Theme.mono; font.pixelSize: 11; color: Theme.dim } }
                            }
                            MouseArea { id: im; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: sm.sel = it.index
                                onClicked: sm.run(it.index) }
                        }
                    }
                }
            }
        }
    }
}
