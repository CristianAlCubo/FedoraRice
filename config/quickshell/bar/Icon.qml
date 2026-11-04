import QtQuick
import QtQuick.Effects

// Icono monocromo (Adwaita simbólico) teñido con `color`.
// Uso: Icon { name: "bluetooth-active"; color: Theme.text; size: 20 }
Item {
    id: ic
    property string name
    property color color: Theme.text
    property int size: 20

    implicitWidth: size
    implicitHeight: size

    readonly property var dirs: ({
        "bluetooth-active": "status", "bluetooth-disabled": "status",
        "network-offline": "status", "network-wired": "devices", "network-wireless": "devices",
        "audio-volume-high": "status", "audio-volume-medium": "status",
        "audio-volume-low": "status", "audio-volume-muted": "status",
        "microphone-sensitivity-high": "status", "microphone-sensitivity-muted": "status",
        "notifications-disabled": "status",
        "preferences-system-notifications": "legacy",
        "audio-headphones": "devices", "audio-speakers": "devices",
        "media-playback-start": "actions", "media-playback-pause": "actions",
        "media-skip-forward": "actions", "media-skip-backward": "actions",
        "edit-clear-all": "actions", "system-shutdown": "actions",
        "window-close": "ui", "pan-down": "ui", "pan-start": "ui", "pan-end": "ui",
        "go-home": "actions", "go-previous": "actions", "go-next": "actions",
        "multimedia-player": "devices", "computer": "devices",
        "web-browser": "legacy", "view-app-grid": "actions", "system-users": "legacy",
        "avatar-default": "status", "preferences-system": "categories", "view-fullscreen": "actions",
        "audio-headset": "devices", "applications-games": "categories",
        "camera-photo": "devices", "camera-video": "devices", "media-record": "actions",
        "selection-mode": "actions", "media-playback-stop": "actions",
        "media-playlist-shuffle": "status", "media-playlist-repeat": "status"
    })

    Image {
        id: img
        anchors.fill: parent
        visible: false
        smooth: true
        sourceSize: Qt.size(ic.size * 3, ic.size * 3)
        source: ic.name === "" ? "" :
            "file:///usr/share/icons/Adwaita/symbolic/" + (ic.dirs[ic.name] ?? "status")
            + "/" + ic.name + "-symbolic.svg"
    }
    MultiEffect {
        anchors.fill: img
        source: img
        brightness: 1.0                 // fuerza el icono a blanco...
        colorization: 1.0               // ...y luego lo tiñe
        colorizationColor: Qt.alpha(ic.color, 1)
        opacity: ic.color.a              // el teñido ignora el alfa: lo aplicamos aparte
    }
}
