import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Servidor de notificaciones propio (reemplaza a mako) + popups.
Scope {
    id: root

    property bool dnd: false                         // No molestar
    IpcHandler {
        target: "notifications"
        function toggleDnd(): void { root.dnd = !root.dnd }
        function clear(): void { root.clearAll() }
    }
    readonly property var history: server.trackedNotifications
    readonly property int count: server.trackedNotifications.values.length

    // Popups visibles: guardamos solo el id y resolvemos el objeto en byId
    property var byId: ({})
    ListModel { id: popupModel }

    function dropPopup(nid) {
        for (let i = 0; i < popupModel.count; i++) {
            if (popupModel.get(i).nid === nid) { popupModel.remove(i); break }
        }
        delete byId[nid]
    }
    function clearAll() {
        const all = server.trackedNotifications.values.slice()
        popupModel.clear()
        byId = ({})
        all.forEach(n => n.dismiss())
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        imageSupported: true

        onNotification: n => {
            n.tracked = true
            if (root.dnd) return
            root.byId[n.id] = n
            popupModel.insert(0, { nid: n.id })
            while (popupModel.count > 4) root.dropPopup(popupModel.get(popupModel.count - 1).nid)
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            visible: popupModel.count > 0
                && Hyprland.focusedMonitor?.name === modelData.name

            anchors { top: true; right: true }
            margins { top: Theme.frameW + 10; right: Theme.frameW + 10 }
            implicitWidth: 372
            implicitHeight: Math.max(1, list.contentHeight)
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            ListView {
                id: list
                anchors.fill: parent
                interactive: false
                spacing: 10
                model: popupModel

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur(180) }
                        NumberAnimation { property: "x"; from: 40; to: 0; duration: Theme.dur(240); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard }
                    }
                }
                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0; duration: Theme.dur(140) }
                        NumberAnimation { property: "x"; to: 40; duration: Theme.dur(160) }
                    }
                }
                displaced: Transition { NumberAnimation { properties: "y"; duration: Theme.dur(200); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.cStandard } }

                delegate: Item {
                    id: row
                    required property int nid
                    readonly property var n: root.byId[nid]
                    readonly property bool critical: n ? n.urgency === NotificationUrgency.Critical : false
                    readonly property int totalMs: !n ? 1 : Math.min(12000,
                        n.expireTimeout > 0 ? n.expireTimeout * 1000 : (critical ? 12000 : 5000))
                    property real elapsed: 0

                    width: list.width
                    height: card.height

                    Timer {
                        interval: 50; running: true; repeat: true
                        onTriggered: {
                            if (hover.containsMouse) return
                            row.elapsed += 50
                            if (row.elapsed >= row.totalMs) root.dropPopup(row.nid)
                        }
                    }
                    Connections {
                        target: row.n
                        function onClosed() { root.dropPopup(row.nid) }
                    }

                    Rectangle {
                        id: card
                        width: parent.width
                        height: body.implicitHeight + 28
                        radius: 16
                        color: Theme.bg
                        border.width: 1
                        border.color: row.critical ? Qt.alpha(Theme.danger, 0.55) : Theme.stroke
                        clip: true

                        RowLayout {
                            id: body
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                            spacing: 12

                            Image {
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                visible: source != ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                sourceSize: Qt.size(76, 76)
                                source: {
                                    if (!row.n) return ""
                                    if (row.n.image !== "") return row.n.image
                                    const a = row.n.appIcon
                                    if (a === "") return ""
                                    return a.startsWith("/") ? "file://" + a : Quickshell.iconPath(a, true)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    Layout.fillWidth: true
                                    text: row.n ? row.n.appName : ""
                                    elide: Text.ElideRight
                                    color: Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                    font.letterSpacing: 0.4
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: row.n ? row.n.summary : ""
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: row.n ? row.n.body : ""
                                    textFormat: Text.StyledText
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    color: Theme.fade(0.72)
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4
                                    spacing: 6
                                    visible: actionsRep.count > 0
                                    Repeater {
                                        id: actionsRep
                                        model: row.n ? row.n.actions : []
                                        delegate: Rectangle {
                                            required property var modelData
                                            height: 26
                                            width: actText.implicitWidth + 22
                                            radius: 13
                                            color: am.containsMouse ? Theme.accentSoft : Theme.bgSoft
                                            border.width: 1
                                            border.color: am.containsMouse ? Theme.accentLine : "transparent"
                                            Text {
                                                id: actText
                                                anchors.centerIn: parent
                                                text: modelData.text
                                                color: Theme.accent
                                                font.family: Theme.font
                                                font.pixelSize: 12
                                            }
                                            MouseArea {
                                                id: am
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: { modelData.invoke(); if (row.n && !row.n.resident) row.n.dismiss() }
                                            }
                                        }
                                    }
                                }
                            }

                            Glyph {
                                Layout.alignment: Qt.AlignTop
                                kind: "close"
                                color: xm.containsMouse ? Theme.text : Theme.dim
                                MouseArea {
                                    id: xm
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.dropPopup(row.nid)   // oculta el popup, queda en el historial
                                }
                            }
                        }

                        // Barra de tiempo restante
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            height: 2
                            width: parent.width * Math.max(0, 1 - row.elapsed / row.totalMs)
                            color: row.critical ? Theme.danger : Theme.accent
                            opacity: 0.7
                        }

                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            z: -1
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: { if (row.n) row.n.dismiss() }   // click: descarta del todo
                        }
                    }
                }
            }
        }
    }
}
