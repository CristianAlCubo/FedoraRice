import QtQuick

// Panel que BROTA de la sidebar: su ancho crece de 0 a `panelWidth` según `reveal` (0..1) y la forma
// fusionada (Fused) sigue ese ancho fotograma a fotograma, así que el borde "se estira" para formar el panel.
// El contenido mantiene su tamaño final: solo se revela (recorte) con un fundido, sin recolocarse.
// Se monta dentro de SideClip. Los hijos que declares dentro van al área de contenido.
Item {
    id: gp
    property real reveal: 0
    property real panelWidth: 300
    property real panelHeight: 200
    property real radius: 22
    default property alias content: inner.data

    width: panelWidth * reveal
    height: panelHeight
    visible: reveal > 0.004

    Fused {
        edge: "left"; r: gp.radius
        f: Theme.flare * Math.min(1, gp.reveal * 2.5)     // las "orejas" nacen con el panel
    }
    Item {
        id: clipBox
        anchors.fill: parent
        clip: true
        opacity: Math.max(0, Math.min(1, (gp.reveal - 0.3) / 0.6))
        Item { id: inner; width: gp.panelWidth; height: parent.height }
    }
}
