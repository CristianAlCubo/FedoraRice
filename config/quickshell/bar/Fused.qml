import QtQuick
import QtQuick.Shapes

// Fondo de un panel que "sale" de un borde del marco: esquinas lejanas redondeadas y, en el borde,
// dos curvas cóncavas ("orejas") que lo funden con el marco. Se coloca como primer hijo de la tarjeta;
// la tarjeta debe estar pegada al borde (top/bottom/left/right) que indica `edge`.
Shape {
    id: s
    property string edge: "top"        // top | bottom | left | right
    property color fill: Theme.frame     // mismo token que el marco y la sidebar: la unión no se nota
    property real r: 24                // radio de las esquinas lejanas
    property real f: Theme.flare       // radio de las uniones con el borde
    property real ext: 90              // el relleno se extiende hacia fuera del borde: tapa el hueco cuando el rebote separa el panel

    readonly property bool vert: edge === "top" || edge === "bottom"
    readonly property real a: vert ? parent.width  : parent.height   // largo a lo largo del borde
    readonly property real d: vert ? parent.height : parent.width    // profundidad (perpendicular al borde)

    width:  vert ? a + 2 * f : d + ext
    height: vert ? d + ext : a + 2 * f
    x: vert ? -f : (edge === "right" ? 0 : -ext)
    y: edge === "top" ? -ext : (edge === "bottom" ? 0 : -f)
    preferredRendererType: Shape.CurveRenderer

    // Se dibuja como panel pegado arriba y se rota según el borde (las rotaciones conservan el sentido de los arcos)
    function pt(x, y) {
        let p
        if (edge === "top")         p = [x + f, y + ext]
        else if (edge === "bottom") p = [a - x + f, d - y]
        else if (edge === "right")  p = [d - y, x + f]
        else                        p = [y + ext, a + f - x]
        return p[0] + "," + p[1]
    }
    // o = cuánto se prolonga el borde hacia fuera (relleno: ext · contorno: 2)
    function build(o) {
        const R = Math.min(r, a / 2, d), F = f
        return "M" + pt(-F, -o) + " L" + pt(-F, 0)
            + " A" + F + "," + F + " 0 0 1 " + pt(0, F)
            + " L" + pt(0, d - R) + " A" + R + "," + R + " 0 0 0 " + pt(R, d)
            + " L" + pt(a - R, d) + " A" + R + "," + R + " 0 0 0 " + pt(a, d - R)
            + " L" + pt(a, F) + " A" + F + "," + F + " 0 0 1 " + pt(a + F, 0)
            + " L" + pt(a + F, -o)
    }

    ShapePath {   // relleno (extendido)
        fillColor: s.fill
        strokeColor: "transparent"
        PathSvg { path: s.build(s.ext) }
    }
    ShapePath {   // contorno de 1 px, sin prolongar
        fillColor: "transparent"
        strokeColor: Qt.alpha(Theme.text, 0.16)
        strokeWidth: 1
        PathSvg { path: s.build(2) }
    }
}
