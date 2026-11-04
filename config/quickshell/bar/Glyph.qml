import QtQuick

// Iconos dibujados a mano (sin depender de fuentes de iconos).
// kind: play | pause | next | prev | chevron | close
Canvas {
    id: g
    property string kind: "play"
    property color color: Theme.text
    implicitWidth: 18
    implicitHeight: 18

    onKindChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const c = getContext("2d")
        c.reset()
        c.fillStyle = g.color
        c.strokeStyle = g.color
        c.lineWidth = 1.8
        c.lineCap = "round"
        c.lineJoin = "round"
        const w = width, h = height
        if (kind === "play") {
            c.beginPath(); c.moveTo(w * 0.28, h * 0.15); c.lineTo(w * 0.88, h * 0.5)
            c.lineTo(w * 0.28, h * 0.85); c.closePath(); c.fill()
        } else if (kind === "pause") {
            c.fillRect(w * 0.22, h * 0.15, w * 0.2, h * 0.7)
            c.fillRect(w * 0.58, h * 0.15, w * 0.2, h * 0.7)
        } else if (kind === "next") {
            c.beginPath(); c.moveTo(w * 0.12, h * 0.2); c.lineTo(w * 0.64, h * 0.5)
            c.lineTo(w * 0.12, h * 0.8); c.closePath(); c.fill()
            c.fillRect(w * 0.72, h * 0.2, w * 0.14, h * 0.6)
        } else if (kind === "prev") {
            c.beginPath(); c.moveTo(w * 0.88, h * 0.2); c.lineTo(w * 0.36, h * 0.5)
            c.lineTo(w * 0.88, h * 0.8); c.closePath(); c.fill()
            c.fillRect(w * 0.14, h * 0.2, w * 0.14, h * 0.6)
        } else if (kind === "chevron") {
            c.beginPath(); c.moveTo(w * 0.22, h * 0.38); c.lineTo(w * 0.5, h * 0.66)
            c.lineTo(w * 0.78, h * 0.38); c.stroke()
        } else if (kind === "check") {
            c.beginPath(); c.moveTo(w * 0.18, h * 0.52); c.lineTo(w * 0.42, h * 0.76)
            c.lineTo(w * 0.82, h * 0.26); c.stroke()
        } else if (kind === "close") {
            c.beginPath(); c.moveTo(w * 0.28, h * 0.28); c.lineTo(w * 0.72, h * 0.72)
            c.moveTo(w * 0.72, h * 0.28); c.lineTo(w * 0.28, h * 0.72); c.stroke()
        }
    }
}
