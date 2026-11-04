import QtQuick
import QtQuick.Layouts

// Calendario mensual (semana desde el lunes). Click en el mes: volver a hoy.
Item {
    id: cal
    property date now: new Date()
    property int viewYear: now.getFullYear()
    property int viewMonth: now.getMonth()

    implicitWidth: 7 * 38
    implicitHeight: col.implicitHeight

    function shift(d) {
        let m = viewMonth + d, y = viewYear
        if (m < 0) { m = 11; y-- } else if (m > 11) { m = 0; y++ }
        viewMonth = m; viewYear = y
    }
    function reset() { viewYear = now.getFullYear(); viewMonth = now.getMonth() }

    readonly property int offset: (new Date(viewYear, viewMonth, 1).getDay() + 6) % 7
    readonly property int dim: new Date(viewYear, viewMonth + 1, 0).getDate()
    readonly property int prevDim: new Date(viewYear, viewMonth, 0).getDate()
    readonly property string title: {
        const s = Qt.locale().monthName(viewMonth, Locale.LongFormat)
        return s.charAt(0).toUpperCase() + s.slice(1) + " " + viewYear
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Text {
                text: cal.title
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 15
                font.weight: Font.DemiBold
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cal.reset() }
            }
            Item { Layout.fillWidth: true }
            Repeater {
                model: [{ n: "pan-start", d: -1 }, { n: "pan-end", d: 1 }]
                delegate: Rectangle {
                    required property var modelData
                    implicitWidth: 30; implicitHeight: 30; radius: 15
                    color: bm.containsMouse ? Theme.bgHover : "transparent"
                    Icon { anchors.centerIn: parent; name: modelData.n; size: 14
                        color: bm.containsMouse ? Theme.text : Theme.dim }
                    MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor; onClicked: cal.shift(modelData.d) }
                }
            }
        }

        Row {
            Layout.fillWidth: true
            Repeater {
                model: ["L", "M", "X", "J", "V", "S", "D"]
                delegate: Text {
                    required property string modelData
                    required property int index
                    width: cal.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: index >= 5 ? Qt.alpha(Theme.accent, 0.55) : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }
        }

        Grid {
            Layout.fillWidth: true
            columns: 7
            Repeater {
                model: 42
                delegate: Item {
                    required property int index
                    readonly property int dayNum: index - cal.offset + 1
                    readonly property bool inMonth: dayNum >= 1 && dayNum <= cal.dim
                    readonly property int shownDay: inMonth ? dayNum
                        : dayNum < 1 ? cal.prevDim + dayNum : dayNum - cal.dim
                    readonly property bool isToday: inMonth
                        && cal.viewYear === cal.now.getFullYear()
                        && cal.viewMonth === cal.now.getMonth()
                        && dayNum === cal.now.getDate()
                    width: cal.width / 7
                    height: 34

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30; height: 30; radius: 15
                        color: isToday ? Theme.accent : (dm.containsMouse && inMonth ? Theme.bgHover : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                        Text {
                            anchors.centerIn: parent
                            text: shownDay
                            color: isToday ? Theme.ink : inMonth ? Theme.text : Theme.fade(0.22)
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.weight: isToday ? Font.DemiBold : Font.Normal
                            font.features: { "tnum": 1 }
                        }
                    }
                    MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true }
                }
            }
        }
    }
}
