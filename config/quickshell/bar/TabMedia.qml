import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Pestaña Multimedia: centro de reproducción.
Item {
    id: tab
    property bool active: false      // pestaña visible → actualiza la posición
    property bool focused: false     // el teclado está dentro de esta pestaña
    readonly property bool interactive: true

    // Atajos directos, sin entrar a la pestaña: Espacio pausa · N/P o Ctrl+←/→ cambian de pista
    function trackKey(k, m) {
        const p = player
        const shift = (m & (Qt.ShiftModifier | Qt.ControlModifier)) !== 0
        if (k === Qt.Key_N || k === Qt.Key_Period || (shift && k === Qt.Key_Right)) { if (p && p.canGoNext) p.next(); return true }
        if (k === Qt.Key_P || k === Qt.Key_Comma || (shift && k === Qt.Key_Left)) { if (p && p.canGoPrevious) p.previous(); return true }
        return false
    }
    function quickKey(k, m) {
        const p = player
        if (k === Qt.Key_Slash && isSpotify) { openSearch(); return true }
        if (k === Qt.Key_Space) { if (p && p.canTogglePlaying) p.togglePlaying(); return true }
        return trackKey(k, m)
    }

    // Dentro (↓): Espacio/Enter: pausa · ←/→: cambia de reproductor · N/P: pista siguiente/anterior
    function handleKey(k, m) {
        const p = player
        if (k === Qt.Key_Slash && isSpotify) { openSearch(); return true }
        if (k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Enter) {
            if (p && p.canTogglePlaying) p.togglePlaying()
            return true
        }
        if (trackKey(k, m)) return true
        if (k === Qt.Key_Left || k === Qt.Key_Right) {
            const n = players.length
            if (n > 1) picked = players[(players.indexOf(p) + (k === Qt.Key_Right ? 1 : n - 1)) % n]
            return true
        }
        return false
    }

    readonly property var players: Mpris.players.values

    // ── Buscador de Spotify (app de escritorio) ─────────────
    signal focusBack()
    readonly property bool isSpotify: player !== null &&
        (String(player.desktopEntry || "").toLowerCase().indexOf("spotify") >= 0 || player.identity === "Spotify")
    property bool searching: false
    property string query: ""
    property var results: []
    property int sel: 0
    property string sstate: "idle"        // idle · loading · done · nocreds · auth · net
    property string lastQ: ""
    readonly property string searchScript: Quickshell.env("HOME") + "/.config/hypr/scripts/spotify-search.py"

    function openSearch() {
        query = ""; results = []; sel = 0; sstate = "idle"; searching = true
        Qt.callLater(() => sInput.forceActiveFocus())
    }
    function closeSearch(refocus) {
        searching = false
        if (refocus !== false) focusBack()
    }
    function runSearch() {
        const q = query.trim()
        if (q.length < 2) { results = []; sstate = "idle"; return }
        if (sproc.running) return
        lastQ = q; sstate = "loading"
        sproc.command = ["python3", "-I", searchScript, q]
        sproc.running = true
    }
    function playResult(i) {
        if (i < 0 || i >= results.length || !player) return
        player.openUri(results[i].uri)
        closeSearch()
    }
    onActiveChanged: if (!active && searching) closeSearch(false)
    Timer { id: debounce; interval: 380; onTriggered: tab.runSearch() }
    Process {
        id: sproc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.length > 0)
                if (lines.length === 0) { tab.sstate = "net" }
                else if (lines[0] !== "OK") { tab.sstate = lines[0].slice(4); tab.results = [] }
                else {
                    tab.results = lines.slice(1).map(l => {
                        const f = l.split("\t")
                        return { uri: f[0], title: f[1], artist: f[2], album: f[3], art: f[4], ms: parseInt(f[5]) || 0 }
                    })
                    tab.sel = 0
                    tab.sstate = "done"
                }
                if (tab.query.trim() !== tab.lastQ) tab.runSearch()
            }
        }
    }
    property var picked: null
    readonly property var player: {
        if (picked && players.indexOf(picked) >= 0) return picked
        return players.find(p => p.isPlaying) ?? players[0] ?? null
    }
    // Nombre legible del origen: usa la URL de la pestaña si el reproductor es un navegador
    function labelFor(p) {
        const url = p.metadata && p.metadata["xesam:url"] ? String(p.metadata["xesam:url"]) : ""
        const sites = [
            [/music\.youtube\.com/, "YouTube Music"], [/youtube\.com|youtu\.be/, "YouTube"],
            [/open\.spotify\.com/, "Spotify Web"], [/twitch\.tv/, "Twitch"],
            [/netflix\.com/, "Netflix"], [/soundcloud\.com/, "SoundCloud"],
            [/primevideo\.com|amazon\./, "Prime Video"], [/disneyplus\.com/, "Disney+"],
            [/vimeo\.com/, "Vimeo"], [/bandcamp\.com/, "Bandcamp"]
        ]
        for (const s of sites) if (s[0].test(url)) return s[1]
        let id = (p.identity || "Reproductor").replace(/^Mozilla\s+/i, "")
        return id.charAt(0).toUpperCase() + id.slice(1)
    }
    function fmt(s) {
        s = Math.max(0, Math.floor(s))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }
    Timer {
        interval: 1000; repeat: true
        running: tab.active && tab.player && tab.player.isPlaying
        onTriggered: tab.player.positionChanged()
    }

    // Fondo: portada difuminada
    Rectangle {
        anchors.fill: parent
        radius: 26
        color: Theme.bgSoft
        border.width: 1
        border.color: Theme.stroke
        clip: true
        Image {
            anchors.fill: parent
            source: tab.player ? tab.player.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.2
            visible: status === Image.Ready
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64; saturation: 0.5 }
        }
    }

    // ── Sin reproductor ─────────────────────────────────────
    ColumnLayout {
        visible: tab.player === null
        anchors.centerIn: parent
        spacing: 12
        Icon {
            Layout.alignment: Qt.AlignHCenter
            name: "multimedia-player"; size: 40; color: Theme.fade(0.16)
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Nada reproduciéndose"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 14
        }
    }

    onPlayerChanged: { swapAnim.restart(); if (searching && !isSpotify) closeSearch(false) }
    ParallelAnimation {
        id: swapAnim
        NumberAnimation { target: playerView; property: "opacity"; from: 0; to: 1; duration: Theme.dur(320); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard }
        NumberAnimation { target: playerView; property: "scale"; from: 0.965; to: 1; duration: Theme.dur(380); easing.type: Easing.OutBack; easing.overshoot: 0.8 }
    }

    // ── Reproductor ─────────────────────────────────────────
    RowLayout {
        id: playerView
        visible: tab.player !== null
        anchors.fill: parent
        anchors.margins: 28
        spacing: 28

        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            Layout.maximumWidth: 316

            Rectangle { anchors.fill: parent; radius: 28; color: Theme.s2 }
            Image {
                id: art
                anchors.fill: parent
                source: tab.player ? tab.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: artMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
            }
            Rectangle { id: artMask; anchors.fill: parent; radius: 28; visible: false; layer.enabled: true }
            Icon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                name: "multimedia-player"; size: 54; color: Theme.fade(0.18)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            // ── Selector: solo iconos, con indicador deslizante ──
            RowLayout {
              Layout.fillWidth: true
              spacing: 8
            Rectangle {
                id: switcher
                visible: tab.players.length > 0
                implicitHeight: 48
                implicitWidth: swRow.implicitWidth + 10
                radius: 24
                color: Theme.scrim(0.28)
                border.width: 1
                border.color: tab.focused && tab.players.length > 1 ? Theme.accentLine : Theme.stroke

                Rectangle {   // indicador que se desliza hacia el reproductor elegido
                    readonly property var cur: swRep.count > 0 ? swRep.itemAt(tab.players.indexOf(tab.player)) : null
                    visible: cur !== null
                    y: 5; width: 38; height: 38; radius: 19
                    x: cur ? 5 + cur.x : 5
                    color: Theme.accentSoft
                    border.width: 1
                    border.color: Theme.accentLine
                    Behavior on x { NumberAnimation { duration: Theme.dur(320); easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                }

                Row {
                    id: swRow
                    x: 5; y: 5
                    spacing: 4
                    Repeater {
                        id: swRep
                        model: tab.players
                        delegate: Item {
                            id: chip
                            required property var modelData
                            readonly property bool cur: tab.player === modelData
                            readonly property string site: tab.labelFor(modelData)
                            width: 38; height: 38
                            scale: chipM.pressed ? 0.9 : (cur ? 1.0 : (chipM.containsMouse ? 1.08 : 0.92))
                            opacity: cur || chipM.containsMouse ? 1 : 0.62
                            Behavior on scale { NumberAnimation { duration: Theme.dur(180); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard } }
                            Behavior on opacity { NumberAnimation { duration: Theme.dur(180) } }

                            // Logo dibujado para los sitios conocidos
                            Canvas {
                                id: brand
                                anchors.centerIn: parent
                                width: 22; height: 22
                                visible: kind !== ""
                                readonly property string kind: /YouTube/.test(chip.site) ? "yt"
                                                             : /Spotify/.test(chip.site) ? "sp" : ""
                                onKindChanged: requestPaint()
                                onPaint: {
                                    const c = getContext("2d"); c.reset()
                                    if (kind === "yt") {
                                        c.fillStyle = chip.site === "YouTube Music" ? "#ff3d3d" : "#ff2d2d"
                                        c.beginPath(); c.roundedRect(0, 4, 22, 14, 4.5, 4.5); c.fill()
                                        c.fillStyle = "#ffffff"
                                        c.beginPath(); c.moveTo(9, 8); c.lineTo(15, 11); c.lineTo(9, 14); c.closePath(); c.fill()
                                    } else if (kind === "sp") {
                                        c.fillStyle = "#1ed760"
                                        c.beginPath(); c.arc(11, 11, 11, 0, Math.PI * 2); c.fill()
                                        c.strokeStyle = "#0b1a10"; c.lineCap = "round"
                                        const arcs = [[6.2, 7.4, 2.2], [5.4, 11.0, 2.0], [4.7, 14.4, 1.7]]
                                        for (const a of arcs) {
                                            c.lineWidth = a[2]; c.beginPath()
                                            c.moveTo(a[0], a[1] - 0.4)
                                            c.quadraticCurveTo(11, a[1] - 3.2, 16.8 - (a[1] - 7.4) * 0.12, a[1] - 0.4)
                                            c.stroke()
                                        }
                                    }
                                }
                            }
                            // Icono de la app para el resto
                            Image {
                                id: appIcon
                                anchors.centerIn: parent
                                width: 22; height: 22
                                visible: brand.kind === "" && status === Image.Ready
                                sourceSize: Qt.size(44, 44)
                                source: chip.modelData.desktopEntry
                                        ? Quickshell.iconPath(chip.modelData.desktopEntry, true) : ""
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: brand.kind === "" && appIcon.status !== Image.Ready
                                name: "multimedia-player"; size: 18
                                color: chip.cur ? Theme.accent : Theme.dim
                            }

                            // Sonando: punto que late
                            Rectangle {
                                visible: chip.modelData.isPlaying
                                width: 8; height: 8; radius: 4
                                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 1; bottomMargin: 1 }
                                color: Theme.accent
                                border.width: 2
                                border.color: Theme.bg
                                SequentialAnimation on opacity {
                                    running: chip.modelData.isPlaying && tab.active
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.35; duration: Theme.dur(700); easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0;  duration: Theme.dur(700); easing.type: Easing.InOutSine }
                                }
                            }

                            MouseArea { id: chipM; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: tab.picked = chip.modelData }

                            // Nombre solo al pasar el cursor
                            Rectangle {
                                visible: opacity > 0.01
                                opacity: chipM.containsMouse ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.dur(140) } }
                                y: parent.height + 6
                                x: (parent.width - width) / 2
                                width: tipT.implicitWidth + 18; height: 24; radius: 12
                                color: Theme.bg
                                border.width: 1; border.color: Theme.stroke
                                z: 10
                                Text { id: tipT; anchors.centerIn: parent; text: chip.site
                                    color: Theme.text; font.family: Theme.font; font.pixelSize: 11 }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Buscar en Spotify (atajo: /)
            Rectangle {
                visible: tab.isSpotify
                implicitWidth: 48; implicitHeight: 48; radius: 24
                color: sbm.containsMouse ? Theme.accentSoft : Theme.scrim(0.28)
                border.width: 1
                border.color: sbm.containsMouse ? Theme.accentLine : Theme.stroke
                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                Canvas {
                    anchors.centerIn: parent
                    width: 18; height: 18
                    property color col: sbm.containsMouse ? Theme.accent : Theme.text
                    onColChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d"); c.reset()
                        c.strokeStyle = col; c.lineWidth = 2; c.lineCap = "round"
                        c.beginPath(); c.arc(7.5, 7.5, 5.2, 0, Math.PI * 2); c.stroke()
                        c.beginPath(); c.moveTo(11.5, 11.5); c.lineTo(16, 16); c.stroke()
                    }
                }
                MouseArea { id: sbm; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: tab.openSearch() }
            }
            }

            Item { Layout.fillHeight: true }

            Text {
                Layout.fillWidth: true
                text: tab.player ? (tab.player.trackTitle || "Sin título") : ""
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 24
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: tab.player ? tab.player.trackArtist : ""
                elide: Text.ElideRight
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 15
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: tab.player ? tab.player.trackAlbum : ""
                elide: Text.ElideRight
                color: Theme.fade(0.3)
                font.family: Theme.font
                font.pixelSize: 12
            }

            Item { Layout.preferredHeight: 8 }

            ColumnLayout {
                Layout.fillWidth: true
                visible: tab.player && tab.player.lengthSupported && tab.player.length > 0
                spacing: 2
                Slider {
                    Layout.fillWidth: true
                    implicitHeight: 16
                    interactive: tab.player ? tab.player.canSeek : false
                    value: tab.player && tab.player.length > 0 ? tab.player.position / tab.player.length : 0
                    onMoved: v => { if (tab.player && tab.player.canSeek) tab.player.position = v * tab.player.length }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: tab.player ? tab.fmt(tab.player.position) : ""
                        color: Theme.dim
                        font.family: Theme.font; font.pixelSize: 11; font.features: { "tnum": 1 }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: tab.player ? tab.fmt(tab.player.length) : ""
                        color: Theme.dim
                        font.family: Theme.font; font.pixelSize: 11; font.features: { "tnum": 1 }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                spacing: 30

                Icon {
                    name: "media-skip-backward"; size: 24
                    color: !tab.player || !tab.player.canGoPrevious ? Theme.fade(0.2)
                           : pm.containsMouse ? Theme.accent : Theme.text
                    MouseArea { id: pm; anchors.fill: parent; anchors.margins: -10; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (tab.player && tab.player.canGoPrevious) tab.player.previous() }
                }
                Rectangle {
                    implicitWidth: 58; implicitHeight: 58; radius: 29
                    color: Theme.accent
                    scale: ppm.pressed ? 0.94 : (ppm.containsMouse ? 1.05 : 1)
                    Behavior on scale { NumberAnimation { duration: Theme.dur(110) } }
                    Icon {
                        anchors.centerIn: parent
                        name: tab.player && tab.player.isPlaying ? "media-playback-pause" : "media-playback-start"
                        size: 26; color: Theme.ink
                    }
                    FocusRing { shown: tab.focused; anchors.margins: -6 }
                    MouseArea { id: ppm; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (tab.player && tab.player.canTogglePlaying) tab.player.togglePlaying() }
                }
                Icon {
                    name: "media-skip-forward"; size: 24
                    color: !tab.player || !tab.player.canGoNext ? Theme.fade(0.2)
                           : nm.containsMouse ? Theme.accent : Theme.text
                    MouseArea { id: nm; anchors.fill: parent; anchors.margins: -10; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (tab.player && tab.player.canGoNext) tab.player.next() }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
    // ── Panel de búsqueda ───────────────────────────────────
    Rectangle {
        id: searchPanel
        anchors.fill: parent
        radius: 26
        color: Theme.bg
        border.width: 1; border.color: Theme.stroke
        opacity: tab.searching ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.dur(160) } }

        ColumnLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48; radius: 24
                color: Theme.s2
                border.width: 1; border.color: Theme.accentLine

                Canvas {
                    x: 18; anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18
                    onPaint: {
                        const c = getContext("2d"); c.reset()
                        c.strokeStyle = Theme.accent; c.lineWidth = 2; c.lineCap = "round"
                        c.beginPath(); c.arc(7.5, 7.5, 5.2, 0, Math.PI * 2); c.stroke()
                        c.beginPath(); c.moveTo(11.5, 11.5); c.lineTo(16, 16); c.stroke()
                    }
                }
                TextInput {
                    id: sInput
                    anchors { left: parent.left; leftMargin: 50; right: parent.right; rightMargin: 52; verticalCenter: parent.verticalCenter }
                    text: tab.query
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.ink
                    font.family: Theme.font; font.pixelSize: 16
                    clip: true
                    onTextChanged: { tab.query = text; debounce.restart() }
                    Keys.onEscapePressed: tab.closeSearch()
                    Keys.onDownPressed: if (tab.results.length > 0) tab.sel = Math.min(tab.results.length - 1, tab.sel + 1)
                    Keys.onUpPressed: tab.sel = Math.max(0, tab.sel - 1)
                    Keys.onReturnPressed: tab.playResult(tab.sel)
                    Keys.onEnterPressed: tab.playResult(tab.sel)
                    Text {
                        visible: sInput.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Buscar canciones en Spotify…"
                        color: Theme.dim
                        font: sInput.font
                    }
                }
                Rectangle {
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    width: 32; height: 32; radius: 16
                    color: scm.containsMouse ? Theme.bgHover : "transparent"
                    Icon { anchors.centerIn: parent; name: "window-close"; size: 13; color: Theme.dim }
                    MouseArea { id: scm; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor; onClicked: tab.closeSearch() }
                }
            }

            ListView {
                id: resList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 3
                boundsBehavior: Flickable.StopAtBounds
                model: tab.results
                currentIndex: tab.sel
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool cur: tab.sel === index
                    width: ListView.view.width
                    height: 54; radius: 18
                    color: cur ? Theme.accentSoft : (rm.containsMouse ? Theme.bgHover : "transparent")
                    border.width: cur ? 1 : 0; border.color: Theme.accentLine
                    Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 16 }
                        spacing: 12
                        Rectangle {
                            implicitWidth: 40; implicitHeight: 40; radius: 10
                            color: Theme.s2; clip: true
                            Image {
                                anchors.fill: parent
                                source: row.modelData.art
                                sourceSize: Qt.size(80, 80)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.title
                                elide: Text.ElideRight
                                color: row.cur ? Theme.accent : Theme.text
                                font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Medium
                            }
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.artist + " · " + row.modelData.album
                                elide: Text.ElideRight
                                color: Theme.dim
                                font.family: Theme.font; font.pixelSize: 12
                            }
                        }
                        Text {
                            text: tab.fmt(row.modelData.ms / 1000)
                            color: Theme.dim
                            font.family: Theme.font; font.pixelSize: 12; font.features: { "tnum": 1 }
                        }
                    }
                    MouseArea {
                        id: rm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: tab.sel = row.index
                        onClicked: tab.playResult(row.index)
                    }
                }

                // Estados vacíos / errores
                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 60
                    visible: tab.results.length === 0
                    spacing: 6
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        color: tab.sstate === "net" || tab.sstate === "auth" ? Theme.danger : Theme.dim
                        font.family: Theme.font; font.pixelSize: 14
                        text: tab.sstate === "loading" ? "Buscando…"
                            : tab.sstate === "done" ? "Sin resultados"
                            : tab.sstate === "nocreds" ? "Falta conectar la API de Spotify"
                            : tab.sstate === "auth" ? "Las credenciales de Spotify no son válidas"
                            : tab.sstate === "net" ? "No se pudo conectar con Spotify"
                            : tab.sstate.indexOf("http") === 0 ? "Spotify respondió con un error (" + tab.sstate.slice(4) + ")"
                            : "Escribe para buscar · ↑↓ elegir · Enter reproducir · Esc cerrar"
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: tab.sstate === "nocreds"
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        color: Theme.dim
                        font.family: Theme.font; font.pixelSize: 12
                        text: "Crea una app gratis en developer.spotify.com/dashboard y pega su Client ID y Client Secret en ~/.config/hypr/spotify-api.json"
                    }
                }
            }
        }
    }
}
