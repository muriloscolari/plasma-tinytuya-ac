import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── Tray icon ────────────────────────────────────────────────────────────
    Plasmoid.icon: Qt.resolvedUrl("icon.png")
    Plasmoid.title: "Ar Condicionado"

    preferredRepresentation: Plasmoid.compactRepresentation

    onExpandedChanged: {
        if (expanded) {
            root.fetchStatus()
        }
    }

    // ── State ─────────────────────────────────────────────────────────────────
    property bool   acOn:             false
    property int    currentTemp:      24
    property int    setTemp:          24
    property string mode:             "cold"
    property string fanSpeed:         "auto"
    property bool   ecoOn:            false
    property bool   lightOn:          false
    property bool   sleepOn:          false
    property bool   swingOn:          false
    property bool   isDebouncingTemp: false

    readonly property string apiBase: "http://localhost:8456"
    property bool   backendOnline: false

    // ── Coalesced command queue state ─────────────────────────────────────────
    property var    pendingCommands: ({})
    property bool   controlInFlight: false

    // ── Mode Theme Metadata (Section 4 Palette) ───────────────────────────────
    readonly property var modeThemes: ({
        "cold": { label: "Frio",   icon: "❄️", color: "#4FC3F7", glow: "#0288D1", bg: "#14293a" },
        "hot":  { label: "Quente", icon: "🔥", color: "#FFB74D", glow: "#E65100", bg: "#332214" },
        "wind": { label: "Vento",  icon: "🍃", color: "#66BB6A", glow: "#2E7D32", bg: "#162d1e" },
        "wet":  { label: "Seco",   icon: "💧", color: "#4DD0E1", glow: "#00838F", bg: "#132c33" },
        "auto": { label: "Auto",   icon: "✦",  color: "#CE93D8", glow: "#7B1FA2", bg: "#2a1b33" }
    })

    readonly property var activeTheme: modeThemes[root.mode] || modeThemes["cold"]
    readonly property color modeColor: activeTheme.color
    readonly property color modeGlowColor: activeTheme.glow
    readonly property color modeBgColor: activeTheme.bg

    // ── Timers: Debounce (450ms) & Status Cooldown (1800ms) ──────────────────
    Timer {
        id: tempDebounceTimer
        interval: 450
        running: false
        repeat: false
        onTriggered: {
            root.isDebouncingTemp = false
            statusCooldownTimer.restart()
            root.sendControl("set_temp", root.setTemp)
        }
    }

    // Bloqueio temporário de status (1.8s) para evitar sobrescrever a UI após interação
    Timer {
        id: statusCooldownTimer
        interval: 1800
        running: false
        repeat: false
    }

    function changeTemp(newVal) {
        var clamped = Math.max(16, Math.min(30, Math.round(newVal)))
        if (root.setTemp === clamped && root.isDebouncingTemp) {
            tempDebounceTimer.restart()
            statusCooldownTimer.restart()
            return
        }
        root.setTemp = clamped
        root.isDebouncingTemp = true
        tempDebounceTimer.restart()
        statusCooldownTimer.restart()
    }

    // ── Startup & polling ──────────────────────────────────────────────────
    Timer {
        id: startupDelayTimer
        interval: 3000
        running: true
        repeat: false
        onTriggered: {
            root.fetchStatus()
            pollTimer.start()
        }
    }

    Timer {
        id: pollTimer
        interval: root.backendOnline ? 20000 : 10000
        running: false
        repeat: true
        triggeredOnStart: false
        onTriggered: root.fetchStatus()
    }

    // ── Compact (tray icon) ──────────────────────────────────────────────────
    compactRepresentation: Item {
        Image {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.8
            height: width
            source: "icon.png"
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectFit
            opacity: root.acOn ? 1.0 : 0.45
            smooth: true
            antialiasing: true
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: root.expanded = !root.expanded
        }
    }

    // ── Full representation (popup) ──────────────────────────────────────────
    fullRepresentation: Item {
        implicitWidth: 356
        implicitHeight: 520

        // Janela Principal (Paleta: #101018 a #171726)
        Rectangle {
            anchors.fill: parent
            radius: 16
            border {
                color: "#292945"
                width: 1
            }
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#101018" }
                GradientStop { position: 1.0; color: "#171726" }
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: 12

                // ── 1. CARD HERO DE TEMPERATURA COM SLIDER E BOTÕES ──────────
                Rectangle {
                    id: heroCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: 178
                    radius: 14
                    color: "#19192b"
                    border {
                        color: root.isDebouncingTemp ? root.modeColor : "#292945"
                        width: 1
                    }

                    // Permite ajustar temperatura com scroll do mouse em qualquer parte do card
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: function(wheel) {
                            if (wheel.angleDelta.y > 0) {
                                root.changeTemp(root.setTemp + 1)
                            } else if (wheel.angleDelta.y < 0) {
                                root.changeTemp(root.setTemp - 1)
                            }
                            wheel.accepted = true
                        }
                    }

                    ColumnLayout {
                        anchors {
                            fill: parent
                             leftMargin: 14
                            rightMargin: 14
                            topMargin: 12
                            bottomMargin: 12
                        }
                        spacing: 8

                        // a) Badges superiores: Modo ativo com cor temática e Temperatura Ambiente
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // Badge do Modo Ativo
                            Rectangle {
                                height: 24
                                radius: 12
                                implicitWidth: modeBadgeRow.implicitWidth + 16
                                color: root.acOn ? root.modeBgColor : "#222238"
                                border {
                                    color: root.acOn ? root.modeColor : "#2d2d48"
                                    width: 1
                                }

                                RowLayout {
                                    id: modeBadgeRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: root.acOn ? root.activeTheme.icon : "⏻"
                                        font.pixelSize: 11
                                        color: root.acOn ? root.modeColor : "#5E5E80"
                                    }
                                    Text {
                                        text: root.acOn ? root.activeTheme.label : "Desligado"
                                        color: root.acOn ? root.modeColor : "#9494B8"
                                        font {
                                            pixelSize: 11
                                            bold: true
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Badge de Temperatura Ambiente
                            Rectangle {
                                height: 24
                                radius: 12
                                implicitWidth: ambientBadgeRow.implicitWidth + 16
                                color: "#222238"
                                border {
                                    color: "#292945"
                                    width: 1
                                }

                                RowLayout {
                                    id: ambientBadgeRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: "🌡 Ambiente: " + root.currentTemp + "°C"
                                        color: "#9494B8"
                                        font {
                                            pixelSize: 11
                                            bold: true
                                        }
                                    }
                                }
                            }
                        }

                        // b) Bloco central: Botões [ - ] e [ + ] com auto-repeat ladeando o mostrador 48px bold
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 18

                            // Botão [ - ]
                            Rectangle {
                                width: 42
                                height: 42
                                radius: 11
                                color: minusArea.pressed ? root.modeBgColor : (minusArea.containsMouse ? "#2c2c48" : "#222238")
                                border {
                                    color: minusArea.pressed ? root.modeColor : (minusArea.containsMouse ? "#3d3d60" : "#2d2d48")
                                    width: 1
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "−"
                                    color: "#F0F0F8"
                                    font {
                                        pixelSize: 22
                                        bold: true
                                    }
                                }

                                Timer {
                                    id: minusRepeatTimer
                                    interval: 120
                                    repeat: true
                                    running: false
                                    onTriggered: root.changeTemp(root.setTemp - 1)
                                }

                                Timer {
                                    id: minusInitialDelay
                                    interval: 380
                                    repeat: false
                                    running: minusArea.pressed
                                    onTriggered: {
                                        if (minusArea.pressed) {
                                            minusRepeatTimer.start()
                                        }
                                    }
                                    onRunningChanged: {
                                        if (!running) {
                                            minusRepeatTimer.stop()
                                        }
                                    }
                                }

                                MouseArea {
                                    id: minusArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: root.changeTemp(root.setTemp - 1)
                                }
                            }

                            // Mostrador Central de Temperatura Alvo
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.setTemp + "°C"
                                    color: "#F0F0F8"
                                    font {
                                        pixelSize: 48
                                        bold: true
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.isDebouncingTemp
                                        ? ("⏳ Definindo " + root.setTemp + "°C...")
                                        : "TEMPERATURA ALVO"
                                    color: root.isDebouncingTemp ? root.modeColor : "#9494B8"
                                    font {
                                        pixelSize: 10
                                        bold: true
                                        letterSpacing: root.isDebouncingTemp ? 0.4 : 1.2
                                    }
                                }
                            }

                            // Botão [ + ]
                            Rectangle {
                                width: 42
                                height: 42
                                radius: 11
                                color: plusArea.pressed ? root.modeBgColor : (plusArea.containsMouse ? "#2c2c48" : "#222238")
                                border {
                                    color: plusArea.pressed ? root.modeColor : (plusArea.containsMouse ? "#3d3d60" : "#2d2d48")
                                    width: 1
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    color: "#F0F0F8"
                                    font {
                                        pixelSize: 22
                                        bold: true
                                    }
                                }

                                Timer {
                                    id: plusRepeatTimer
                                    interval: 120
                                    repeat: true
                                    running: false
                                    onTriggered: root.changeTemp(root.setTemp + 1)
                                }

                                Timer {
                                    id: plusInitialDelay
                                    interval: 380
                                    repeat: false
                                    running: plusArea.pressed
                                    onTriggered: {
                                        if (plusArea.pressed) {
                                            plusRepeatTimer.start()
                                        }
                                    }
                                    onRunningChanged: {
                                        if (!running) {
                                            plusRepeatTimer.stop()
                                        }
                                    }
                                }

                                MouseArea {
                                    id: plusArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: root.changeTemp(root.setTemp + 1)
                                }
                            }
                        }

                        // c) Barrinha deslizante (Slider) 16°C a 30°C com cor dinâmica do modo ativo
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "16°"
                                color: "#5E5E80"
                                font {
                                    pixelSize: 11
                                    bold: true
                                }
                            }

                            Item {
                                id: sliderContainer
                                Layout.fillWidth: true
                                height: 24

                                readonly property real progress: Math.max(0, Math.min(1, (root.setTemp - 16) / 14.0))

                                // Trilho inativo
                                Rectangle {
                                    id: sliderTrack
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 8
                                    radius: 4
                                    color: "#222238"
                                    border {
                                        color: "#2d2d48"
                                        width: 1
                                    }

                                    // Preenchimento ativo com cor temática do modo
                                    Rectangle {
                                        width: Math.max(height, parent.width * sliderContainer.progress)
                                        height: parent.height
                                        radius: 4
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: root.modeGlowColor }
                                            GradientStop { position: 1.0; color: root.modeColor }
                                        }
                                    }
                                }

                                // Thumb (Bolinha do Slider)
                                Rectangle {
                                    id: sliderThumb
                                    width: 18
                                    height: 18
                                    radius: 9
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.max(0, Math.min(parent.width - width, sliderContainer.progress * (parent.width - width)))
                                    color: root.modeColor
                                    border {
                                        color: "#F0F0F8"
                                        width: sliderMouse.pressed || sliderMouse.containsMouse ? 2 : 1
                                    }
                                    scale: sliderMouse.pressed ? 1.12 : 1.0
                                }

                                MouseArea {
                                    id: sliderMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    function updateFromMouse(mx) {
                                        var ratio = Math.max(0, Math.min(1, mx / width))
                                        var target = Math.round(16 + ratio * 14)
                                        root.changeTemp(target)
                                    }

                                    onPressed: function(mouse) {
                                        updateFromMouse(mouse.x)
                                    }
                                    onPositionChanged: function(mouse) {
                                        if (pressed) {
                                            updateFromMouse(mouse.x)
                                        }
                                    }
                                    onWheel: function(wheel) {
                                        if (wheel.angleDelta.y > 0) {
                                            root.changeTemp(root.setTemp + 1)
                                        } else if (wheel.angleDelta.y < 0) {
                                            root.changeTemp(root.setTemp - 1)
                                        }
                                        wheel.accepted = true
                                    }
                                }
                            }

                            Text {
                                text: "30°"
                                color: "#5E5E80"
                                font {
                                    pixelSize: 11
                                    bold: true
                                }
                            }
                        }
                    }
                }

                // ── 2. BOTÕES DE ENERGIA (LIGAR / DESLIGAR) ──────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Botão Ligar (Verde #1B5E20 -> #2E7D32 com borda #388E3C)
                    Rectangle {
                        Layout.fillWidth: true
                        height: 44
                        radius: 10
                        border {
                            color: root.acOn ? "#388E3C" : (ligarHover.containsMouse ? "#388E3C" : "#2d2d48")
                            width: 1
                        }
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: root.acOn ? "#2E7D32" : (ligarHover.containsMouse ? "#1B5E20" : "#222238")
                            }
                            GradientStop {
                                position: 1.0
                                color: root.acOn ? "#1B5E20" : (ligarHover.containsMouse ? "#144718" : "#222238")
                            }
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "⏻"
                                color: root.acOn ? "#F0F0F8" : "#66BB6A"
                                font.pixelSize: 15
                            }
                            Text {
                                text: "Ligar"
                                color: root.acOn ? "#F0F0F8" : "#9494B8"
                                font {
                                    pixelSize: 12
                                    bold: true
                                }
                            }
                        }

                        MouseArea {
                            id: ligarHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.acOn = true
                                statusCooldownTimer.restart()
                                root.sendControl("power_on", true)
                            }
                        }
                    }

                    // Botão Desligar (Vermelho #8E1616 -> #B71C1C com borda #C62828)
                    Rectangle {
                        Layout.fillWidth: true
                        height: 44
                        radius: 10
                        border {
                            color: !root.acOn ? "#C62828" : (desligarHover.containsMouse ? "#C62828" : "#2d2d48")
                            width: 1
                        }
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: !root.acOn ? "#B71C1C" : (desligarHover.containsMouse ? "#8E1616" : "#222238")
                            }
                            GradientStop {
                                position: 1.0
                                color: !root.acOn ? "#8E1616" : (desligarHover.containsMouse ? "#6b1111" : "#222238")
                            }
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "⏻"
                                color: !root.acOn ? "#F0F0F8" : "#EF5350"
                                font.pixelSize: 15
                            }
                            Text {
                                text: "Desligar"
                                color: !root.acOn ? "#F0F0F8" : "#9494B8"
                                font {
                                    pixelSize: 12
                                    bold: true
                                }
                            }
                        }

                        MouseArea {
                            id: desligarHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.acOn = false
                                statusCooldownTimer.restart()
                                root.sendControl("power_off", false)
                            }
                        }
                    }
                }

                // ── 3. MODOS DE OPERAÇÃO (DP 4) ──────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "MODO DE OPERAÇÃO"
                        color: "#5E5E80"
                        font {
                            pixelSize: 10
                            bold: true
                            letterSpacing: 1.2
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: [
                                { mode: "cold", label: "Frio",   icon: "❄️", color: "#4FC3F7", glow: "#0288D1", bg: "#14293a" },
                                { mode: "hot",  label: "Quente", icon: "🔥", color: "#FFB74D", glow: "#E65100", bg: "#332214" },
                                { mode: "wind", label: "Vento",  icon: "🍃", color: "#66BB6A", glow: "#2E7D32", bg: "#162d1e" },
                                { mode: "wet",  label: "Seco",   icon: "💧", color: "#4DD0E1", glow: "#00838F", bg: "#132c33" },
                                { mode: "auto", label: "Auto",   icon: "✦",  color: "#CE93D8", glow: "#7B1FA2", bg: "#2a1b33" }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool isSelected: root.mode === modelData.mode

                                Layout.fillWidth: true
                                height: 54
                                radius: 10
                                color: isSelected ? modelData.bg : (modeHover.containsMouse ? "#2c2c48" : "#222238")
                                border {
                                    color: isSelected ? modelData.color : "#2d2d48"
                                    width: 1
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.icon
                                        color: modelData.color
                                        font.pixelSize: 16
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.label
                                        color: isSelected ? modelData.color : "#9494B8"
                                        font {
                                            pixelSize: 11
                                            bold: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: modeHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.mode = modelData.mode
                                        statusCooldownTimer.restart()
                                        root.sendControl("set_mode", modelData.mode)
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 4. INTENSIDADE DO VENTO (DP 5) ───────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "INTENSIDADE DO VENTO"
                        color: "#5E5E80"
                        font {
                            pixelSize: 10
                            bold: true
                            letterSpacing: 1.2
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: [
                                { key: "auto", label: "Auto",  icon: "🅰" },
                                { key: "low",  label: "Baixo", icon: "🍃" },
                                { key: "mid",  label: "Médio", icon: "💨" },
                                { key: "high", label: "Alto",  icon: "🌪️" }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool isSelected: root.fanSpeed === modelData.key

                                Layout.fillWidth: true
                                height: 38
                                radius: 8
                                color: isSelected ? "#16384c" : (fanHover.containsMouse ? "#2c2c48" : "#222238")
                                border {
                                    color: isSelected ? "#4FC3F7" : "#2d2d48"
                                    width: 1
                                }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: modelData.icon
                                        font.pixelSize: 11
                                    }
                                    Text {
                                        text: modelData.label
                                        color: isSelected ? "#4FC3F7" : "#9494B8"
                                        font {
                                            pixelSize: 11
                                            bold: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: fanHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.fanSpeed = modelData.key
                                        statusCooldownTimer.restart()
                                        root.sendControl("set_fan", modelData.key)
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 5. FUNÇÕES EXTRAS (DP 13, 8, 102, 33) ────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "FUNÇÕES EXTRAS"
                        color: "#5E5E80"
                        font {
                            pixelSize: 10
                            bold: true
                            letterSpacing: 1.2
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Luz / Visor (DP 13)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 52
                            radius: 10
                            color: root.lightOn ? "#16384c" : (luzHover.containsMouse ? "#2c2c48" : "#222238")
                            border {
                                color: root.lightOn ? "#4FC3F7" : "#2d2d48"
                                width: 1
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "💡"
                                    font.pixelSize: 16
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Visor"
                                    color: root.lightOn ? "#F0F0F8" : "#9494B8"
                                    font {
                                        pixelSize: 11
                                        bold: true
                                    }
                                }
                            }

                            MouseArea {
                                id: luzHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.lightOn = !root.lightOn
                                    statusCooldownTimer.restart()
                                    root.sendControl("toggle_light", root.lightOn)
                                }
                            }
                        }

                        // Modo Eco (DP 8)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 52
                            radius: 10
                            color: root.ecoOn ? "#162d1e" : (ecoHover.containsMouse ? "#2c2c48" : "#222238")
                            border {
                                color: root.ecoOn ? "#66BB6A" : "#2d2d48"
                                width: 1
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "🌿"
                                    font.pixelSize: 16
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Eco"
                                    color: root.ecoOn ? "#F0F0F8" : "#9494B8"
                                    font {
                                        pixelSize: 11
                                        bold: true
                                    }
                                }
                            }

                            MouseArea {
                                id: ecoHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.ecoOn = !root.ecoOn
                                    statusCooldownTimer.restart()
                                    root.sendControl("toggle_eco", root.ecoOn)
                                }
                            }
                        }

                        // Modo Dormir / Sono (DP 102)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 52
                            radius: 10
                            color: root.sleepOn ? "#2a1b33" : (sonoHover.containsMouse ? "#2c2c48" : "#222238")
                            border {
                                color: root.sleepOn ? "#CE93D8" : "#2d2d48"
                                width: 1
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "🌙"
                                    font.pixelSize: 16
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Sono"
                                    color: root.sleepOn ? "#F0F0F8" : "#9494B8"
                                    font {
                                        pixelSize: 11
                                        bold: true
                                    }
                                }
                            }

                            MouseArea {
                                id: sonoHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.sleepOn = !root.sleepOn
                                    statusCooldownTimer.restart()
                                    root.sendControl("toggle_sleep", root.sleepOn)
                                }
                            }
                        }

                        // Oscilar / Swing (DP 33)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 52
                            radius: 10
                            color: root.swingOn ? "#132c33" : (swingHover.containsMouse ? "#2c2c48" : "#222238")
                            border {
                                color: root.swingOn ? "#4DD0E1" : "#2d2d48"
                                width: 1
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "↕️"
                                    font.pixelSize: 16
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Oscilar"
                                    color: root.swingOn ? "#F0F0F8" : "#9494B8"
                                    font {
                                        pixelSize: 11
                                        bold: true
                                    }
                                }
                            }

                            MouseArea {
                                id: swingHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.swingOn = !root.swingOn
                                    statusCooldownTimer.restart()
                                    root.sendControl("toggle_swing", root.swingOn)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── HTTP helpers com Coalescência de Comandos e Proteção de Debounce ─────
    function fetchStatus() {
        // Não sobrescreve a interface durante interação ou envio ativo
        if (root.isDebouncingTemp || tempDebounceTimer.running || statusCooldownTimer.running || root.controlInFlight) {
            return
        }

        var xhr = new XMLHttpRequest()
        xhr.open("GET", root.apiBase + "/api/status")
        xhr.timeout = 4500
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return
            if (xhr.status === 200) {
                try {
                    var resp = JSON.parse(xhr.responseText)
                    if (resp.ok) {
                        root.backendOnline = true
                        var s = resp.status
                        if (!statusCooldownTimer.running && !root.controlInFlight) {
                            root.acOn        = Boolean(s.switch)
                            if (!root.isDebouncingTemp && !tempDebounceTimer.running) {
                                root.setTemp = Math.round(s.temp_set / 10)
                            }
                            root.currentTemp = Math.round((s.temp_cur || s.temp_set) / 10)
                            root.mode        = s.mode || "cold"
                            root.fanSpeed    = s.fan_speed || "auto"
                            root.ecoOn       = Boolean(s.eco)
                            root.lightOn     = Boolean(s.light)
                            root.sleepOn     = Boolean(s.sleep)
                            root.swingOn     = Boolean(s.swing)
                        }
                    }
                } catch(e) {
                    root.backendOnline = false
                }
            } else {
                root.backendOnline = false
            }
        }
        xhr.ontimeout = function() { root.backendOnline = false }
        xhr.onerror   = function() { root.backendOnline = false }
        xhr.send()
    }

    function sendControl(action, value) {
        // Coalescência: se já houver comando para a mesma ação na fila, substitui pelo mais recente
        var queue = root.pendingCommands
        queue[action] = value
        root.pendingCommands = queue
        processNextCommand()
    }

    function processNextCommand() {
        if (root.controlInFlight) {
            return
        }

        var queue = root.pendingCommands
        var keys = Object.keys(queue)
        if (keys.length === 0) {
            return
        }

        var nextAction = keys[0]
        var nextValue = queue[nextAction]
        delete queue[nextAction]
        root.pendingCommands = queue

        root.controlInFlight = true
        statusCooldownTimer.restart()

        var xhr = new XMLHttpRequest()
        xhr.open("POST", root.apiBase + "/api/control")
        xhr.timeout = 5000
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return
            root.controlInFlight = false
            statusCooldownTimer.restart()
            processNextCommand()
        }
        xhr.ontimeout = function() {
            root.controlInFlight = false
            processNextCommand()
        }
        xhr.onerror = function() {
            root.controlInFlight = false
            processNextCommand()
        }
        xhr.send(JSON.stringify({ action: nextAction, value: nextValue }))
    }
}
