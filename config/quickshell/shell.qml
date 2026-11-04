
import QtQuick
import Quickshell

ShellRoot {
    FloatingWindow {
        id: window

        width: 620
        height: 720
        visible: true
        title: "NOVA — Desktop Companion"
        color: "#0b0d16"

        property string currentMessage: "¡Hola! Estoy lista para ayudarte."
        property string userInput: ""
        property string currentTime: Qt.formatDateTime(new Date(), "hh:mm:ss")

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: window.currentTime =
                Qt.formatDateTime(new Date(), "hh:mm:ss")
        }

        Rectangle {
            anchors.fill: parent
            color: "#0b0d16"
            radius: 24
            border.color: "#29253f"
            border.width: 1

            Rectangle {
                anchors.fill: parent
                radius: 24
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#17152b" }
                    GradientStop { position: 0.5; color: "#0d1020" }
                    GradientStop { position: 1.0; color: "#11101b" }
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 22

                // HEADER
                Row {
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        width: 38
                        height: 38
                        radius: 12
                        color: "#292047"

                        Text {
                            anchors.centerIn: parent
                            text: "✦"
                            color: "#c5a5ff"
                            font.pixelSize: 23
                        }
                    }

                    Column {
                        spacing: 3

                        Text {
                            text: "NOVA"
                            color: "#f0eaff"
                            font.pixelSize: 16
                            font.bold: true
                            font.letterSpacing: 3
                        }

                        Text {
                            text: "PERSONAL AI COMPANION"
                            color: "#77718e"
                            font.pixelSize: 9
                            font.letterSpacing: 2
                        }
                    }

                    Item { width: 1; height: 1 }

                    Rectangle {
                        width: 85
                        height: 28
                        radius: 14
                        color: "#172c2a"

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                width: 7
                                height: 7
                                radius: 4
                                color: "#64e6b1"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "ONLINE"
                                color: "#64e6b1"
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }
                    }
                }

                // AVATAR
                Item {
                    width: parent.width
                    height: 290

                    Rectangle {
                        id: aura
                        width: 210
                        height: 210
                        radius: 105
                        anchors.centerIn: parent
                        color: "#33225d"
                        opacity: 0.45

                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            NumberAnimation {
                                to: 1.12
                                duration: 1800
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: 0.95
                                duration: 1800
                                easing.type: Easing.InOutSine
                            }
                        }
                    }

                    Rectangle {
                        width: 160
                        height: 160
                        radius: 80
                        anchors.centerIn: parent
                        color: "#201938"
                        border.color: "#8b65d8"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "✧"
                            color: "#d5baff"
                            font.pixelSize: 90

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.55; duration: 1200 }
                                NumberAnimation { to: 1.0; duration: 1200 }
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        text: "NOVA"
                        color: "#e5d8ff"
                        font.pixelSize: 20
                        font.bold: true
                        font.letterSpacing: 5
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -22
                        text: "READY TO ASSIST"
                        color: "#80769e"
                        font.pixelSize: 9
                        font.letterSpacing: 2
                    }
                }

                // CLOCK
                Rectangle {
                    width: parent.width
                    height: 85
                    radius: 16
                    color: "#151526"
                    border.color: "#29253f"

                    Column {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: window.currentTime
                            color: "#e5dcff"
                            font.pixelSize: 27
                            font.family: "monospace"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDate(new Date(), "dddd, dd MMMM yyyy")
                            color: "#89829f"
                            font.pixelSize: 11
                        }
                    }
                }

                // CHAT
                Text {
                    text: "CONVERSATION"
                    color: "#9c8abf"
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 2
                }

                Rectangle {
                    width: parent.width
                    height: 65
                    radius: 12
                    color: "#171729"
                    border.color: "#302748"

                    Text {
                        anchors.fill: parent
                        anchors.margins: 14
                        verticalAlignment: Text.AlignVCenter
                        text: window.currentMessage
                        color: "#d8d2e8"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                }

                Row {
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        width: parent.width - 60
                        height: 44
                        radius: 12
                        color: "#171729"
                        border.color: "#39304f"

                        TextInput {
                            id: input
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#ffffff"
                            font.pixelSize: 13
                            clip: true

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Escribe algo..."
                                color: "#625d78"
                                visible: !input.text && !input.activeFocus
                            }

                            onAccepted: sendButton.clicked()
                        }
                    }

                    Rectangle {
                        id: sendButton
                        width: 50
                        height: 44
                        radius: 12
                        color: "#7854bd"

                        Text {
                            anchors.centerIn: parent
                            text: "➤"
                            color: "white"
                            font.pixelSize: 19
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                if (input.text.trim().length > 0) {
                                    window.currentMessage =
                                        "Tú: " + input.text
                                    input.text = ""
                                }
                            }
                        }
                    }
                }

                Item { width: 1; height: 1 }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "NOVA DESKTOP COMPANION  •  PROTOTYPE 01"
                    color: "#514b68"
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }
            }
        }
    }
}
