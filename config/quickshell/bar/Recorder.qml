import QtQuick
import Quickshell
import Quickshell.Io

// Estado de la grabación de pantalla (la gestiona hypr/scripts/capture.sh).
// El script escribe ~/.cache/cubi/rec/state: "<recording|paused> <segundos> <epoch>".
Scope {
    id: rec

    property string status: "idle"            // idle · recording · paused
    property real base: 0                     // segundos acumulados en segmentos anteriores
    property real since: 0                    // epoch (s) del segmento en curso
    property real elapsed: 0
    readonly property bool active: status !== "idle"
    readonly property bool paused: status === "paused"
    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/capture.sh"

    function run(mode) { cmd.command = ["sh", script, mode]; cmd.running = true }
    function pause()  { run("rec-pause") }
    function resume() { run("rec-resume") }
    function stop()   { run("rec-stop") }
    function toggle() { if (paused) resume(); else pause() }

    function tick() {
        elapsed = status === "recording" ? base + Math.max(0, Date.now() / 1000 - since) : base
    }
    function fmt(s) {
        s = Math.floor(s)
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), x = s % 60
        const p = n => (n < 10 ? "0" : "") + n
        return (h > 0 ? h + ":" + p(m) : m) + ":" + p(x)
    }

    Process { id: cmd }

    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.cache/cubi/rec/state"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const f = text().trim().split(/\s+/)
            if (f.length >= 3 && (f[0] === "recording" || f[0] === "paused")) {
                rec.status = f[0]; rec.base = parseFloat(f[1]) || 0; rec.since = parseFloat(f[2]) || 0
            } else rec.status = "idle"
            rec.tick()
        }
        onLoadFailed: { rec.status = "idle"; rec.elapsed = 0 }
    }
    // el directorio de la sesión se crea y borra: reintenta cargar el estado
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: { if (rec.status === "idle") stateFile.reload(); rec.tick() }
    }

    // Si wf-recorder murió solo, cierra la sesión (une lo grabado hasta entonces)
    Process {
        id: alive
        command: ["pgrep", "-x", "wf-recorder"]
        onExited: code => { if (code !== 0 && rec.status === "recording") rec.stop() }
    }
    Timer { interval: 4000; running: rec.status === "recording"; repeat: true; onTriggered: alive.running = true }
}
