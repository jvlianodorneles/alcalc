import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    signal requestLoadExpression(string expr)

    property string searchQuery: ""
    property string copiedRowIndex: ""

    Timer {
        id: copiedRowTimer
        interval: 1500
        onTriggered: root.copiedRowIndex = ""
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // Header & Search Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                color: backend.themeSurface
                radius: 8
                border.color: searchField.activeFocus ? backend.themeAccent : backend.themeBorder
                border.width: searchField.activeFocus ? 2 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    Text {
                        text: " 🔍"
                        color: backend.themeMuted
                        font.pixelSize: 15
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: "Search calculations in tape..."
                        placeholderTextColor: backend.themeMuted
                        color: backend.themeForeground
                        font.pixelSize: 14
                        background: null
                        onTextChanged: root.searchQuery = text.toLowerCase()
                    }

                    Button {
                        visible: searchField.text.length > 0
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        flat: true
                        contentItem: Text { text: "✕"; color: backend.themeMuted; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 13 }
                        onClicked: searchField.text = ""
                    }
                }
            }

            Button {
                Layout.preferredHeight: 42
                Layout.preferredWidth: 96
                contentItem: Text {
                    text: "󰆏 Export"
                    color: backend.themeForeground
                    font.bold: true
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.down ? backend.themeSurfaceVariant : backend.themeSurface
                    border.color: backend.themeBorder
                    radius: 8
                }
                onClicked: {
                    var hist = backend.historyList;
                    if (!hist || hist.length === 0) return;
                    var textOut = "# Alcalc Calculation Tape\n";
                    for (var i = 0; i < hist.length; i++) {
                        textOut += "[" + hist[i].time + "] " + hist[i].expr + " = " + hist[i].result + "\n";
                    }
                    backend.copyToClipboard(textOut);
                }
            }

            Button {
                Layout.preferredHeight: 42
                Layout.preferredWidth: 88
                contentItem: Text {
                    text: "Clear All"
                    color: backend.themeError
                    font.bold: true
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.down ? backend.themeSurfaceVariant : backend.themeSurface
                    border.color: backend.themeError
                    radius: 8
                }
                onClicked: backend.clearHistory()
            }
        }

        // Empty state
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !backend.historyList || backend.historyList.length === 0
            color: "transparent"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                Text {
                    text: "📜"
                    font.pixelSize: 52
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: "No calculations in tape yet"
                    color: backend.themeForeground
                    font.bold: true
                    font.pixelSize: 17
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: "Your evaluated expressions will appear here automatically."
                    color: backend.themeMuted
                    font.pixelSize: 14
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // History List
        ListView {
            id: historyListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: backend.historyList && backend.historyList.length > 0
            clip: true
            spacing: 8
            model: backend.historyList

            delegate: Rectangle {
                id: rowDelegate
                width: historyListView.width
                height: rowLayout.implicitHeight + 20
                visible: root.searchQuery === "" ||
                         (modelData.expr && modelData.expr.toLowerCase().indexOf(root.searchQuery) !== -1) ||
                         (modelData.result && modelData.result.toLowerCase().indexOf(root.searchQuery) !== -1)
                color: index % 2 === 0 ? backend.themeSurface : backend.themeSurfaceVariant
                radius: 8
                border.color: backend.themeBorder
                border.width: 1

                RowLayout {
                    id: rowLayout
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: modelData.time || ""
                        color: backend.themeMuted
                        font.pixelSize: 12
                        Layout.preferredWidth: 60
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: modelData.expr || ""
                            color: backend.themeForeground
                            font.family: "Monospace, 'JetBrains Mono', monospace"
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "= " + (modelData.result || "")
                            color: modelData.isError ? backend.themeError : backend.themeAccent
                            font.family: "Monospace, 'JetBrains Mono', monospace"
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // 1-Click Load into input
                    Button {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 80
                        contentItem: Text {
                            text: "󰑐 Use"
                            color: backend.themeForeground
                            font.bold: true
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.down ? backend.themeSurfaceVariant : backend.themeBackground
                            border.color: backend.themeBorder
                            radius: 6
                        }
                        onClicked: root.requestLoadExpression(modelData.expr)
                    }

                    // 1-Click Copy Result
                    Button {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 84
                        contentItem: Text {
                            text: root.copiedRowIndex === String(index) ? "✓" : "󰆏 Copy"
                            color: root.copiedRowIndex === String(index) ? backend.themeSuccess : backend.themeForeground
                            font.bold: true
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.down ? backend.themeSurfaceVariant : backend.themeBackground
                            border.color: backend.themeBorder
                            radius: 6
                        }
                        onClicked: {
                            backend.copyToClipboard(modelData.result);
                            root.copiedRowIndex = String(index);
                            copiedRowTimer.restart();
                        }
                    }

                    // Remove entry
                    Button {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 36
                        contentItem: Text {
                            text: "✕"
                            color: backend.themeMuted
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.down ? backend.themeSurfaceVariant : "transparent"
                            radius: 6
                        }
                        onClicked: backend.removeHistoryEntry(index)
                    }
                }
            }
        }
    }
}
