import QtQuick
import QtQuick.Layouts
import Quickshell

// Pestaña Avisos: historial de notificaciones, No molestar y limpiar.
Item {
    id: tab
    required property var notifs
    property bool focused: false
    readonly property bool interactive: true
    property int sel: 0
    onFocusedChanged: if (focused) sel = 0
    // Notificaciones agrupadas por app: la más reciente de cada grupo es la vista previa; un encabezado expande/colapsa.
    property var expanded: ({})
    function toggleGroup(app) { const e = Object.assign({}, expanded); e[app] = !e[app]; expanded = e }
    readonly property var rows: {
        const groups = [], idx = {}
        for (const n of tab.notifs.history.values.slice().reverse()) {
            const k = n.appName || "—"
            if (!(k in idx)) { idx[k] = groups.length; groups.push({ app: k, list: [] }) }
            groups[idx[k]].list.push(n)
        }
        const out = []
        for (const g of groups) {
            const open = !!tab.expanded[g.app]
            if (g.list.length > 1) out.push({ type: "head", app: g.app, count: g.list.length, open: open, list: g.list, n: g.list[0] })
            const shown = (g.list.length > 1 && !open) ? g.list.slice(0, 1) : g.list
            shown.forEach(n => out.push({ type: "item", n: n, grouped: g.list.length > 1 }))
        }
        return out
    }

    // ↑/↓ elegir · Intro: descartar (o expandir/colapsar un grupo) · Supr: descartar (grupo entero) · C borrar todo · D no molestar
    function handleKey(k) {
        if (k === Qt.Key_D) { notifs.dnd = !notifs.dnd; return true }
        if (k === Qt.Key_C) { notifs.clearAll(); return true }
        if (rows.length === 0) return false
        if (k === Qt.Key_Down) { sel = Math.min(rows.length - 1, sel + 1); nlist.positionViewAtIndex(sel, ListView.Contain); return true }
        if (k === Qt.Key_Up) { if (sel > 0) { sel--; nlist.positionViewAtIndex(sel, ListView.Contain); return true } return false }
        const r = rows[Math.min(sel, rows.length - 1)]
        if (!r) return false
        const dismissRow = () => { if (r.type === "head") r.list.slice().forEach(n => n.dismiss()); else r.n.dismiss() }
        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            if (r.type === "head") { toggleGroup(r.app); return true }
            dismissRow(); sel = Math.max(0, Math.min(sel, rows.length - 2)); return true
        }
        if (k === Qt.Key_Delete || k === Qt.Key_Backspace) { dismissRow(); sel = Math.max(0, Math.min(sel, rows.length - 2)); return true }
        return false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            spacing: 8

            Text {
                text: tab.notifs.count > 0 ? tab.notifs.count + (tab.notifs.count === 1 ? " notificación" : " notificaciones")
                                           : "Sin notificaciones"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }

            Rectangle {
                visible: tab.notifs.count > 0
                implicitWidth: clearRow.implicitWidth + 28
                implicitHeight: 38
                radius: 19
                color: clearM.containsMouse ? Theme.bgHover : Theme.bgSoft
                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                Row {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "edit-clear-all"; size: 15
                        color: clearM.containsMouse ? Theme.text : Theme.dim }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Borrar todo"
                        color: clearM.containsMouse ? Theme.text : Theme.dim
                        font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium }
                }
                MouseArea { id: clearM; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: tab.notifs.clearAll() }
            }

            Rectangle {
                implicitWidth: dndRow.implicitWidth + 28
                implicitHeight: 38
                radius: 19
                color: tab.notifs.dnd ? Theme.accent : (dndM.containsMouse ? Theme.bgHover : Theme.bgSoft)
                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                Row {
                    id: dndRow
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { anchors.verticalCenter: parent.verticalCenter
                        name: tab.notifs.dnd ? "notifications-disabled" : "preferences-system-notifications"
                        size: 15; color: tab.notifs.dnd ? Theme.ink : Theme.text }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "No molestar"
                        color: tab.notifs.dnd ? Theme.ink : Theme.text
                        font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium }
                }
                MouseArea { id: dndM; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: tab.notifs.dnd = !tab.notifs.dnd }
            }
        }

        // Estado vacío
        Item {
            visible: tab.notifs.count === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    name: "preferences-system-notifications"; size: 38; color: Theme.fade(0.14)
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Todo al día"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 14
                }
            }
        }

        ListView {
            id: nlist
            visible: tab.notifs.count > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: tab.rows
            // Entradas con ligero deslizamiento y salida/reacomodo suaves al descartar
            add: Transition { ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur(180); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard }
                NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.dur(220); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard } } }
            remove: Transition { ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: Theme.dur(120) }
                NumberAnimation { property: "x"; to: 40; duration: Theme.dur(160); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard } } }
            displaced: Transition { NumberAnimation { properties: "y"; duration: Theme.dur(200); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard } }

            delegate: Item {
                id: dlg
                required property var modelData
                required property int index
                width: nlist.width
                height: ld.item ? ld.item.height : 0
                Loader {
                    id: ld
                    x: (dlg.modelData.type === "item" && dlg.modelData.grouped) ? 14 : 0
                    width: parent.width - x
                    sourceComponent: dlg.modelData.type === "head" ? headC : itemC
                }

                // ── Encabezado de grupo ──
                Component {
                    id: headC
                    Rectangle {
                        readonly property bool kbd: tab.focused && tab.sel === dlg.index
                        height: 46
                        radius: 18
                        color: (hm.containsMouse || kbd) ? Theme.s3 : Theme.s2
                        border.width: kbd ? 2 : 0
                        border.color: Theme.accent
                        Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }
                        Row {
                            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            spacing: 10
                            Image {
                                id: hIcon
                                width: 20; height: 20; anchors.verticalCenter: parent.verticalCenter
                                visible: status === Image.Ready
                                sourceSize: Qt.size(40, 40)
                                source: { const a = dlg.modelData.n.appIcon; return !a ? "" : (a.startsWith("/") ? "file://" + a : Quickshell.iconPath(a, true)) }
                            }
                            Text { text: dlg.modelData.app; color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold
                                anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { width: cnt.implicitWidth + 12; height: 18; radius: 9; color: Theme.accentSoft; anchors.verticalCenter: parent.verticalCenter
                                Text { id: cnt; anchors.centerIn: parent; text: dlg.modelData.count; color: Theme.accent; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold } }
                        }
                        Row {
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 14
                            Text { text: dlg.modelData.open ? "Contraer" : "Ver todas"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter }
                            Icon { anchors.verticalCenter: parent.verticalCenter; name: "window-close"; size: 14
                                color: gdm.containsMouse ? Theme.danger : Theme.dim
                                MouseArea { id: gdm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: dlg.modelData.list.slice().forEach(n => n.dismiss()) } }
                        }
                        MouseArea { id: hm; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: tab.toggleGroup(dlg.modelData.app) }
                    }
                }

                // ── Notificación ──
                Component {
                    id: itemC
                    Rectangle {
                        id: card
                readonly property bool kbd: tab.focused && tab.sel === dlg.index
                width: ld.width
                height: nrow.implicitHeight + 28
                radius: 22
                color: (nhover.containsMouse || kbd) ? Theme.bgHover : Theme.bgSoft
                border.width: kbd ? 2 : 0
                border.color: Theme.accent
                Behavior on color { ColorAnimation { duration: Theme.dur(190); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cEffects } }

                MouseArea { id: nhover; anchors.fill: parent; hoverEnabled: true }

                RowLayout {
                    id: nrow
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: 16; rightMargin: 16 }
                    spacing: 14

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 19
                        color: Theme.s2
                        Image {
                            id: nIcon
                            anchors.centerIn: parent
                            width: 22; height: 22
                            visible: status === Image.Ready
                            sourceSize: Qt.size(44, 44)
                            source: {
                                const a = dlg.modelData.n.appIcon
                                if (!a) return ""
                                return a.startsWith("/") ? "file://" + a : Quickshell.iconPath(a, true)
                            }
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: nIcon.status !== Image.Ready
                            name: "preferences-system-notifications"; size: 17; color: Theme.dim
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: dlg.modelData.n.summary
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: dlg.modelData.n.appName
                                color: Theme.fade(0.3)
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: dlg.modelData.n.body
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            color: Theme.fade(0.62)
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }

                    Icon {
                        Layout.alignment: Qt.AlignTop
                        name: "window-close"; size: 14
                        color: dm.containsMouse ? Theme.text : Theme.dim
                        opacity: nhover.containsMouse || dm.containsMouse || card.kbd ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.dur(120) } }
                        MouseArea { id: dm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: dlg.modelData.n.dismiss() }
                    }
                }
                    }
                }
            }
        }
    }
}
