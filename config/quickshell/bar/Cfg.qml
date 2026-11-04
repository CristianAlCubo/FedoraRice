pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Ajustes que no son de tema: ~/.config/rice/shell.json (clima, favoritos del lanzador, toasts). Se recarga en vivo.
Singleton {
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/rice/shell.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property var cfg: { try { return JSON.parse(file.text()) } catch (e) { return {} } }
    readonly property var weather:  cfg.weather  ?? ({})
    readonly property var launcher: cfg.launcher ?? ({})
    readonly property var toasts:   cfg.toasts   ?? ({})
}
