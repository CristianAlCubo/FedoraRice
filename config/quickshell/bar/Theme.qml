pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lee ~/.config/rice/theme.json (única fuente del tema). Se recarga en vivo al guardar el archivo.
// Los demás archivos (kitty, Hyprland, hyprlock) se generan con `rice-theme`.
Singleton {
    id: t

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/rice/theme.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    readonly property var cfg: { try { return JSON.parse(file.text()) } catch (e) { return {} } }
    readonly property var c:   cfg.colors  ?? ({})
    readonly property var op:  cfg.opacity ?? ({})
    readonly property var fn:  cfg.fonts   ?? ({})

    readonly property string themeId:   cfg.id   ?? ""
    readonly property string themeName: cfg.name ?? ""

    // ── Paleta base ──
    readonly property color _base:    c.base    ?? "#1a1b26"
    readonly property color _bgDark:  c.bgDark  ?? "#16161e"
    readonly property color _surface: c.surface ?? "#24283b"
    readonly property color _text:    c.text    ?? "#c0caf5"
    readonly property color _dim:     mixc(Qt.color(c.dim ?? "#737aa2"), _text, 0.18)   // secundario, aclarado hacia el texto para legibilidad
    readonly property color _accent:  c.accent  ?? "#7aa2f7"
    readonly property color _accent2: c.accent2 ?? "#bb9af7"
    readonly property color _cyan:    c.cyan    ?? "#7dcfff"
    readonly property color _green:   c.green   ?? "#9ece6a"
    readonly property color _yellow:  c.yellow  ?? "#e0af68"
    readonly property color _orange:  c.orange  ?? "#ff9e64"
    readonly property color _danger:  c.red     ?? "#f7768e"
    readonly property color _ink:     c.ink     ?? "#16161e"

    // Los tokens públicos siguen al valor del tema con una transición suave (cambio de tema sin saltos).
    property color base: _base
    Behavior on base { ColorAnimation { duration: t.dur(360); easing.type: Easing.OutCubic } }
    property color bgDark: _bgDark
    Behavior on bgDark { ColorAnimation { duration: t.dur(360); easing.type: Easing.OutCubic } }
    property color surface: _surface
    Behavior on surface { ColorAnimation { duration: t.dur(360); easing.type: Easing.OutCubic } }
    property color text: _text
    Behavior on text { ColorAnimation { duration: t.dur(360); easing.type: Easing.OutCubic } }
    property color dim: _dim
    Behavior on dim { ColorAnimation { duration: t.dur(360); easing.type: Easing.OutCubic } }
    property color accent: _accent
    Behavior on accent { ColorAnimation { duration: t.dur(360); easing.type: Easing.OutCubic } }
    property color accent2: _accent2
    Behavior on accent2 { ColorAnimation { duration: t.dur(360); easing.type: Easing.OutCubic } }
    property color cyan: _cyan
    Behavior on cyan { ColorAnimation { duration: t.dur(360); easing.type: Easing.OutCubic } }
    property color green: _green
    Behavior on green { ColorAnimation { duration: t.dur(360); easing.type: Easing.OutCubic } }
    property color yellow: _yellow
    Behavior on yellow { ColorAnimation { duration: t.dur(360); easing.type: Easing.OutCubic } }
    property color orange: _orange
    Behavior on orange { ColorAnimation { duration: t.dur(360); easing.type: Easing.OutCubic } }
    property color danger: _danger
    Behavior on danger { ColorAnimation { duration: t.dur(360); easing.type: Easing.OutCubic } }
    property color ink: _ink
    Behavior on ink { ColorAnimation { duration: t.dur(360); easing.type: Easing.OutCubic } }

    // ── Derivados ──
    readonly property color bg:         Qt.alpha(base,   op.panel ?? 0.985)
    readonly property color bgBar:      Qt.alpha(bgDark, op.bar   ?? 0.90)
    readonly property color accentSoft: Qt.alpha(accent, 0.22)
    readonly property color accentLine: Qt.alpha(accent, 0.55)

    // ── Superficies (elevación) ──
    // s0 marco · s1 panel · s2 tarjetas/botones sobre el panel · s3 hover y elementos dentro de tarjetas · s4 seleccionado/pulsado.
    // Opacas y derivadas de la paleta: mezclan `base` con `text` según theme.json → "surfaces": [s2, s3, s4].
    function mixc(a, b, k) { return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1) }
    readonly property var lv: cfg.surfaces ?? [0.07, 0.125, 0.19]
    readonly property color s0: bgDark
    readonly property color s1: base
    readonly property color s2: mixc(base, text, lv[0])
    readonly property color s3: mixc(base, text, lv[1])
    readonly property color s4: mixc(base, text, lv[2])
    readonly property color bgSoft:  s2          // alias: tarjeta/botón sobre el panel
    readonly property color bgHover: s3          // alias: hover
    readonly property color stroke:  Qt.alpha(text, 0.12)

    // Utilidades para transparencias: Theme.fade(0.1) = texto translúcido; Theme.scrim(0.4) = velo oscuro
    function fade(a)  { return Qt.alpha(text, a) }
    function scrim(a) { return Qt.alpha(bgDark, a) }

    // ── Tipografía y medidas ──
    readonly property string font:  fn.sans ?? "Rubik"
    readonly property string mono:  fn.mono ?? "FiraCode Nerd Font Mono"
    // Escala de animaciones (theme.json → "scale": {"anim": 1.0}); 0.5 = el doble de rápido, 0 = sin animaciones
    readonly property real animScale: cfg.scale?.anim ?? 1.0
    function dur(ms) { return Math.round(ms * animScale) }
    // Tokens de movimiento: una sola curva de salida (arranque rápido, frenado largo) y duraciones comunes.
    // Curvas y duraciones de Caelestia (Material 3 Expressive). Las "spatial" ya NO rebotan (decisión del usuario): arrancan rápido y frenan suave hacia la posición final.
    readonly property var animCurve: ({
        spatial:     [0.16, 1, 0.3, 1, 1, 1],
        fastSpatial: [0.2, 1, 0.3, 1, 1, 1],
        slowSpatial: [0.12, 1, 0.3, 1, 1, 1],
        effects:     [0.34, 0.80, 0.34, 1, 1, 1],
        fastEffects: [0.31, 0.94, 0.34, 1, 1, 1],
        slowEffects: [0.34, 0.88, 0.34, 1, 1, 1],
        standard:    [0.2, 0, 0, 1, 1, 1]
    })
    readonly property var animMs: ({ spatial: 420, fastSpatial: 320, slowSpatial: 560, effects: 190, fastEffects: 140, slowEffects: 280, standard: 220 })
    readonly property var cEffects: animCurve.effects
    readonly property var cStandard: animCurve.standard
    readonly property var cSpatial: animCurve.spatial
    readonly property int ease: Easing.OutQuint
    readonly property int easeSpring: Easing.OutBack        // con easing.overshoot pequeño: asentamiento "vivo"
    readonly property int tFast: dur(110)
    readonly property int tNormal: dur(170)
    readonly property int tSlow: dur(260)

    readonly property int sidebarW: cfg.layout?.sidebarW ?? 64
    readonly property int frameW:   cfg.layout?.frameW   ?? 10     // grosor del marco (arriba, derecha, abajo)
    readonly property int flare:    cfg.layout?.flare   ?? 20     // radio de las uniones panel↔marco
    readonly property int frameR:   cfg.layout?.frameR   ?? 24     // radio de las esquinas del hueco
    readonly property color frame:  Qt.alpha(bgDark, op.frame ?? 1) // color del marco (opaco: se funde con la sidebar)
}
