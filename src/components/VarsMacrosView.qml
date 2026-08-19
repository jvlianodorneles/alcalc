import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Engine.js" as Engine

Item {
    id: root

    signal requestRunMacro(string expr)

    property string newMacroName: ""
    property string newMacroExpr: ""
    property string macroSaveStatus: ""

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 16

            // =========================================================
            // SECTION 1: ACTIVE IN-MEMORY VARIABLES
            // =========================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: varsColumn.implicitHeight + 24
                color: backend.themeSurface
                radius: 8
                border.color: backend.themeBorder

                ColumnLayout {
                    id: varsColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "🧩 Active Variables in Memory"
                            color: backend.themeForeground
                            font.bold: true
                            font.pixelSize: 16
                            Layout.fillWidth: true
                        }

                        Button {
                            Layout.preferredHeight: 34
                            contentItem: Text { text: "Clear All Vars"; color: backend.themeError; font.bold: true; font.pixelSize: 12 }
                            background: Rectangle { color: backend.themeSurfaceVariant; border.color: backend.themeError; radius: 6 }
                            onClicked: backend.clearVars()
                        }
                    }

                    // Empty notice
                    Text {
                        visible: Object.keys(backend.varsMap).length === 0
                        text: "No variables stored yet. Assign variables in expressions using `:` (e.g. `5 : fingers` or `1..5 : vec`)."
                        color: backend.themeMuted
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    // Variables table
                    Repeater {
                        model: Object.keys(backend.varsMap)
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            color: index % 2 === 0 ? backend.themeSurfaceVariant : "transparent"
                            radius: 6

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 10

                                Text {
                                    text: modelData
                                    color: backend.themeAccent
                                    font.family: "Monospace, 'JetBrains Mono', monospace"
                                    font.bold: true
                                    font.pixelSize: 14
                                    Layout.preferredWidth: 100
                                }

                                Text {
                                    text: "= " + Engine.render(backend.varsMap[modelData], backend.places)
                                    color: backend.themeForeground
                                    font.family: "Monospace, 'JetBrains Mono', monospace"
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Button {
                                    Layout.preferredHeight: 28
                                    Layout.preferredWidth: 28
                                    contentItem: Text { text: "✕"; color: backend.themeMuted; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    background: Rectangle { color: "transparent" }
                                    onClicked: backend.removeVar(modelData)
                                }
                            }
                        }
                    }
                }
            }

            // =========================================================
            // SECTION 2: CUSTOM MACROS & FUNCTIONS
            // =========================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: macrosColumn.implicitHeight + 24
                color: backend.themeSurface
                radius: 8
                border.color: backend.themeBorder

                ColumnLayout {
                    id: macrosColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "🧮 Custom Expression Macros"
                        color: backend.themeForeground
                        font.bold: true
                        font.pixelSize: 16
                    }

                    Text {
                        text: "Define reusable formula templates. Use parameter names like `x`, `y` or `r` that can be assigned at runtime."
                        color: backend.themeMuted
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    // Add Macro Form
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: macroNameInput
                            Layout.preferredWidth: 130
                            Layout.preferredHeight: 40
                            placeholderText: "Macro name"
                            placeholderTextColor: backend.themeMuted
                            color: backend.themeForeground
                            font.pixelSize: 13
                            background: Rectangle {
                                color: backend.themeBackground
                                border.color: backend.themeBorder
                                radius: 6
                            }
                        }

                        TextField {
                            id: macroExprInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            placeholderText: "Template expression (e.g. x - 32 * 5 / 9)"
                            placeholderTextColor: backend.themeMuted
                            color: backend.themeForeground
                            font.pixelSize: 13
                            background: Rectangle {
                                color: backend.themeBackground
                                border.color: backend.themeBorder
                                radius: 6
                            }
                        }

                        Button {
                            Layout.preferredHeight: 40
                            Layout.preferredWidth: 90
                            contentItem: Text {
                                text: "+ Add"
                                color: "#ffffff"
                                font.bold: true
                                font.pixelSize: 13
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: backend.themeAccent
                                radius: 6
                            }
                            onClicked: {
                                var name = macroNameInput.text.trim();
                                var expr = macroExprInput.text.trim();
                                if (name.length > 0 && expr.length > 0) {
                                    backend.saveMacro(name, expr);
                                    macroNameInput.text = "";
                                    macroExprInput.text = "";
                                }
                            }
                        }
                    }

                    // Stored Macros List
                    Text {
                        visible: Object.keys(backend.macrosMap).length === 0
                        text: "No custom macros defined yet. Try adding `fahrenheit` with template `x - 32 * 5 / 9`!"
                        color: backend.themeMuted
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: Object.keys(backend.macrosMap)
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42
                            color: index % 2 === 0 ? backend.themeSurfaceVariant : "transparent"
                            radius: 6

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 10

                                Text {
                                    text: modelData
                                    color: backend.themeAccent
                                    font.family: "Monospace, 'JetBrains Mono', monospace"
                                    font.bold: true
                                    font.pixelSize: 14
                                    Layout.preferredWidth: 120
                                }

                                Text {
                                    text: "= " + backend.macrosMap[modelData]
                                    color: backend.themeForeground
                                    font.family: "Monospace, 'JetBrains Mono', monospace"
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Button {
                                    Layout.preferredHeight: 30
                                    Layout.preferredWidth: 70
                                    contentItem: Text {
                                        text: "▶ Test"
                                        color: backend.themeForeground
                                        font.bold: true
                                        font.pixelSize: 12
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: backend.themeBackground
                                        border.color: backend.themeBorder
                                        radius: 4
                                    }
                                    onClicked: root.requestRunMacro(modelData)
                                }

                                Button {
                                    Layout.preferredHeight: 30
                                    Layout.preferredWidth: 30
                                    contentItem: Text { text: "✕"; color: backend.themeMuted; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    background: Rectangle { color: "transparent" }
                                    onClicked: backend.removeMacro(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
