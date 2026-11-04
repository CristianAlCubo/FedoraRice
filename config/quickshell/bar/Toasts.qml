import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// Avisos breves ("utilidades"): bloq mayús/num, salida de audio, distribución de teclado, VPN,
// no molestar y modo juego. Salen del borde inferior, fusionados con el marco.
// Se activan/desactivan en shell.json → "toasts". Uso manual: qs ipc call toasts push <glifo> <texto>
Scope {
    id: ts

    required property var notifs
    required property var gamemode

    property string glyph: ""
    property string message: ""
    property color tint: Theme.accent
    property bool shown: false
    property bool armed: false
    Timer { interval: 4000; running: true; onTriggered: ts.armed = true }   // no avisar por el estado inicial
    Timer { id: hideT; interval: 2200; onTriggered: ts.shown = false }

    function push(g, text, c) {
        glyph = g; message = text; tint = c ?? Theme.accent
        shown = true; hideT.restart()
    }
    function on(key) { return (Cfg.toasts[key] ?? true) && armed }

    IpcHandler {
        target: "toasts"
        function push(glyph: string, text: string): void { ts.push(glyph, text) }
    }

    // ── Bloq Núm (LEDs del teclado; el aviso de Bloq Mayús se quitó por molesto) ──
    property string _leds: ""
    Process {
        command: ["sh", "-c", "while :; do c=$(cat /sys/class/leds/*::capslock/brightness 2>/dev/null | sort -r | head -1); " +
                              "n=$(cat /sys/class/leds/*::numlock/brightness 2>/dev/null | sort -r | head -1); echo \"${c:-0} ${n:-0}\"; sleep 0.4; done"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (line === ts._leds) return
                const prev = ts._leds.split(" "), cur = line.split(" ")
                ts._leds = line
                if (prev.length < 2 || !ts.on("capsNum")) return
                if (prev[1] !== cur[1]) ts.push("", "Bloq Núm " + (cur[1] === "1" ? "activado" : "desactivado"), cur[1] === "1" ? Theme.accent : Theme.dim)
            }
        }
    }

    // ── Salida de audio ──
    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            if (!ts.on("audioOutput")) return
            const s = Pipewire.defaultAudioSink
            if (s) ts.push("", "Salida: " + (s.description || s.name), Theme.accent)
        }
    }

    // ── Micrófono ──
    PwObjectTracker { objects: [Pipewire.defaultAudioSource] }
    Connections {
        target: Pipewire.defaultAudioSource?.audio ?? null
        function onMutedChanged() {
            if (!ts.on("mic")) return
            const m = Pipewire.defaultAudioSource.audio.muted
            ts.push(m ? "\uf131" : "\uf130", "Micrófono " + (m ? "silenciado" : "activado"), m ? Theme.danger : Theme.green)
        }
    }

    // ── Distribución de teclado ──
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "activelayout" || !ts.on("layout")) return
            const p = ev.data.split(",")
            ts.push("", "Teclado: " + (p.slice(1).join(",") || p[0]), Theme.accent2)
        }
    }

    // ── VPN (NetBird: interfaz wt0) ──
    property int _vpn: -1
    Process {
        id: vpnP
        command: ["sh", "-c", "ip -o link show wt0 >/dev/null 2>&1 && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: {
            const v = text.trim() === "1" ? 1 : 0
            if (ts._vpn >= 0 && v !== ts._vpn && ts.on("vpn"))
                ts.push("", v ? "VPN conectada" : "VPN desconectada", v ? Theme.green : Theme.dim)
            ts._vpn = v
        } }
    }
    Timer { interval: 6000; running: true; repeat: true; triggeredOnStart: true; onTriggered: vpnP.running = true }

    // ── No molestar ──
    Connections {
        target: ts.notifs
        function onDndChanged() {
            if (ts.on("dnd")) ts.push("", "No molestar " + (ts.notifs.dnd ? "activado" : "desactivado"), ts.notifs.dnd ? Theme.yellow : Theme.dim)
        }
    }

    // ── Modo juego ──
    Connections {
        target: ts.gamemode
        function onOnChanged() {
            if (ts.on("gameMode")) ts.push("", "Modo juego " + (ts.gamemode.on ? "activado" : "desactivado"), ts.gamemode.on ? Theme.green : Theme.dim)
        }
    }

    // ── Ventana ──
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            readonly property bool mine: ts.shown && Hyprland.focusedMonitor?.name === modelData.name
            anchors { left: true; right: true; bottom: true }
            implicitHeight: 90
            margins { bottom: Theme.frameW; left: Theme.sidebarW; right: Theme.frameW }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            visible: true
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "toast"

            Item {
                id: card
                width: row.implicitWidth + 44
                height: 50
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                visible: opacity > 0.01
                opacity: win.mine ? 1 : 0
                transform: Translate { y: win.mine ? 0 : 30; Behavior on y { Anim { kind: "fastSpatial" } } }
                Behavior on opacity { NumberAnimation { duration: Theme.dur(100) } }

                Fused { edge: "bottom"; r: 20 }
                Row {
                    id: row
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -2
                    spacing: 10
                    Text { text: ts.glyph; color: ts.tint; font.family: Theme.mono; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: ts.message; color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
}
