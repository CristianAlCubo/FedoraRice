pragma Singleton
import QtQuick
import Quickshell

// Resuelve el icono de una app a partir de la clase de su ventana (Hyprland).
Singleton {
    function icon(cls) {
        if (!cls) return ""
        const e = DesktopEntries.heuristicLookup(cls)
        const tries = [e ? e.icon : "", cls, cls.toLowerCase(), cls.split(".").pop().toLowerCase()]
        for (const t of tries) {
            if (!t) continue
            const p = Quickshell.iconPath(t, true)
            if (p) return p
        }
        return ""
    }
}
