import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

// Marco de pantalla (estilo caelestia): la sidebar y un borde fino rodean el contenido,
// que queda como un "inset" con esquinas redondeadas. Una ventana por monitor.
Scope {
    Variants {
        model: Quickshell.screens

        Scope {
            id: sc
            required property var modelData

            // Tiras invisibles que reservan el espacio del borde (la sidebar reserva el lado izquierdo)
            component Strip: PanelWindow {
                screen: sc.modelData
                color: "transparent"
                mask: Region {}
                WlrLayershell.namespace: "frame-strip"
            }
            Strip { anchors { top: true; left: true; right: true }
                   implicitHeight: Theme.frameW; exclusiveZone: Theme.frameW }
            Strip { anchors { bottom: true; left: true; right: true }
                implicitHeight: Theme.frameW
                exclusiveZone: Theme.frameW
            }
            Strip { anchors { right: true; top: true; bottom: true }
                 implicitWidth: Theme.frameW;  exclusiveZone: Theme.frameW }

            // El marco dibujado: rectángulo exterior menos un hueco redondeado (relleno par-impar)
            PanelWindow {
                id: fw
                screen: sc.modelData
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                mask: Region {}                       // no captura clicks
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "frame"

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: Theme.frame
                        strokeColor: "transparent"
                        fillRule: ShapePath.OddEvenFill
                        PathSvg { path: "M0,0 L" + fw.width + ",0 L" + fw.width + "," + fw.height + " L0," + fw.height + " Z" }
                        PathSvg {
                            readonly property real x0: Theme.sidebarW
                            readonly property real y0: Theme.frameW
                            readonly property real w:  fw.width  - Theme.sidebarW - Theme.frameW
                            readonly property real h:  fw.height - 2 * Theme.frameW
                            readonly property real r:  Theme.frameR
                            path: "M" + (x0 + r) + "," + y0
                                + " L" + (x0 + w - r) + "," + y0 + " A" + r + "," + r + " 0 0 1 " + (x0 + w) + "," + (y0 + r)
                                + " L" + (x0 + w) + "," + (y0 + h - r) + " A" + r + "," + r + " 0 0 1 " + (x0 + w - r) + "," + (y0 + h)
                                + " L" + (x0 + r) + "," + (y0 + h) + " A" + r + "," + r + " 0 0 1 " + x0 + "," + (y0 + h - r)
                                + " L" + x0 + "," + (y0 + r) + " A" + r + "," + r + " 0 0 1 " + (x0 + r) + "," + y0 + " Z"
                        }
                    }
                }
            }
        }
    }
}
