import QtQuick
import Quickshell
import Quickshell.Io

// Modo juego: apaga animaciones, blur, sombras y huecos de Hyprland (scripts/gamemode.sh).
Scope {
    id: gm
    property bool on: false
    signal changed(bool on)
    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/gamemode.sh"

    function toggle() { run(on ? "off" : "on") }
    function run(mode) { cmd.command = ["sh", script, mode]; cmd.running = true }
    Process { id: cmd; onExited: stat.running = true }
    Process {
        id: stat
        command: ["sh", gm.script, "status"]
        running: true
        stdout: StdioCollector { onStreamFinished: {
            const v = text.trim() === "on"
            if (v !== gm.on) { const first = gm._init; gm.on = v; if (first) gm.changed(v) }
            gm._init = true
        } }
    }
    property bool _init: false

    IpcHandler {
        target: "gamemode"
        function toggle(): void { gm.toggle() }
        function enable(): void { gm.run("on") }
        function disable(): void { gm.run("off") }
    }
}
