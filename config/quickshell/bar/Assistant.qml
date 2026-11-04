import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// Asistente de escritorio (Nexora + avatar 3D): estado, botón de la barra y panel de ajustes.
// La ventana del avatar es una ventana web (Chrome --app) que gestiona assistant.sh; aquí solo
// viven los ajustes (claves, modelo y voz) y el estado de los servicios.
//   qs ipc call assistant toggle | show | hide | settings
Scope {
    id: me

    property bool open: false
    readonly property string home: Quickshell.env("HOME")
    readonly property string script: home + "/.config/hypr/scripts/assistant.sh"
    readonly property string confPath: home + "/.config/nexora/env"

    // ── Estado de los servicios (lo refresca assistant.sh status) ──────
    property var stat: ({})
    readonly property bool configured: stat.configured === "yes"
    readonly property bool apiUp: stat.api === "active"
    readonly property bool kokoroUp: stat.kokoro === "up"
    readonly property bool qwenUp: stat.qwen === "up"
    readonly property bool voicesUp: stat.voices === "up"
    readonly property bool llmUp: stat.llm === "up"
    readonly property var qwenVoices: (stat.qwen_voices || "") === "" ? [] : stat.qwen_voices.split(",")

    // ── Formulario ─────────────────────────────────────────
    property var cfg: ({})              // contenido original del env (se conserva lo que no se edita)
    property string orKey: ""
    property string gemKey: ""
    property string llmModel: ""
    property string llmProvider: "openrouter"   // openrouter | local
    property string llmBaseUrl: "http://127.0.0.1:8088/v1"
    property string llmModelPath: ""            // GGUF que sirve llama-server (solo local)
    property string llmCtx: ""                  // contexto en tokens (vacío = el del modelo)
    property string llmReasoning: "auto"        // auto | off | low | medium | high
    property string ttsMode: "gemini"   // gemini | kokoro | qwen | piper | supertonic | off
    property string gemModel: ""
    property string gemVoice: ""
    property string kokVoice: ""
    property string kokUrl: ""
    property string qwenUrl: ""
    property string qwenVoice: ""
    property string qwenLang: ""
    property string qwenInstr: ""
    property string voicesUrl: ""
    property string voicesLang: ""
    property var voicesItems: []        // [{id, label}] de VOICES_LIST
    property string voicesActive: ""    // la primera de la lista al guardar

    // Navegación: categoría lateral + pestaña de cada categoría.
    property string cat: "general"
    property var subSel: ({ general: "claves", voz: "motor", servicios: "estado" })
    readonly property string sub: subSel[cat]
    readonly property var cats: [["general", "General"], ["voz", "Voz"], ["servicios", "Servicios"]]
    readonly property var tabsOf: ({
        general: [["claves", "Claves"], ["modelo", "Modelo"]],
        voz: [["motor", "Motor"], ["gemini", "Gemini"], ["kokoro", "Kokoro"], ["qwen", "Qwen"], ["piper", "Piper"], ["supertonic", "Supertonic"]],
        servicios: [["estado", "Estado"]]
    })
    function setSub(c, t) { const o = Object.assign({}, subSel); o[c] = t; subSel = o }
    function page(c, t) { return cat === c && sub === t }
    function engineOfTab(t) { return t }
    // Piper y Supertonic comparten servidor y VOICES_LIST; el motor de una voz sale de su id.
    function engineOfVoice(id) { return id.indexOf("piper-") === 0 ? "piper" : "supertonic" }
    function voicesFor(engine) { return voicesItems.filter(i => engineOfVoice(i.id) === engine) }
    function pickEngine(e) {
        ttsMode = e; dirty = true
        if ((e === "piper" || e === "supertonic") && engineOfVoice(voicesActive) !== e) {
            const l = voicesFor(e)
            if (l.length > 0) voicesActive = l[0].id
        }
    }
    readonly property bool isVoices: ttsMode === "piper" || ttsMode === "supertonic"
    property bool showOr: false
    property bool showGem: false
    property string message: ""
    property bool messageErr: false
    property bool busy: false
    property bool dirty: false

    readonly property bool needGemini: ttsMode === "gemini" && gemKey.trim() === ""
    readonly property bool canSave: !busy && llmModel.trim() !== ""
        && !(llmProvider === "local" && (llmBaseUrl.trim() === "" || llmModelPath.trim() === ""))
        && !(ttsMode === "gemini" && gemModel.trim() === "")
        && !(ttsMode === "qwen" && qwenVoice.trim() === "")
        && !(isVoices && voicesFor(ttsMode).length === 0)
    readonly property var geminiVoices: ["Kore", "Puck", "Zephyr", "Aoede", "Charon", "Leda", "Fenrir"]
    readonly property var kokoroVoices: ["ef_dora", "em_alex", "em_santa"]

    IpcHandler {
        target: "assistant"
        function toggle(): void   { me.run(["toggle"]) }
        function show(): void     { me.run(["show"]) }
        function hide(): void     { me.run(["hide"]) }
        function settings(): void { me.open = true }
        function voice(): void    { me.cat = "voz"; me.open = true }
        function tab(c: string, t: string): void { me.cat = c; me.setSub(c, t); me.open = true }
        function close(): void    { me.open = false }
        function save(): void     { me.save() }
    }

    function run(args) { runProc.command = [me.script].concat(args); runProc.running = true }

    onOpenChanged: {
        if (open) {
            message = ""; dirty = false; showOr = false; showGem = false
            initProc.running = true
            statProc.running = true
        }
    }

    function loadFrom(text) {
        const c = {}
        for (const line of text.split("\n")) {
            const i = line.indexOf("=")
            if (i > 0 && line[0] !== "#") c[line.slice(0, i)] = line.slice(i + 1)
        }
        cfg = c
        orKey = c.OPENROUTER_API_KEY || ""
        gemKey = c.GEMINI_API_KEY || ""
        llmModel = c.LLM_MODEL || ""
        llmProvider = c.LLM_PROVIDER === "local" ? "local" : "openrouter"
        llmBaseUrl = c.LLM_BASE_URL || "http://127.0.0.1:8088/v1"
        llmModelPath = c.LLM_MODEL_PATH || ""
        llmCtx = c.LLM_CONTEXT_TOKENS || ""
        llmReasoning = ["off", "low", "medium", "high"].indexOf(c.LLM_REASONING) >= 0 ? c.LLM_REASONING : "auto"
        gemModel = c.TTS_MODEL || "gemini-3.8-flash-lite-tts"
        gemVoice = c.TTS_VOICE || "Kore"
        kokVoice = c.KOKORO_VOICE || "ef_dora"
        kokUrl = c.KOKORO_BASE_URL || "http://127.0.0.1:8881"
        qwenUrl = c.QWEN_BASE_URL || "http://127.0.0.1:8890"
        qwenVoice = c.QWEN_VOICE || ""
        qwenLang = c.QWEN_LANGUAGE || "Spanish"
        qwenInstr = c.QWEN_INSTRUCTIONS || ""
        voicesUrl = c.VOICES_BASE_URL || "http://127.0.0.1:8891"
        voicesLang = c.VOICES_LANGUAGE || "Spanish"
        voicesItems = (c.VOICES_LIST || "").split(",").map(e => e.trim()).filter(e => e !== "").map(e => {
            const i = e.indexOf("|")
            return i < 0 ? { id: e, label: e } : { id: e.slice(0, i).trim(), label: e.slice(i + 1).trim() }
        })
        voicesActive = voicesItems.length > 0 ? voicesItems[0].id : ""
        ttsMode = c.TTS_ENABLED === "false" ? "off" : (["kokoro", "qwen"].indexOf(c.TTS_PROVIDER) >= 0 ? c.TTS_PROVIDER
                  : (c.TTS_PROVIDER === "voices" ? engineOfVoice(voicesActive) : "gemini"))
        dirty = false
    }

    function serialize() {
        const clean = v => String(v).replace(/[\r\n]/g, "").trim()
        const v = {
            OPENROUTER_API_KEY: clean(orKey), GEMINI_API_KEY: clean(gemKey), LLM_MODEL: clean(llmModel),
            LLM_PROVIDER: llmProvider, LLM_BASE_URL: clean(llmBaseUrl), LLM_MODEL_PATH: clean(llmModelPath),
            LLM_CONTEXT_TOKENS: clean(llmCtx).replace(/[^0-9]/g, ""), LLM_REASONING: llmReasoning,
            LLM_FLAVOR: "llamacpp",
            TTS_ENABLED: ttsMode === "off" ? "false" : "true",
            TTS_PROVIDER: ["kokoro", "qwen"].indexOf(ttsMode) >= 0 ? ttsMode : (isVoices ? "voices" : "gemini"),
            TTS_MODEL: clean(gemModel), TTS_VOICE: clean(gemVoice),
            KOKORO_BASE_URL: clean(kokUrl), KOKORO_VOICE: clean(kokVoice),
            QWEN_BASE_URL: clean(qwenUrl), QWEN_VOICE: clean(qwenVoice), QWEN_LANGUAGE: clean(qwenLang), QWEN_INSTRUCTIONS: clean(qwenInstr),
            VOICES_BASE_URL: clean(voicesUrl), VOICES_LANGUAGE: clean(voicesLang)
        }
        if (voicesItems.length > 0) {
            const ordered = voicesItems.filter(i => i.id === voicesActive).concat(voicesItems.filter(i => i.id !== voicesActive))
            v.VOICES_LIST = ordered.map(i => clean(i.id) + "|" + clean(i.label).replace(/,/g, " ")).join(",")
        }
        const seen = {}
        const out = []
        for (const line of (confText || "").split("\n")) {
            const i = line.indexOf("=")
            const k = i > 0 && line[0] !== "#" ? line.slice(0, i) : ""
            if (k !== "" && v[k] !== undefined) { out.push(k + "=" + v[k]); seen[k] = true }
            else if (line !== "") out.push(line)
        }
        for (const k in v) if (!seen[k]) out.push(k + "=" + v[k])
        return out.join("\n") + "\n"
    }
    property string confText: ""

    function save() {
        if (!canSave) return
        busy = true; messageErr = false
        message = "Guardando y reiniciando el asistente…"
        saveProc.environment = { "NEXORA_ENV_TEXT": serialize() }
        saveProc.running = true
    }

    // ── Procesos ────────────────────────────────────────────
    Process { id: runProc }
    Process { id: initProc; command: [me.script, "init"]; onExited: readProc.running = true }
    Process {
        id: readProc
        command: ["cat", me.confPath]
        stdout: StdioCollector { onStreamFinished: { me.confText = text; me.loadFrom(text) } }
    }
    Process {
        id: statProc
        command: [me.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = {}
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0) s[line.slice(0, i)] = line.slice(i + 1)
                }
                me.stat = s
            }
        }
    }
    Process {
        id: saveProc
        command: ["sh", "-c",
            "umask 077; f=\"$HOME/.config/nexora/env\"; printf '%s' \"$NEXORA_ENV_TEXT\" > \"$f.tmp\" && mv \"$f.tmp\" \"$f\" && chmod 600 \"$f\" && " +
            "\"$HOME/.config/hypr/scripts/assistant.sh\" apply"]
        onExited: code => {
            me.busy = false
            if (code === 0) {
                me.confText = me.serialize(); me.dirty = false
                me.messageErr = false
                me.message = me.orKey.trim() === "" ? "Guardado. Falta la clave de OpenRouter para arrancar."
                                                     : "Guardado. El asistente se reinició con la nueva configuración."
            } else { me.messageErr = true; me.message = "No se pudo guardar (código " + code + ")" }
            statProc.running = true
        }
    }
    Process {
        id: testProc
        onExited: code => { me.message = code === 0 ? "" : "No se pudo reproducir la voz (¿está el servidor en marcha?)"; me.messageErr = code !== 0 }
    }
    Process {
        id: kokProc
        onExited: code => {
            me.busy = false
            me.messageErr = code !== 0
            me.message = code === 0 ? "Listo." : "Falló la operación (código " + code + ")"
            statProc.running = true
        }
    }
    Timer { interval: 2500; running: me.open; repeat: true; onTriggered: statProc.running = true }
    // El indicador de la barra se mantiene al día aunque el panel esté cerrado.
    Timer { interval: 8000; running: !me.open; repeat: true; triggeredOnStart: true; onTriggered: statProc.running = true }

    function testVoice(engine, voice) {
        message = "Reproduciendo muestra…"; messageErr = false
        testProc.command = [script, "voice-test", engine, voice]
        testProc.running = true
    }

    function kokoro(action) {
        busy = true; messageErr = false
        message = action === "kokoro-install" ? "Descargando la imagen de Kokoro (puede tardar unos minutos)…" : "Procesando…"
        kokProc.command = [script, action]
        kokProc.running = true
    }

    // ── Ventana ─────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            visible: me.open && Hyprland.focusedMonitor?.name === modelData.name

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                color: Theme.scrim(0.42)
                opacity: win.visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.dur(200) } }
            }
            MouseArea { anchors.fill: parent; onClicked: me.open = false }

            FocusScope {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: ev => {
                    if (ev.key === Qt.Key_Escape) { me.open = false; ev.accepted = true }
                    else if ((ev.modifiers & Qt.ControlModifier) && (ev.key === Qt.Key_Return || ev.key === Qt.Key_S)) {
                        me.save(); ev.accepted = true
                    }
                }
            }

            // ── Componentes ─────────────────────────────────
            component Section: ColumnLayout {
                property string title
                property string hint
                Layout.fillWidth: true
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: parent.parent.title.toUpperCase()
                        color: Theme.dim
                        font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: parent.parent.hint
                        color: Theme.dim; elide: Text.ElideRight
                        font.family: Theme.font; font.pixelSize: 11
                    }
                }
            }

            component Field: Rectangle {
                id: fld
                property string label
                property alias value: input.text
                property string placeholder
                property bool secret: false
                property bool revealed: false
                property bool warn: false
                signal edited()
                signal revealToggled()

                Layout.fillWidth: true
                implicitHeight: 52
                radius: 16
                color: Theme.bgSoft
                border.width: 1
                border.color: input.activeFocus ? Theme.accentLine : (fld.warn ? Qt.alpha(Theme.danger, 0.5) : "transparent")
                Behavior on border.color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }

                Text {
                    id: lbl
                    anchors { left: parent.left; leftMargin: 16; top: parent.top; topMargin: 7 }
                    text: fld.label
                    color: Theme.dim
                    font.family: Theme.font; font.pixelSize: 10; font.weight: Font.Medium; font.letterSpacing: 0.6
                }
                TextInput {
                    id: input
                    anchors { left: parent.left; leftMargin: 16; right: eye.visible ? eye.left : parent.right; rightMargin: 12
                              bottom: parent.bottom; bottomMargin: 8 }
                    color: Theme.text
                    selectionColor: Theme.accent; selectedTextColor: Theme.ink
                    selectByMouse: true
                    clip: true
                    font.family: Theme.font; font.pixelSize: 14
                    echoMode: fld.secret && !fld.revealed ? TextInput.Password : TextInput.Normal
                    passwordCharacter: "•"
                    onTextEdited: { me.dirty = true; fld.edited() }
                    Text {
                        visible: input.text === ""
                        text: fld.placeholder
                        color: Theme.fade(0.22)
                        font: input.font
                    }
                }
                Item {
                    id: eye
                    visible: fld.secret
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    width: 32; height: 32
                    Canvas {
                        anchors.centerIn: parent
                        width: 18; height: 18
                        property bool on: fld.revealed
                        property color tint: eyeM.containsMouse ? Theme.text : Theme.dim
                        onOnChanged: requestPaint()
                        onTintChanged: requestPaint()
                        onPaint: {
                            const c = getContext("2d"); c.reset()
                            c.strokeStyle = tint; c.lineWidth = 1.6; c.lineCap = "round"; c.lineJoin = "round"
                            c.beginPath(); c.moveTo(1.5, 9)
                            c.quadraticCurveTo(9, -0.5, 16.5, 9); c.quadraticCurveTo(9, 18.5, 1.5, 9); c.stroke()
                            c.beginPath(); c.arc(9, 9, 2.6, 0, Math.PI * 2); c.stroke()
                            if (!on) { c.beginPath(); c.moveTo(3, 15); c.lineTo(15, 3); c.stroke() }
                        }
                    }
                    MouseArea {
                        id: eyeM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fld.revealToggled()
                    }
                }
            }

            component Chip: Rectangle {
                id: chip
                property string label
                property bool checked: false
                property bool enabledChip: true
                signal clicked()
                implicitHeight: 38
                implicitWidth: chipText.implicitWidth + 28
                radius: 19
                opacity: enabledChip ? 1 : 0.4
                color: checked ? Theme.accentSoft : (chipM.containsMouse ? Theme.bgHover : Theme.bgSoft)
                border.width: 1
                border.color: checked ? Theme.accentLine : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: chip.label
                    color: chip.checked ? Theme.accent : Theme.text
                    font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium
                }
                MouseArea {
                    id: chipM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (chip.enabledChip) chip.clicked()
                }
            }

            component Pill: Row {
                property string label
                property color tint: Theme.dim
                spacing: 6
                Rectangle { width: 8; height: 8; radius: 4; color: parent.tint; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: parent.label
                    color: Theme.dim
                    font.family: Theme.font; font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            component Btn: Rectangle {
                id: btn
                property string label
                property bool primary: false
                property bool enabledBtn: true
                signal clicked()
                implicitHeight: 40
                implicitWidth: btnText.implicitWidth + 36
                radius: 20
                opacity: enabledBtn ? 1 : 0.4
                color: primary ? (btnM.containsMouse && enabledBtn ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
                               : (btnM.containsMouse && enabledBtn ? Theme.bgHover : Theme.bgSoft)
                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                Text {
                    id: btnText
                    anchors.centerIn: parent
                    text: btn.label
                    color: btn.primary ? Theme.ink : Theme.text
                    font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold
                }
                MouseArea {
                    id: btnM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: btn.enabledBtn ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (btn.enabledBtn) btn.clicked()
                }
            }

            component SideItem: Rectangle {
                id: si
                property string label
                property bool active: false
                signal clicked()
                Layout.fillWidth: true
                implicitHeight: 42
                radius: 14
                color: active ? Theme.accentSoft : (siM.containsMouse ? Theme.bgSoft : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                Text {
                    anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                    text: si.label
                    color: si.active ? Theme.accent : Theme.text
                    font.family: Theme.font; font.pixelSize: 14; font.weight: si.active ? Font.DemiBold : Font.Medium
                }
                MouseArea { id: siM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: si.clicked() }
            }

            component TabBtn: Item {
                id: tb
                property string label
                property bool active: false
                property bool dot: false
                signal clicked()
                implicitHeight: 44
                implicitWidth: tbRow.implicitWidth + 28
                Row {
                    id: tbRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: tb.label
                        color: tb.active ? Theme.text : (tbM.containsMouse ? Theme.text : Theme.dim)
                        font.family: Theme.font; font.pixelSize: 13; font.weight: tb.active ? Font.DemiBold : Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle { visible: tb.dot; width: 6; height: 6; radius: 3; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 10; rightMargin: 10 }
                    height: 2; radius: 1; color: Theme.accent
                    opacity: tb.active ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.dur(140) } }
                }
                MouseArea { id: tbM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tb.clicked() }
            }

            component ServiceRow: Rectangle {
                id: svc
                property string name
                property string detail
                property bool up: false
                property string own: ""            // estado de la unidad systemd ("" = no gestionada)
                property bool canStart: true
                signal startClicked()
                signal stopClicked()
                Layout.fillWidth: true
                implicitHeight: 64
                radius: 18
                color: Theme.bgSoft
                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                    spacing: 12
                    Rectangle {
                        width: 9; height: 9; radius: 5
                        color: svc.up ? Theme.green : (svc.own === "activating" ? Theme.yellow : Theme.dim)
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: svc.name; color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text {
                            text: svc.up ? "En marcha · " + svc.detail : (svc.own === "activating" ? "Arrancando…" : "Detenido · " + svc.detail)
                            color: Theme.dim; font.family: Theme.font; font.pixelSize: 12
                        }
                    }
                    Btn {
                        visible: svc.own !== "" && !svc.up && svc.own !== "activating" && svc.canStart
                        label: "Iniciar"; enabledBtn: !me.busy
                        onClicked: svc.startClicked()
                    }
                    Btn {
                        visible: svc.own === "active" || svc.own === "activating"
                        label: "Detener"; enabledBtn: !me.busy
                        onClicked: svc.stopClicked()
                    }
                }
            }

            // ── Tarjeta ─────────────────────────────────────
            Rectangle {
                id: card
                width: Math.min(900, win.width - 80)
                height: Math.min(win.height - 80, 640)
                anchors.centerIn: parent
                radius: 30
                color: Theme.bg
                border.width: 1
                border.color: Theme.stroke
                opacity: win.visible ? 1 : 0
                scale: win.visible ? 1 : 0.97
                Behavior on opacity { NumberAnimation { duration: Theme.dur(180) } }
                Behavior on scale { NumberAnimation { duration: Theme.dur(240); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard } }
                MouseArea { anchors.fill: parent }

                // Cabecera
                Item {
                    id: head
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 78
                    Column {
                        anchors { left: parent.left; leftMargin: 28; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        Text {
                            text: "Asistente"
                            color: Theme.text
                            font.family: Theme.font; font.pixelSize: 22; font.weight: Font.DemiBold
                        }
                        Text {
                            text: "Claves, modelo y voz del chatbot con avatar 3D"
                            color: Theme.dim
                            font.family: Theme.font; font.pixelSize: 13
                        }
                    }
                    Row {
                        anchors { right: parent.right; rightMargin: 28; verticalCenter: parent.verticalCenter }
                        spacing: 16
                        Pill { label: "API"; tint: me.apiUp ? Theme.green : (me.configured ? Theme.yellow : Theme.dim) }
                        Pill { visible: me.llmProvider === "local"; label: "Modelo"; tint: me.llmUp ? Theme.green : Theme.yellow }
                        Pill { visible: me.ttsMode === "kokoro"; label: "Kokoro"; tint: me.kokoroUp ? Theme.green : Theme.dim }
                        Pill { visible: me.ttsMode === "qwen"; label: "Qwen"; tint: me.qwenUp ? Theme.green : Theme.dim }
                        Pill { visible: me.isVoices; label: "Voces"; tint: me.voicesUp ? Theme.green : Theme.dim }
                    }
                }

                // Categorías
                Rectangle {
                    id: nav
                    anchors { left: parent.left; top: head.bottom; bottom: foot.top; leftMargin: 18; topMargin: 4; bottomMargin: 4 }
                    width: 180
                    color: "transparent"
                    ColumnLayout {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        spacing: 4
                        Repeater {
                            model: me.cats
                            delegate: SideItem {
                                required property var modelData
                                label: modelData[1]
                                active: me.cat === modelData[0]
                                onClicked: me.cat = modelData[0]
                            }
                        }
                    }
                                    Column {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 16; bottomMargin: 6 }
                        spacing: 2
                        Text {
                            text: "Asistente " + (me.stat.version_assistant ? "v" + me.stat.version_assistant : "—")
                            color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
                        }
                        Text {
                            text: "Nexora " + (me.stat.version_nexora ? "v" + me.stat.version_nexora : "—")
                            color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
                        }
                    }
}
                Rectangle { anchors { left: nav.right; top: head.bottom; bottom: foot.top; leftMargin: 8; topMargin: 8; bottomMargin: 8 }
                            width: 1; color: Theme.stroke }

                // Pestañas de la categoría
                Item {
                    id: tabs
                    anchors { left: nav.right; right: parent.right; top: head.bottom; leftMargin: 20; rightMargin: 28 }
                    height: 44
                    Row {
                        spacing: 0
                        Repeater {
                            model: me.tabsOf[me.cat]
                            delegate: TabBtn {
                                required property var modelData
                                label: modelData[1]
                                active: me.sub === modelData[0]
                                dot: me.cat === "voz" && modelData[0] !== "motor" && me.ttsMode === me.engineOfTab(modelData[0])
                                onClicked: me.setSub(me.cat, modelData[0])
                            }
                        }
                    }
                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.stroke }
                }

                Flickable {
                    id: flick
                    anchors { left: nav.right; right: parent.right; top: tabs.bottom; bottom: foot.top
                              leftMargin: 20; rightMargin: 28; topMargin: 16 }
                    contentWidth: width
                    contentHeight: body.implicitHeight + 8
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: body
                        width: flick.width
                        spacing: 12

                        // ── General · Claves
                        ColumnLayout {
                            visible: me.page("general", "claves")
                            Layout.fillWidth: true
                            spacing: 8
                            Section { title: "Claves"; hint: "se guardan en ~/.config/nexora/env (solo tú puedes leerlas)" }
                            Field {
                                label: "OPENROUTER API KEY"; placeholder: "sk-or-v1-…"
                                secret: true; revealed: me.showOr
                                value: me.orKey
                                onEdited: me.orKey = value
                                onRevealToggled: me.showOr = !me.showOr
                                warn: me.orKey.trim() === "" && me.llmProvider === "openrouter"
                            }
                            Field {
                                label: "GEMINI API KEY"; placeholder: me.ttsMode === "gemini" ? "necesaria para la voz de Gemini" : "opcional"
                                secret: true; revealed: me.showGem
                                value: me.gemKey
                                onEdited: me.gemKey = value
                                onRevealToggled: me.showGem = !me.showGem
                                warn: me.needGemini
                            }
                        }

                        // ── General · Modelo
                        ColumnLayout {
                            visible: me.page("general", "modelo")
                            Layout.fillWidth: true
                            spacing: 8
                            Section { title: "Modelo de lenguaje"; hint: "en la nube (OpenRouter) o en tu GPU (llama.cpp); se aplica al guardar" }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 8
                                Chip { label: "OpenRouter · nube"; checked: me.llmProvider === "openrouter"; onClicked: { me.llmProvider = "openrouter"; me.dirty = true } }
                                Chip { label: "Local · llama.cpp"; checked: me.llmProvider === "local"; onClicked: { me.llmProvider = "local"; me.dirty = true } }
                            }
                            Field {
                                label: me.llmProvider === "local" ? "NOMBRE DEL MODELO (alias en llama-server)" : "MODELO DE LENGUAJE"
                                placeholder: me.llmProvider === "local" ? "bonsai-27b" : "anthropic/claude-haiku-5.5"
                                value: me.llmModel
                                onEdited: me.llmModel = value
                            }
                            Field {
                                visible: me.llmProvider === "local"
                                label: "ARCHIVO GGUF"; placeholder: "/home/…/.lmstudio/models/…/modelo.gguf"
                                value: me.llmModelPath
                                onEdited: me.llmModelPath = value
                                warn: me.llmModelPath.trim() === ""
                            }
                            Field {
                                visible: me.llmProvider === "local"
                                label: "URL DEL SERVIDOR"; placeholder: "http://127.0.0.1:8088/v1"
                                value: me.llmBaseUrl
                                onEdited: me.llmBaseUrl = value
                            }
                            Field {
                                visible: me.llmProvider === "local"
                                label: "CONTEXTO (tokens)"; placeholder: "16384 (vacío = el del modelo)"
                                value: me.llmCtx
                                onEdited: me.llmCtx = value
                            }
                            Section { title: "Razonamiento"; hint: "cuánto piensa el modelo antes de responder" }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 8
                                Chip { label: "Apagado"; checked: me.llmReasoning === "off"; onClicked: { me.llmReasoning = "off"; me.dirty = true } }
                                Chip { label: "Automático"; checked: me.llmReasoning === "auto"; onClicked: { me.llmReasoning = "auto"; me.dirty = true } }
                                Chip { label: "Bajo"; checked: me.llmReasoning === "low"; onClicked: { me.llmReasoning = "low"; me.dirty = true } }
                                Chip { label: "Medio"; checked: me.llmReasoning === "medium"; onClicked: { me.llmReasoning = "medium"; me.dirty = true } }
                                Chip { label: "Alto"; checked: me.llmReasoning === "high"; onClicked: { me.llmReasoning = "high"; me.dirty = true } }
                            }
                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: Theme.dim; font.family: Theme.font; font.pixelSize: 12
                                text: "Apagado responde más rápido (recomendado para voz). Automático deja que cada turno decida su esfuerzo; en OpenRouter solo tiene efecto si el modelo lo admite."
                            }
                        }

                        // ── Voz · Motor
                        ColumnLayout {
                            visible: me.page("voz", "motor")
                            Layout.fillWidth: true
                            spacing: 10
                            Section { title: "Motor de voz"; hint: "se aplica al guardar" }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 8
                                Chip { label: "Gemini · nube"; checked: me.ttsMode === "gemini"; onClicked: { me.ttsMode = "gemini"; me.dirty = true } }
                                Chip { label: "Kokoro · GPU"; checked: me.ttsMode === "kokoro"; onClicked: { me.ttsMode = "kokoro"; me.dirty = true } }
                                Chip { label: "Qwen · GPU"; checked: me.ttsMode === "qwen"; onClicked: { me.ttsMode = "qwen"; me.dirty = true } }
                                Chip { label: "Piper · GPU"; checked: me.ttsMode === "piper"; onClicked: me.pickEngine("piper") }
                                Chip { label: "Supertonic · GPU"; checked: me.ttsMode === "supertonic"; onClicked: me.pickEngine("supertonic") }
                                Chip { label: "Sin voz"; checked: me.ttsMode === "off"; onClicked: { me.ttsMode = "off"; me.dirty = true } }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: hintCol.implicitHeight + 28
                                radius: 18
                                color: Theme.bgSoft
                                Column {
                                    id: hintCol
                                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 16 }
                                    spacing: 4
                                    Text {
                                        text: ({ gemini: "Gemini (nube)", kokoro: "Kokoro (local)", qwen: "Qwen3-TTS (local)", piper: "Piper (local)", supertonic: "Supertonic (local)", off: "Sin voz" })[me.ttsMode]
                                        color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold
                                    }
                                    Text {
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        text: ({
                                            gemini: "Voces expresivas en la nube. Necesita la clave de Gemini y envía el texto a Google.",
                                            kokoro: "Rápida y ligera en tu GPU (contenedor Docker). Voz en español algo básica.",
                                            qwen: "Calidad alta con la voz de mujer diseñada. Usa ~5 GB de VRAM y tarda ~2,5 s en empezar a sonar.",
                                            piper: "Voces clásicas en GPU: ~0,15 s hasta el primer audio (comparte ~2,7 GB de VRAM con Supertonic). Suenan más robóticas, con mucho carácter.",
                                            supertonic: "Modelo moderno en GPU: ~0,2 s hasta el primer audio y más natural que Piper (comparte VRAM con Piper).",
                                            off: "El asistente responde solo con texto."
                                        })[me.ttsMode]
                                        color: Theme.dim; font.family: Theme.font; font.pixelSize: 12
                                    }
                                }
                            }
                        }

                        // ── Voz · Gemini
                        ColumnLayout {
                            visible: me.page("voz", "gemini")
                            Layout.fillWidth: true
                            spacing: 8
                            Section { title: "Gemini"; hint: me.ttsMode === "gemini" ? "motor activo" : "no es el motor activo" }
                            Field {
                                label: "MODELO TTS DE GEMINI"; placeholder: "gemini-3.8-flash-lite-tts"
                                value: me.gemModel
                                onEdited: me.gemModel = value
                            }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 6
                                Repeater {
                                    model: me.geminiVoices
                                    delegate: Chip {
                                        required property string modelData
                                        label: modelData
                                        checked: me.gemVoice === modelData
                                        onClicked: { me.gemVoice = modelData; me.dirty = true }
                                    }
                                }
                            }
                        }

                        // ── Voz · Kokoro
                        ColumnLayout {
                            visible: me.page("voz", "kokoro")
                            Layout.fillWidth: true
                            spacing: 8
                            Section { title: "Kokoro"; hint: me.ttsMode === "kokoro" ? "motor activo" : "no es el motor activo" }
                            Field {
                                label: "URL DE KOKORO"; placeholder: "http://127.0.0.1:8881"
                                value: me.kokUrl
                                onEdited: me.kokUrl = value
                            }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 6
                                Repeater {
                                    model: me.kokoroVoices
                                    delegate: Chip {
                                        required property string modelData
                                        label: modelData
                                        checked: me.kokVoice === modelData
                                        onClicked: { me.kokVoice = modelData; me.dirty = true }
                                    }
                                }
                            }
                        }

                        // ── Voz · Qwen
                        ColumnLayout {
                            visible: me.page("voz", "qwen")
                            Layout.fillWidth: true
                            spacing: 8
                            Section { title: "Qwen3-TTS"; hint: me.ttsMode === "qwen" ? "motor activo" : "no es el motor activo" }
                            Field {
                                label: "URL DE QWEN TTS"; placeholder: "http://127.0.0.1:8890"
                                value: me.qwenUrl
                                onEdited: me.qwenUrl = value
                            }
                            Field {
                                label: "PERFIL DE VOZ"; placeholder: "nombre del perfil (carpeta en voices/)"
                                value: me.qwenVoice
                                onEdited: me.qwenVoice = value
                                warn: me.ttsMode === "qwen" && me.qwenVoice.trim() === ""
                            }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 6
                                Repeater {
                                    model: me.qwenVoices
                                    delegate: Chip {
                                        required property string modelData
                                        label: modelData
                                        checked: me.qwenVoice === modelData
                                        onClicked: { me.qwenVoice = modelData; me.dirty = true }
                                    }
                                }
                            }
                            Field {
                                label: "ESTILO (OPCIONAL)"; placeholder: "p. ej. cálida y cercana"
                                value: me.qwenInstr
                                onEdited: me.qwenInstr = value
                            }
                            Btn {
                                visible: me.qwenUp && me.qwenVoice.trim() !== ""
                                label: "Probar voz"
                                onClicked: me.testVoice("qwen", me.qwenVoice.trim())
                            }
                        }

                        // ── Voz · Ligeras
                        ColumnLayout {
                            visible: me.page("voz", "piper") || me.page("voz", "supertonic")
                            Layout.fillWidth: true
                            spacing: 8
                            Section { title: me.sub === "piper" ? "Piper" : "Supertonic"; hint: me.ttsMode === me.sub ? "motor activo · toca una voz para elegirla" : (me.voicesUp ? "toca una voz para usarla" : "servidor detenido: arráncalo en Servicios") }
                            Field {
                                label: "URL DEL SERVIDOR (COMPARTIDO POR PIPER Y SUPERTONIC)"; placeholder: "http://127.0.0.1:8891"
                                value: me.voicesUrl
                                onEdited: me.voicesUrl = value
                            }
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 8
                                rowSpacing: 6
                                Repeater {
                                    model: me.voicesFor(me.sub)
                                    delegate: Rectangle {
                                        id: vrow
                                        required property var modelData
                                        readonly property bool chosen: me.voicesActive === modelData.id && me.ttsMode === me.sub
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        implicitHeight: 48
                                        radius: 16
                                        color: chosen ? Theme.accentSoft : (vM.containsMouse ? Theme.bgHover : Theme.bgSoft)
                                        border.width: 1
                                        border.color: chosen ? Theme.accentLine : "transparent"
                                        Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                                        MouseArea {
                                            id: vM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { me.voicesActive = vrow.modelData.id; me.ttsMode = me.sub; me.dirty = true }
                                        }
                                        Text {
                                            anchors { left: parent.left; leftMargin: 14; right: play.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                            text: vrow.modelData.label
                                            elide: Text.ElideRight
                                            color: vrow.chosen ? Theme.accent : Theme.text
                                            font.family: Theme.font; font.pixelSize: 13; font.weight: vrow.chosen ? Font.DemiBold : Font.Medium
                                        }
                                        Rectangle {
                                            id: play
                                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                            width: 34; height: 34; radius: 17
                                            opacity: me.voicesUp ? 1 : 0.35
                                            color: pM.containsMouse && me.voicesUp ? Theme.bgHover : Theme.bg
                                            Canvas {
                                                anchors.centerIn: parent
                                                width: 14; height: 14
                                                property color tint: Theme.text
                                                onTintChanged: requestPaint()
                                                onPaint: {
                                                    const c = getContext("2d"); c.reset()
                                                    c.fillStyle = tint
                                                    c.beginPath(); c.moveTo(3, 1); c.lineTo(13, 7); c.lineTo(3, 13); c.closePath(); c.fill()
                                                }
                                            }
                                            MouseArea {
                                                id: pM
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: me.voicesUp ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: if (me.voicesUp) me.testVoice("voices", vrow.modelData.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── Servicios · Estado
                        ColumnLayout {
                            visible: me.page("servicios", "estado")
                            Layout.fillWidth: true
                            spacing: 8
                            Section { title: "Servicios"; hint: "los motores de voz se arrancan solos al usarlos" }
                            ServiceRow {
                                name: "API de Nexora"; detail: "chatbot y orquestación"
                                up: me.apiUp; own: ""
                            }
                            ServiceRow {
                                visible: me.llmProvider === "local"
                                name: "Modelo local"; detail: "llama-server · GPU · " + (me.llmModel || "—") + " · " + me.llmBaseUrl
                                up: me.llmUp; own: me.stat.llm_own || "inactive"
                                onStartClicked: me.kokoro("llm-start")
                                onStopClicked: me.kokoro("llm-stop")
                            }
                            ServiceRow {
                                name: "Piper y Supertonic"; detail: "un servidor · GPU · ~2,7 GB de VRAM · puerto 8891"
                                up: me.voicesUp; own: me.stat.voices_own || "inactive"
                                onStartClicked: me.kokoro("voices-start")
                                onStopClicked: me.kokoro("voices-stop")
                            }
                            ServiceRow {
                                name: "Qwen3-TTS"; detail: "GPU · ~5 GB de VRAM · puerto 8890"
                                up: me.qwenUp; own: me.stat.qwen_own || "inactive"
                                onStartClicked: me.kokoro("qwen-start")
                                onStopClicked: me.kokoro("qwen-stop")
                            }
                            ServiceRow {
                                name: "Kokoro"; detail: me.stat.kokoro_image === "yes" ? "GPU · Docker · puerto 8881" : "imagen sin descargar"
                                up: me.kokoroUp; own: me.stat.kokoro_own || "inactive"
                                canStart: me.stat.kokoro_image === "yes"
                                onStartClicked: me.kokoro("kokoro-start")
                                onStopClicked: me.kokoro("kokoro-stop")
                            }
                            Btn {
                                visible: !me.kokoroUp && me.stat.kokoro_image !== "yes"
                                label: "Descargar imagen de Kokoro"
                                enabledBtn: !me.busy
                                onClicked: me.kokoro("kokoro-install")
                            }
                        }

                        Item { Layout.preferredHeight: 4 }
                    }
                }

                // Pie
                Item {
                    id: foot
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 72
                    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 28; rightMargin: 28 }
                                height: 1; color: Theme.stroke }
                    Text {
                        anchors { left: parent.left; leftMargin: 28; right: btns.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: me.message !== "" ? me.message
                              : (me.needGemini ? "Falta la clave de Gemini (o elige otro motor en Voz)" : (me.dirty ? "Cambios sin guardar" : ""))
                        color: me.messageErr ? Theme.danger : (me.message === "" && me.needGemini ? Theme.yellow : Theme.dim)
                        elide: Text.ElideRight
                        font.family: Theme.font; font.pixelSize: 12
                    }
                    Row {
                        id: btns
                        anchors { right: parent.right; rightMargin: 28; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Btn { label: "Cerrar"; onClicked: me.open = false }
                        Btn {
                            label: me.busy ? "Aplicando…" : "Guardar y aplicar"
                            primary: true
                            enabledBtn: me.canSave && !me.needGemini
                            onClicked: me.save()
                        }
                    }
                }
            }
        }
    }
}
