import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Tema de SDDM "Cubi": mismo lenguaje visual que el shell (oscuro, translúcido, acento cian),
// con movimiento: fondo que respira, dos puntos del reloj parpadeando, puntos que aparecen al
// escribir y un anillo giratorio al validar la contraseña.
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0b0d12"

    readonly property color text: "#e6e8ee"
    readonly property color dim: "#7d8294"
    readonly property color accent: "#33ccff"
    readonly property color danger: "#ff6b7a"
    readonly property string font: "Inter"

    // Solo el monitor más grande muestra la interfaz; los demás, solo el fondo desenfocado
    readonly property bool isMain: {
        const s = Qt.application.screens
        if (!s || s.length < 2) return true
        let big = s[0]
        for (let i = 1; i < s.length; i++)
            if (s[i].width * s[i].height > big.width * big.height) big = s[i]
        return Screen.name === big.name
    }

    property bool failed: false
    property bool busy: false
    property bool done: false
    property real intro: 0          // 0 → 1 al abrir

    // ── Fondo con movimiento lento ──────────────────────────
    Item {
        anchors.fill: parent
        clip: true
        Image {
            id: bg
            anchors.fill: parent
            source: config.background
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            transformOrigin: Item.Center
            scale: 1.04
            SequentialAnimation on scale {
                loops: Animation.Infinite
                NumberAnimation { to: 1.10; duration: 22000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.04; duration: 22000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on x {
                loops: Animation.Infinite
                NumberAnimation { to: -26; duration: 30000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 26;  duration: 30000; easing.type: Easing.InOutSine }
            }
        }
    }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.12 }
    // Viñeta suave
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
            GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.45) }
        }
    }

    // Selectores ocultos (modelos de SDDM)
    ComboBox {
        id: userBox
        visible: false
        model: userModel
        textRole: "realName"
        valueRole: "name"
        currentIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    }
    ComboBox {
        id: sessionBox
        visible: false
        model: sessionModel
        textRole: "name"
        currentIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
        // Hyprland por defecto (se puede cambiar con el selector de abajo)
        Component.onCompleted: {
            for (let i = 0; i < count; i++)
                if (/hyprland/i.test(textAt(i))) { currentIndex = i; break }
        }
    }

    // ── Interfaz (solo monitor principal) ───────────────────
    Item {
        id: ui
        anchors.fill: parent
        visible: root.isMain
        opacity: root.done ? 0 : 1
        scale: root.done ? 1.06 : 1
        Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.InCubic } }
        Behavior on scale { NumberAnimation { duration: 480; easing.type: Easing.InCubic } }

        // Hora y fecha
        Item {
            id: clockBox
            width: parent.width
            height: 240
            y: parent.height * 0.5 - 330 - (1 - root.intro) * 24
            opacity: Math.min(1, root.intro * 1.6)
            property date now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: clockBox.now = new Date() }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0
                Text {
                    text: Qt.formatDateTime(clockBox.now, "HH")
                    color: root.text
                    font.family: root.font; font.pixelSize: 140; font.weight: Font.Light
                }
                Text {
                    id: colon
                    text: ":"
                    color: root.text
                    font.family: root.font; font.pixelSize: 140; font.weight: Font.Light
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    text: Qt.formatDateTime(clockBox.now, "mm")
                    color: root.text
                    font.family: root.font; font.pixelSize: 140; font.weight: Font.Light
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 168
                text: {
                    const s = Qt.locale("es_ES").toString(clockBox.now, "dddd, d 'de' MMMM")
                    return s.charAt(0).toUpperCase() + s.slice(1)
                }
                color: root.dim
                font.family: root.font
                font.pixelSize: 21
                font.letterSpacing: 0.5
            }
        }

        // ── Formulario ──────────────────────────────────────
        Item {
            id: form
            width: 340
            height: 190
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.5 - 30 + (1 - root.intro) * 30
            opacity: Math.max(0, Math.min(1, root.intro * 2 - 0.5))

            Text {
                id: who
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                text: userBox.currentText || userBox.currentValue
                color: root.text
                font.family: root.font
                font.pixelSize: 19
                font.weight: Font.Medium
                opacity: root.busy ? 0.0 : 1
                Behavior on opacity { NumberAnimation { duration: 200 } }
                MouseArea {
                    anchors.fill: parent; anchors.margins: -8
                    enabled: userBox.count > 1
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: userBox.currentIndex = (userBox.currentIndex + 1) % userBox.count
                }
            }

            // Brillo pulsante detrás del campo
            Rectangle {
                id: glow
                anchors.centerIn: field
                width: field.width + 26
                height: field.height + 26
                radius: height / 2
                color: "transparent"
                border.width: 10
                border.color: Qt.rgba(0.2, 0.8, 1, 0.10)
                opacity: root.failed ? 0 : (pwd.activeFocus || root.busy ? 1 : 0.35)
                Behavior on opacity { NumberAnimation { duration: 300 } }
                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: !root.failed
                    NumberAnimation { to: 1.04; duration: 1600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0;  duration: 1600; easing.type: Easing.InOutSine }
                }
            }

            // Campo: píldora → círculo mientras valida
            Rectangle {
                id: field
                width: root.busy ? 60 : 320
                height: 60
                radius: 30
                x: (form.width - width) / 2
                y: 42
                color: Qt.rgba(0.047, 0.055, 0.078, 0.62)
                border.width: 2
                border.color: root.failed ? root.danger
                             : root.busy ? Qt.rgba(0.2, 0.8, 1, 0.0)
                             : pwd.activeFocus ? Qt.rgba(0.2, 0.8, 1, 0.9) : Qt.rgba(0.2, 0.8, 1, 0.38)
                Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }
                Behavior on border.color { ColorAnimation { duration: 200 } }
                transform: Translate { id: shakeT }

                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: shakeT; property: "x"; to: -12; duration: 55 }
                    NumberAnimation { target: shakeT; property: "x"; to: 12;  duration: 80 }
                    NumberAnimation { target: shakeT; property: "x"; to: -7;  duration: 70 }
                    NumberAnimation { target: shakeT; property: "x"; to: 7;   duration: 60 }
                    NumberAnimation { target: shakeT; property: "x"; to: 0;   duration: 55 }
                }

                // Campo real (texto invisible; los puntos los dibujamos nosotros)
                TextField {
                    id: pwd
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 60
                    echoMode: TextInput.Password
                    color: "transparent"
                    selectionColor: "transparent"
                    selectedTextColor: "transparent"
                    font.family: root.font
                    font.pixelSize: 18
                    placeholderText: "Contraseña"
                    placeholderTextColor: root.dim
                    background: null
                    cursorDelegate: Item {}
                    enabled: !root.busy
                    opacity: root.busy ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    horizontalAlignment: TextInput.AlignHCenter
                    focus: true
                    selectByMouse: false
                    onAccepted: root.doLogin()
                    onTextChanged: root.failed = false
                    Keys.onEscapePressed: pwd.text = ""
                }

                // Puntos que aparecen con un pequeño rebote
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 24 + (parent.width - 84 - width) / 2
                    spacing: 7
                    opacity: root.busy ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    Repeater {
                        model: Math.min(pwd.text.length, 14)
                        delegate: Rectangle {
                            width: 9; height: 9; radius: 5
                            color: root.accent
                            scale: 0
                            Component.onCompleted: pop.start()
                            NumberAnimation on scale {
                                id: pop; running: false
                                from: 0; to: 1; duration: 260
                                easing.type: Easing.OutBack; easing.overshoot: 2.4
                            }
                        }
                    }
                }

                // Botón de entrar
                Rectangle {
                    width: 44; height: 44; radius: 22
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    color: pwd.text.length > 0 ? root.accent : Qt.rgba(1, 1, 1, 0.07)
                    opacity: root.busy ? 0 : 1
                    scale: arrowM.pressed ? 0.92 : 1
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    Canvas {
                        anchors.centerIn: parent
                        width: 18; height: 18
                        property bool active: pwd.text.length > 0
                        onActiveChanged: requestPaint()
                        onPaint: {
                            const c = getContext("2d"); c.reset()
                            c.strokeStyle = active ? "#06161c" : "#7d8294"
                            c.lineWidth = 2.2; c.lineCap = "round"; c.lineJoin = "round"
                            c.beginPath(); c.moveTo(3, 9); c.lineTo(15, 9)
                            c.moveTo(10, 4); c.lineTo(15, 9); c.lineTo(10, 14); c.stroke()
                        }
                    }
                    MouseArea { id: arrowM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.doLogin() }
                }

                // ── Spinner tecnológico ─────────────────────
                Item {
                    id: spinner
                    anchors.centerIn: parent
                    width: 60; height: 60
                    opacity: root.busy ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 260 } }

                    // Anillo exterior con estela degradada
                    Canvas {
                        id: ringA
                        anchors.fill: parent
                        onPaint: {
                            const c = getContext("2d"); c.reset()
                            const cx = width / 2, cy = height / 2, r = 27
                            const segs = 56, span = Math.PI * 1.55
                            c.lineWidth = 3; c.lineCap = "butt"
                            for (let i = 0; i < segs; i++) {
                                const a0 = i / segs * span
                                const a1 = (i + 1) / segs * span + 0.03
                                c.strokeStyle = "rgba(51,204,255," + Math.pow(i / segs, 1.7).toFixed(3) + ")"
                                c.beginPath(); c.arc(cx, cy, r, a0, a1); c.stroke()
                            }
                            c.fillStyle = "#33ccff"
                            c.beginPath(); c.arc(cx + r * Math.cos(span), cy + r * Math.sin(span), 2.6, 0, Math.PI * 2); c.fill()
                        }
                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 1050
                            loops: Animation.Infinite; running: spinner.visible
                        }
                    }
                    // Anillo interior discontinuo, en sentido contrario
                    Canvas {
                        id: ringB
                        anchors.centerIn: parent
                        width: 40; height: 40
                        onPaint: {
                            const c = getContext("2d"); c.reset()
                            c.strokeStyle = "rgba(51,204,255,0.55)"
                            c.lineWidth = 1.6; c.lineCap = "round"
                            const n = 6, gap = 0.5, step = Math.PI * 2 / n
                            for (let i = 0; i < n; i++) {
                                c.beginPath()
                                c.arc(20, 20, 15.5, i * step, i * step + step - gap)
                                c.stroke()
                            }
                        }
                        RotationAnimator on rotation {
                            from: 360; to: 0; duration: 2600
                            loops: Animation.Infinite; running: spinner.visible
                        }
                    }
                    // Núcleo que late
                    Rectangle {
                        anchors.centerIn: parent
                        width: 7; height: 7; radius: 4
                        color: root.accent
                        SequentialAnimation on scale {
                            loops: Animation.Infinite; running: spinner.visible
                            NumberAnimation { to: 1.7; duration: 520; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.8; duration: 520; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 118
                text: root.failed ? "Contraseña incorrecta" : (root.busy ? "Verificando…" : "")
                color: root.failed ? root.danger : root.dim
                font.family: root.font
                font.pixelSize: 14
                font.letterSpacing: root.busy ? 1.2 : 0
                opacity: text === "" ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }

        // ── Sesión (abajo a la izquierda) ───────────────────
        Rectangle {
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 36; bottomMargin: 34 }
            height: 40
            width: sessionRow.implicitWidth + 36
            radius: 20
            opacity: Math.max(0, root.intro * 2 - 1)
            color: sessMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.047, 0.055, 0.078, 0.55)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)
            Behavior on color { ColorAnimation { duration: 120 } }
            Row {
                id: sessionRow
                anchors.centerIn: parent
                spacing: 10
                Rectangle { width: 7; height: 7; radius: 4; color: root.accent; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: sessionBox.currentText
                    color: root.text
                    font.family: root.font
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
            }
            MouseArea {
                id: sessMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sessionBox.currentIndex = (sessionBox.currentIndex + 1) % sessionBox.count
            }
        }

        // ── Apagar / reiniciar (abajo a la derecha) ─────────
        Row {
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: 36; bottomMargin: 34 }
            spacing: 10
            opacity: Math.max(0, root.intro * 2 - 1)

            component PowerBtn: Rectangle {
                id: pb
                property string kind: "off"
                signal activated()
                width: 40; height: 40; radius: 20
                color: pm.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.047, 0.055, 0.078, 0.55)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 120 } }
                Canvas {
                    anchors.centerIn: parent
                    width: 18; height: 18
                    property color col: pm.containsMouse ? "#33ccff" : "#e6e8ee"
                    onColChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d"); c.reset()
                        c.strokeStyle = col; c.lineWidth = 2; c.lineCap = "round"; c.lineJoin = "round"
                        if (pb.kind === "off") {
                            c.beginPath(); c.arc(9, 10, 6.5, -Math.PI * 0.32, Math.PI * 1.32, false); c.stroke()
                            c.beginPath(); c.moveTo(9, 2); c.lineTo(9, 9); c.stroke()
                        } else {
                            c.beginPath(); c.arc(9, 9, 6.5, -Math.PI * 0.15, Math.PI * 1.55, false); c.stroke()
                            c.beginPath(); c.moveTo(13.5, 1.5); c.lineTo(15.5, 5); c.lineTo(11.5, 6); c.stroke()
                        }
                    }
                }
                MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: pb.activated() }
            }

            PowerBtn { kind: "reboot"; visible: sddm.canReboot;   onActivated: sddm.reboot() }
            PowerBtn { kind: "off";    visible: sddm.canPowerOff; onActivated: sddm.powerOff() }
        }
    }

    // ── Lógica de acceso ────────────────────────────────────
    function doLogin() {
        if (busy || pwd.text.length === 0) return
        failed = false
        busy = true
        sddm.login(userBox.currentValue, pwd.text, sessionBox.currentIndex)
    }
    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            pwd.text = ""
            root.failed = true
            shake.restart()
            pwd.forceActiveFocus()
        }
        function onLoginSucceeded() {
            root.done = true
        }
    }

    // Entrada escalonada
    NumberAnimation { id: introAnim; target: root; property: "intro"; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
    Component.onCompleted: { introAnim.start(); if (isMain) pwd.forceActiveFocus() }
}
