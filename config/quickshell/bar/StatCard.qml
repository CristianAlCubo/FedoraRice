import QtQuick

// Tarjeta de métrica: título, valor grande, subtítulo, anillo opcional y gráfica.
Rectangle {
    id: c
    property string title
    property string valueText
    property string subText
    property real ratio: -1            // 0..1 → muestra anillo; <0 → sin anillo
    property var history: []
    property real maxValue: 1          // escala de la gráfica; 0 = automática
    property color tint: Theme.accent

    radius: 24
    color: Theme.bgSoft
    border.width: 1
    border.color: Theme.stroke
    clip: true

    // valor animado del anillo
    property real shown: Math.max(0, ratio)
    Behavior on shown { NumberAnimation { duration: Theme.dur(450); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard } }
    onShownChanged: ring.requestPaint()
    onTintChanged: { ring.requestPaint(); spark.requestPaint() }

    // ── Gráfica (fondo inferior) ────────────────────────────
    Canvas {
        id: spark
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: parent.height * 0.42
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: c; function onHistoryChanged() { spark.requestPaint() } }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const h = c.history
            if (!h || h.length < 2) return
            let max = c.maxValue
            if (max <= 0) { max = 1; for (const v of h) if (v > max) max = v }
            const w = width, ht = height - 6
            const step = w / 59
            const pts = h.map((v, i) => ({
                x: w - (h.length - 1 - i) * step,
                y: ht - Math.max(0, Math.min(1, v / max)) * (ht - 8) + 2
            }))

            const g = ctx.createLinearGradient(0, 0, 0, height)
            g.addColorStop(0, Qt.alpha(c.tint, 0.28))
            g.addColorStop(1, Qt.alpha(c.tint, 0))

            function trace() {
                ctx.beginPath()
                ctx.moveTo(pts[0].x, pts[0].y)
                for (let i = 1; i < pts.length - 1; i++) {
                    const mx = (pts[i].x + pts[i + 1].x) / 2
                    const my = (pts[i].y + pts[i + 1].y) / 2
                    ctx.quadraticCurveTo(pts[i].x, pts[i].y, mx, my)
                }
                ctx.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y)
            }
            trace()
            ctx.lineTo(pts[pts.length - 1].x, height)
            ctx.lineTo(pts[0].x, height)
            ctx.closePath()
            ctx.fillStyle = g
            ctx.fill()

            trace()
            ctx.strokeStyle = c.tint
            ctx.lineWidth = 1.8
            ctx.lineJoin = "round"
            ctx.stroke()
        }
    }

    // ── Texto ───────────────────────────────────────────────
    Column {
        anchors { left: parent.left; top: parent.top; margins: 16 }
        spacing: 2
        Text {
            text: c.title.toUpperCase()
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
        }
        Text {
            text: c.valueText
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 26
            font.weight: Font.Light
            font.features: { "tnum": 1 }
        }
        Text {
            text: c.subText
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 11
            font.features: { "tnum": 1 }
        }
    }

    // ── Anillo ──────────────────────────────────────────────
    Canvas {
        id: ring
        visible: c.ratio >= 0
        width: 44; height: 44
        anchors { right: parent.right; top: parent.top; margins: 14 }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const cx = width / 2, cy = height / 2, r = 17
            ctx.lineWidth = 5
            ctx.lineCap = "round"
            ctx.strokeStyle = Theme.fade(0.08)
            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke()
            if (c.shown > 0.005) {
                ctx.strokeStyle = c.tint
                ctx.beginPath()
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, c.shown))
                ctx.stroke()
            }
        }
    }
}
