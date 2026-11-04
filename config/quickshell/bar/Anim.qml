import QtQuick

// Animación numérica con las curvas Material 3 Expressive del rice de referencia (Caelestia).
// kind: spatial (movimiento/posición, con sobreimpulso) · fastSpatial · slowSpatial · effects (color/opacidad) · fastEffects · slowEffects · standard
NumberAnimation {
    property string kind: "spatial"
    duration: Theme.dur(Theme.animMs[kind] ?? 400)
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.animCurve[kind] ?? Theme.animCurve.standard
}
