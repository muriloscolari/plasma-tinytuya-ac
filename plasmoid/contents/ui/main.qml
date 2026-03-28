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
    property bool   acOn:        false
    property int    currentTemp: 24
    property int    setTemp:     24
    property string mode:        "cold"
    property bool   ecoOn:       false
    property bool   lightOn:     false
    property bool   sleepOn:     false

    readonly property string apiBase: "http://localhost:8456"

    // ── Startup & polling ────────────────────────────────────────────────────
    Component.onCompleted: fetchStatus()

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: fetchStatus()
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
            opacity: root.acOn ? 1.0 : 0.5
            smooth: true
            antialiasing: true
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    // ── Full representation (popup) ──────────────────────────────────────────
    fullRepresentation: Item {
        implicitWidth: 340
        implicitHeight: 500

        Rectangle {
            anchors.fill: parent
            radius: 16
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#1a1a2e" }
                GradientStop { position: 1.0; color: "#16213e" }
            }

            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 12

                // ── Temperature display ──────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 180
                    radius: 14
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#2563eb" }
                        GradientStop { position: 1.0; color: "#1d4ed8" }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "TEMPERATURA ATUAL: " + root.currentTemp + "°C"
                            color: "#93c5fd"
                            font { pixelSize: 12; letterSpacing: 1.2 }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 24

                            // Minus button
                            Rectangle {
                                width: 44; height: 44; radius: 22
                                color: minusArea.containsMouse ? "#1d4ed8" : "#1e3a8a"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "−"
                                    color: "white"
                                    font.pixelSize: 26
                                }
                                MouseArea {
                                    id: minusArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.setTemp > 16) {
                                            root.setTemp--
                                            root.sendControl("set_temp", root.setTemp)
                                        }
                                    }
                                }
                            }

                            Text {
                                text: root.setTemp
                                color: "white"
                                font { pixelSize: 72; bold: true }
                            }

                            // Plus button
                            Rectangle {
                                width: 44; height: 44; radius: 22
                                color: plusArea.containsMouse ? "#1d4ed8" : "#1e3a8a"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    color: "white"
                                    font.pixelSize: 26
                                }
                                MouseArea {
                                    id: plusArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.setTemp < 30) {
                                            root.setTemp++
                                            root.sendControl("set_temp", root.setTemp)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Graus Celsius"
                            color: "#93c5fd"
                            font.pixelSize: 13
                        }
                    }
                }

                // ── Power buttons ─────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Ligar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 70; radius: 12
                        color: root.acOn ? "#1e3a8a" : (ligarHover.containsMouse ? "#1e293b" : "#0f172a")
                        Behavior on color { ColorAnimation { duration: 150 } }
                        border { color: root.acOn ? "#3b82f6" : "#1e293b"; width: 1 }
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 4
                            Text { Layout.alignment: Qt.AlignHCenter; text: "⏻"; color: "#4ade80"; font.pixelSize: 22 }
                            Text { Layout.alignment: Qt.AlignHCenter; text: "Ligar"; color: "white"; font.pixelSize: 12 }
                        }
                        MouseArea { id: ligarHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.acOn = true; root.sendControl("power_on", true) } }
                    }

                    // Desligar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 70; radius: 12
                        color: !root.acOn ? "#1e3a8a" : (desligarHover.containsMouse ? "#1e293b" : "#0f172a")
                        Behavior on color { ColorAnimation { duration: 150 } }
                        border { color: !root.acOn ? "#3b82f6" : "#1e293b"; width: 1 }
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 4
                            Text { Layout.alignment: Qt.AlignHCenter; text: "⏻"; color: "#f87171"; font.pixelSize: 22 }
                            Text { Layout.alignment: Qt.AlignHCenter; text: "Desligar"; color: "white"; font.pixelSize: 12 }
                        }
                        MouseArea { id: desligarHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.acOn = false; root.sendControl("power_off", false) } }
                    }
                }

                // ── Mode buttons ──────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [
                            { label: "Frio",   icon: "❄",  color: "#60a5fa", mode: "cold" },
                            { label: "Quente", icon: "🔥", color: "#fb923c", mode: "hot"  },
                            { label: "Auto",   icon: "✦",  color: "#c084fc", mode: "auto" },
                            { label: "Vento",  icon: "≋",  color: "#34d399", mode: "wind" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            height: 70; radius: 12
                            color: root.mode === modelData.mode ? "#1e3a8a" : (modeHover.containsMouse ? "#1e293b" : "#0f172a")
                            Behavior on color { ColorAnimation { duration: 150 } }
                            border { color: root.mode === modelData.mode ? "#3b82f6" : "#1e293b"; width: 1 }
                            ColumnLayout {
                                anchors.centerIn: parent; spacing: 4
                                Text { Layout.alignment: Qt.AlignHCenter; text: modelData.icon; color: modelData.color; font.pixelSize: 20 }
                                Text { Layout.alignment: Qt.AlignHCenter; text: modelData.label; color: "white"; font.pixelSize: 11 }
                            }
                            MouseArea { id: modeHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.mode = modelData.mode; root.sendControl("set_mode", modelData.mode) } }
                        }
                    }
                }

                // ── Extra buttons ─────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Luz
                    Rectangle {
                        Layout.fillWidth: true
                        height: 70; radius: 12
                        color: root.lightOn ? "#1e3a8a" : (luzHover.containsMouse ? "#1e293b" : "#0f172a")
                        Behavior on color { ColorAnimation { duration: 150 } }
                        border { color: root.lightOn ? "#3b82f6" : "#1e293b"; width: 1 }
                        ColumnLayout { anchors.centerIn: parent; spacing: 4
                            Text { Layout.alignment: Qt.AlignHCenter; text: "💡"; color: "#fde68a"; font.pixelSize: 20 }
                            Text { Layout.alignment: Qt.AlignHCenter; text: "Luz"; color: "white"; font.pixelSize: 11 }
                        }
                        MouseArea { id: luzHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.lightOn = !root.lightOn; root.sendControl("toggle_light", root.lightOn) } }
                    }

                    // Eco
                    Rectangle {
                        Layout.fillWidth: true
                        height: 70; radius: 12
                        color: root.ecoOn ? "#1e3a8a" : (ecoHover.containsMouse ? "#1e293b" : "#0f172a")
                        Behavior on color { ColorAnimation { duration: 150 } }
                        border { color: root.ecoOn ? "#3b82f6" : "#1e293b"; width: 1 }
                        ColumnLayout { anchors.centerIn: parent; spacing: 4
                            Text { Layout.alignment: Qt.AlignHCenter; text: "🌿"; color: "#4ade80"; font.pixelSize: 20 }
                            Text { Layout.alignment: Qt.AlignHCenter; text: "Eco"; color: "white"; font.pixelSize: 11 }
                        }
                        MouseArea { id: ecoHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.ecoOn = !root.ecoOn; root.sendControl("toggle_eco", root.ecoOn) } }
                    }

                    // Sono
                    Rectangle {
                        Layout.fillWidth: true
                        height: 70; radius: 12
                        color: root.sleepOn ? "#1e3a8a" : (sonoHover.containsMouse ? "#1e293b" : "#0f172a")
                        Behavior on color { ColorAnimation { duration: 150 } }
                        border { color: root.sleepOn ? "#3b82f6" : "#1e293b"; width: 1 }
                        ColumnLayout { anchors.centerIn: parent; spacing: 4
                            Text { Layout.alignment: Qt.AlignHCenter; text: "🌙"; color: "#818cf8"; font.pixelSize: 20 }
                            Text { Layout.alignment: Qt.AlignHCenter; text: "Sono"; color: "white"; font.pixelSize: 11 }
                        }
                        MouseArea { id: sonoHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.sleepOn = !root.sleepOn; root.sendControl("toggle_sleep", root.sleepOn) } }
                    }
                }
            }
        }
    }

    // ── HTTP helpers ─────────────────────────────────────────────────────────
    function fetchStatus() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", root.apiBase + "/api/status")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try {
                    var resp = JSON.parse(xhr.responseText)
                    if (resp.ok) {
                        var s = resp.status
                        root.acOn        = s.switch
                        root.setTemp     = Math.round(s.temp_set / 10)
                        root.currentTemp = Math.round((s.temp_cur || s.temp_set) / 10)
                        root.mode        = s.mode
                        root.ecoOn       = s.eco
                        root.lightOn     = s.light
                        root.sleepOn     = s.sleep
                    }
                } catch(e) {}
            }
        }
        xhr.send()
    }

    function sendControl(action, value) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", root.apiBase + "/api/control")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify({ action: action, value: value }))
    }
}
