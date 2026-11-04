import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// Pastilla flotante al cambiar el volumen o silenciar.
Scope {
    id: osd

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null

    property bool armed: false      // evita que salte al iniciar
    property bool shown: false

    Timer { interval: 2500; running: true; onTriggered: osd.armed = true }
    Timer { id: hideTimer; interval: 1500; onTriggered: osd.shown = false }

    function poke() {
        if (!armed) return
        shown = true
        hideTimer.restart()
    }

    Connections {
        target: osd.audio
        function onVolumeChanged() { osd.poke() }
        function onMutedChanged() { osd.poke() }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            visible: pill.opacity > 0.01
                && Hyprland.focusedMonitor?.name === modelData.name

            anchors { bottom: true }
            margins { bottom: 90 }
            implicitWidth: 320
            implicitHeight: 56
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}                       // no captura clicks
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                id: pill
                anchors.fill: parent
                radius: height / 2
                color: Theme.bg
                border.width: 1
                border.color: Theme.stroke
                opacity: osd.shown ? 1 : 0
                scale: osd.shown ? 1 : 0.96
                Behavior on opacity { NumberAnimation { duration: Theme.dur(180) } }
                Behavior on scale { Anim { kind: "spatial" } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 22
                    anchors.rightMargin: 22
                    spacing: 14

                    Text {
                        text: osd.audio?.muted ? "MUTE" : "VOL"
                        color: osd.audio?.muted ? Theme.dim : Theme.accent
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                        Layout.preferredWidth: 34
                    }
                    Slider {
                        Layout.fillWidth: true
                        interactive: false
                        value: osd.audio?.volume ?? 0
                        fill: osd.audio?.muted ? Theme.dim : Theme.accent
                    }
                    Text {
                        text: Math.round((osd.audio?.volume ?? 0) * 100) + "%"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 38
                    }
                }
            }
        }
    }
}
