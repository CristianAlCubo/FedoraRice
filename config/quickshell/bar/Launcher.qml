import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: launcher

    // ── Tema (mismo que la barra) ───────────────────────────
    readonly property color bg:     Theme.bg
    readonly property color stroke: Theme.stroke
    readonly property color text:   Theme.text
    readonly property color dim:    Theme.dim
    readonly property color accent: Theme.accent
    readonly property string font:  Theme.font

    property bool open: false

    readonly property string home: Quickshell.env("HOME")
    readonly property string qsb: "qs -p " + home + "/.config/quickshell/bar ipc call "
    Process { id: sh }
    function run(cmd) { sh.command = ["sh", "-c", cmd]; sh.running = true }

    // ── Uso (apps lanzadas) para ordenar por frecuencia ──
    FileView { id: usage; path: launcher.home + "/.cache/rice/launcher.log"; printErrors: false }
    readonly property var counts: {
        const m = {}
        try { usage.text().split("\n").forEach(l => { if (l) m[l] = (m[l] || 0) + 1 }) } catch (e) {}
        return m
    }
    readonly property var favs: (Cfg.launcher.favourites ?? []).map(f => String(f).toLowerCase())
    function favRank(e) {
        const id = (e.id ?? "").toLowerCase(), n = e.name.toLowerCase()
        return favs.findIndex(f => id === f || id === f + ".desktop" || id.endsWith("." + f) || n === f)
    }
    function fuzzy(name, q) {           // ¿están las letras de q en orden dentro de name?
        let j = 0
        for (let i = 0; i < name.length && j < q.length; i++) if (name[i] === q[j]) j++
        return j === q.length
    }

    // ── Calculadora ──
    function calc(q) {
        let e = q.trim()
        if (e.startsWith("=")) e = e.slice(1)
        else if (!/[+\-*\/%^]/.test(e) && !/(sqrt|sin|cos|tan|log|ln|abs|pi)/.test(e)) return null
        e = e.replace(/,/g, ".").replace(/\^/g, "**").replace(/\bpi\b/g, "Math.PI").replace(/\be\b/g, "Math.E")
             .replace(/\bln\(/g, "Math.log(").replace(/\blog\(/g, "Math.log10(")
             .replace(/\b(sqrt|sin|cos|tan|abs)\(/g, "Math.$1(")
        if (!/^[\d\s+\-*\/%.()eMathPIEsqrtincoablgo]*$/.test(e) || /[a-zA-Z]/.test(e.replace(/Math\.(PI|E|sqrt|sin|cos|tan|abs|log10|log)/g, ""))) return null
        try {
            const v = Function('"use strict"; return (' + e + ')')()
            if (typeof v !== "number" || !isFinite(v)) return null
            return Math.round(v * 1e10) / 1e10
        } catch (err) { return null }
    }

    // ── Acciones (prefijo ">" o al escribir su nombre) ──
    FileView { id: themeIdx; path: launcher.home + "/.config/rice/themes/index.json"; blockLoading: true; printErrors: false }
    readonly property var themeList: { try { return JSON.parse(themeIdx.text()) } catch (e) { return [] } }
    readonly property var actions: {
        const A = (name, comment, glyph, kw, cmd) => ({ isAction: true, name: name, comment: comment, glyph: glyph, kw: kw, run: () => launcher.run(cmd) })
        const base = [
            A("Bloquear pantalla", "Hyprlock", "\uf023", "lock bloquear", home + "/.config/hypr/scripts/lock.sh"),
            A("Suspender", "Suspender el equipo", "\uf186", "sleep suspender dormir", "systemctl suspend"),
            A("Cerrar sesión…", "Abre el menú de sesión", "\uf2f5", "logout salir cerrar", qsb + "session open logout"),
            A("Reiniciar…", "Abre el menú de sesión", "\uf021", "reboot reiniciar", qsb + "session open reboot"),
            A("Apagar…", "Abre el menú de sesión", "\uf011", "shutdown poweroff apagar", qsb + "session open shutdown"),
            A("Menú de sesión", "Bloquear, salir, reiniciar, apagar", "\uf011", "session sesion", qsb + "session toggle"),
            A("Modo juego", "Activa o desactiva animaciones, blur y sombras", "\uf11b", "game juego gaming rendimiento", qsb + "gamemode toggle"),
            A("No molestar", "Alterna las notificaciones", "\uf1f6", "dnd molestar notificaciones", qsb + "notifications toggleDnd"),
            A("Captura de pantalla", "Pantalla completa", "\uf030", "screenshot captura pantalla", qsb + "dashboard capture shot-full"),
            A("Captura de región", "Selecciona un área", "\uf125", "screenshot captura region", qsb + "dashboard capture shot-region"),
            A("Grabar pantalla", "Video de la pantalla", "\uf03d", "record grabar video", qsb + "dashboard capture rec-full"),
            A("Fondos de pantalla", "Escritorio, bloqueo y login", "\uf03e", "wallpaper fondo", qsb + "settings toggle"),
            A("Centro de control", "Dashboard", "\uf2d0", "dashboard control centro", qsb + "dashboard toggle"),
            A("Panel de controles", "Ajustes rápidos y temas", "\uf1de", "controls controles ajustes", qsb + "controls toggle"),
            A("Sincronizar Archivos con el tema", "Actualiza los colores de Nautilus/GTK (reábrelo para verlos)", "\uf07b", "nautilus archivos gtk sincronizar tema",
              "python3 " + home + "/.config/rice/apply.py gtk >/dev/null 2>&1 && " + qsb + "toasts push '\uf07b' 'Archivos sincronizado con el tema (reábrelo para verlo)'"),
            A("Editar widgets", "Mover widgets del escritorio", "\uf0db", "widgets editar", qsb + "widgets edit"),
        ]
        const themes = themeList.map(t => A("Tema: " + t.name, t.description, "\udb80\udfd8", "tema theme color " + t.id,
            "python3 " + home + "/.config/rice/apply.py set " + t.id))
        return base.concat(themes)
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.open = !launcher.open }
        function show(): void   { launcher.open = true }
        function hide(): void   { launcher.open = false }
        function search(q: string): void { launcher.presetQuery = q; launcher.open = true }   // abre con texto: ">", "= 2+2", "nord"…
    }
    property string presetQuery: ""

    // ── Categorías ──────────────────────────────────────────
    readonly property var categories: [
        { id: "all",         label: "Todas" },
        { id: "Network",     label: "Internet" },
        { id: "Development", label: "Desarrollo" },
        { id: "AudioVideo",  label: "Multimedia" },
        { id: "Graphics",    label: "Gráficos" },
        { id: "Office",      label: "Oficina" },
        { id: "Game",        label: "Juegos" },
        { id: "Utility",     label: "Utilidades" },
        { id: "System",      label: "Sistema" }
    ]

    readonly property var allApps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    // Solo mostramos categorías que tengan al menos una app
    readonly property var activeCategories: categories.filter(c =>
        c.id === "all" || allApps.some(a => a.categories.indexOf(c.id) >= 0))

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            visible: launcher.open
                && Hyprland.focusedMonitor?.name === modelData.name

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            property string query: ""
            property string category: "all"

            readonly property var results: {
                let q = query.trim().toLowerCase()
                const out = []

                // Modo acciones: ">texto"
                if (q.startsWith(">")) {
                    q = q.slice(1).trim()
                    for (const a of launcher.actions) {
                        if (q === "" || (a.name + " " + a.kw).toLowerCase().includes(q)) out.push(a)
                    }
                    return out
                }

                // Calculadora
                const c = launcher.calc(q)
                if (c !== null) out.push({ isAction: true, name: "= " + c, comment: "Intro copia el resultado",
                    glyph: "\uf1ec", run: () => launcher.run("printf %s '" + c + "' | wl-copy") })

                for (const e of launcher.allApps) {
                    if (category !== "all" && e.categories.indexOf(category) < 0) continue
                    const cnt = launcher.counts[(e.id ?? "").replace(/[^\w.-]/g, "")] || 0
                    const fav = launcher.favRank(e)
                    if (q === "") { out.push({ e: e, s: 0, f: fav >= 0 ? fav : 999, c: -cnt }); continue }
                    const n = e.name.toLowerCase()
                    const hay = (n + " " + (e.genericName ?? "") + " " + (e.comment ?? "") + " "
                        + (e.keywords ?? []).join(" ")).toLowerCase()
                    let sc = -1
                    if (n.startsWith(q))        sc = 0
                    else if (n.includes(q))     sc = 1
                    else if (hay.includes(q))   sc = 2
                    else if (q.length >= 2 && launcher.fuzzy(n, q)) sc = 3
                    if (sc >= 0) out.push({ e: e, s: sc, f: fav >= 0 ? fav : 999, c: -cnt })
                }
                // Acciones cuyo nombre coincide (sin prefijo), tras las apps que empiezan igual
                if (q.length >= 2 && category === "all") {
                    for (const a of launcher.actions)
                        if ((a.name + " " + a.kw).toLowerCase().includes(q)) out.push({ e: a, s: 1.5, f: 999, c: 0 })
                }
                out.sort((a, b) => a.s - b.s || a.f - b.f || a.c - b.c)
                const apps = out.map(x => x.e ?? x)
                return (c !== null) ? apps : apps
            }

            onVisibleChanged: if (visible) {
                usage.reload()
                query = ""; category = "all"
                input.text = ""
                list.currentIndex = 0
                if (launcher.presetQuery !== "") { input.text = launcher.presetQuery; launcher.presetQuery = "" }
                input.forceActiveFocus()
            }

            function launch(entry) {
                if (!entry) return
                if (entry.isAction) entry.run()
                else {
                    entry.execute()
                    const id = (entry.id ?? "").replace(/[^\w.-]/g, "")
                    if (id !== "" && Cfg.launcher.useCounts !== false)
                        launcher.run("mkdir -p ~/.cache/rice && echo '" + id + "' >> ~/.cache/rice/launcher.log")
                }
                launcher.open = false
            }
            function cycleCategory(dir) {
                const cs = launcher.activeCategories
                let i = cs.findIndex(c => c.id === category)
                i = (i + dir + cs.length) % cs.length
                category = cs[i].id
                list.currentIndex = 0
            }

            // Click fuera cierra
            MouseArea {
                anchors.fill: parent
                onClicked: launcher.open = false
            }

            // Velo suave
            Rectangle {
                anchors.fill: parent
                color: Theme.scrim(0.28)
                opacity: win.visible ? 1 : 0
                Behavior on opacity { Anim { kind: "effects" } }
            }

            // ── Tarjeta ─────────────────────────────────
            Rectangle {
                id: card
                width: 720
                // Altura según resultados (como Caelestia): crece/encoge con rebote suave
                readonly property int rowH: 54
                property real listH: Math.max(1, Math.min(win.results.length, 8)) * rowH
                Behavior on listH { Anim { kind: "spatial" } }
                height: col.implicitHeight + 32
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: (Theme.sidebarW - Theme.frameW) / 2
                y: parent.height - height - Theme.frameW
                property real off: win.visible ? 0 : 1
                Behavior on off { Anim { kind: "spatial" } }
                opacity: Math.max(0, Math.min(1, 1 - off * 1.2))
                transform: Translate { y: card.off * (card.height + Theme.frameW) }
                color: "transparent"

                Fused { edge: "bottom"; r: 22 }

                MouseArea { anchors.fill: parent }  // no propaga el click de cierre

                ColumnLayout {
                    id: col
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    // Búsqueda
                    Rectangle {
                        Layout.fillWidth: true
                        height: 48
                        radius: 14
                        color: Theme.s2
                        border.width: 1
                        border.color: input.activeFocus
                            ? Qt.alpha(Theme.accent, 0.55) : launcher.stroke
                        Behavior on border.color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 12

                            // Lupa dibujada (sin fuentes de iconos)
                            Item {
                                width: 16; height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle {
                                    width: 11; height: 11; radius: 6
                                    color: "transparent"
                                    border.width: 1.8
                                    border.color: launcher.accent
                                }
                                Rectangle {
                                    x: 9; y: 12; width: 7; height: 1.8; radius: 1
                                    rotation: 45
                                    transformOrigin: Item.Left
                                    color: launcher.accent
                                }
                            }

                            TextInput {
                                id: input
                                width: parent.width - 28
                                anchors.verticalCenter: parent.verticalCenter
                                color: launcher.text
                                font.family: launcher.font
                                font.pixelSize: 16
                                selectionColor: launcher.accent
                                selectedTextColor: Theme.ink
                                clip: true
                                onTextChanged: { win.query = text; list.currentIndex = 0 }

                                Text {
                                    visible: !input.text
                                    text: "Buscar apps, > acciones, = calcular…"
                                    color: launcher.dim
                                    font: input.font
                                }

                                Keys.onPressed: ev => {
                                    if (ev.key === Qt.Key_Escape) {
                                        launcher.open = false
                                    } else if (ev.key === Qt.Key_Down
                                        || (ev.modifiers & Qt.ControlModifier && ev.key === Qt.Key_N)) {
                                        list.incrementCurrentIndex(); ev.accepted = true
                                    } else if (ev.key === Qt.Key_Up
                                        || (ev.modifiers & Qt.ControlModifier && ev.key === Qt.Key_P)) {
                                        list.decrementCurrentIndex(); ev.accepted = true
                                    } else if (ev.key === Qt.Key_Tab) {
                                        win.cycleCategory(1); ev.accepted = true
                                    } else if (ev.key === Qt.Key_Backtab) {
                                        win.cycleCategory(-1); ev.accepted = true
                                    } else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                                        win.launch(win.results[list.currentIndex]); ev.accepted = true
                                    }
                                }
                            }
                        }
                    }

                    // Chips de categoría
                    Flickable {
                        Layout.fillWidth: true
                        height: 30
                        contentWidth: chips.implicitWidth
                        clip: true
                        interactive: contentWidth > width

                        Row {
                            id: chips
                            spacing: 6
                            Repeater {
                                model: launcher.activeCategories
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool on: win.category === modelData.id
                                    height: 28
                                    width: chipText.implicitWidth + 24
                                    radius: 14
                                    color: on ? Qt.alpha(Theme.accent, 0.16)
                                        : chipMouse.containsMouse ? Theme.s3
                                        : Theme.s2
                                    border.width: 1
                                    border.color: on ? Qt.alpha(Theme.accent, 0.5) : "transparent"
                                    Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }

                                    Text {
                                        id: chipText
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: parent.on ? launcher.accent : launcher.dim
                                        font.family: launcher.font
                                        font.pixelSize: 12
                                        font.weight: parent.on ? Font.Medium : Font.Normal
                                    }
                                    MouseArea {
                                        id: chipMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            win.category = modelData.id
                                            list.currentIndex = 0
                                            input.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Resultados
                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.preferredHeight: card.listH
                        clip: true
                        spacing: 2
                        model: ScriptModel { values: win.results }
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds
                        highlightFollowsCurrentItem: false

                        // Transiciones por elemento (solo cambian los que entran/salen/se mueven)
                        add: Transition { Anim { properties: "opacity,scale"; from: 0; to: 1; kind: "effects" } }
                        remove: Transition { Anim { properties: "opacity,scale"; to: 0; kind: "effects" } }
                        displaced: Transition {
                            Anim { property: "y"; kind: "spatial" }
                            Anim { properties: "opacity,scale"; to: 1; kind: "effects" }
                        }

                        highlight: Rectangle {
                            y: list.currentItem ? list.currentItem.y : 0
                            height: list.currentItem ? list.currentItem.height : 0
                            Behavior on y { Anim { kind: "fastSpatial" } }
                            radius: 12
                            color: Qt.alpha(Theme.accent, 0.12)
                            border.width: 1
                            border.color: Qt.alpha(Theme.accent, 0.28)
                            Rectangle {   // barrita de acento
                                width: 3; height: 18; radius: 2
                                anchors.left: parent.left
                                anchors.leftMargin: 5
                                anchors.verticalCenter: parent.verticalCenter
                                color: launcher.accent
                            }
                        }

                        delegate: Item {
                            id: row
                            required property var modelData
                            required property int index
                            width: list.width
                            height: 52

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 18
                                anchors.rightMargin: 12
                                spacing: 14

                                Rectangle {   // acciones y calculadora: glifo en vez de icono
                                    visible: !!row.modelData.isAction
                                    width: 32; height: 32; radius: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.s3
                                    Text { anchors.centerIn: parent; text: row.modelData.glyph ?? ""
                                        font.family: Theme.mono; font.pixelSize: 16; color: Theme.accent }
                                }
                                Image {
                                    visible: !row.modelData.isAction
                                    width: 32; height: 32
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: row.modelData.isAction ? "" : Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                                    sourceSize: Qt.size(64, 64)
                                    smooth: true
                                    asynchronous: true
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 46
                                    spacing: 2
                                    Text {
                                        width: parent.width
                                        text: row.modelData.name
                                        elide: Text.ElideRight
                                        color: list.currentIndex === row.index
                                            ? Theme.text : launcher.text
                                        font.family: launcher.font
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                    }
                                    Text {
                                        width: parent.width
                                        visible: text !== ""
                                        text: row.modelData.comment || row.modelData.genericName || ""
                                        elide: Text.ElideRight
                                        color: launcher.dim
                                        font.family: launcher.font
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: list.currentIndex = row.index
                                onClicked: win.launch(row.modelData)
                            }
                        }

                        // Estado vacío
                        Text {
                            anchors.centerIn: parent
                            visible: win.results.length === 0
                            text: "Sin resultados"
                            color: launcher.dim
                            font.family: launcher.font
                            font.pixelSize: 13
                        }
                    }

                    // Pie con atajos
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 18
                        Repeater {
                            model: ["↑↓  navegar", "⇥  categoría", ">  acciones", "⏎  abrir", "esc  cerrar"]
                            delegate: Text {
                                required property string modelData
                                text: modelData
                                color: launcher.dim
                                opacity: 0.6
                                font.family: launcher.font
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }
    }
}
