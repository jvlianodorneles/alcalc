import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Engine.js" as Engine

Item {
    id: root

    signal requestLoadFormula(string expr)

    property var allSamples: Engine.getSampleList()
    property string selectedCategory: "all"
    property string searchQuery: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // Search and Category Pills
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                color: backend.themeSurface
                radius: 6
                border.color: searchFormulaField.activeFocus ? backend.themeAccent : backend.themeBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 6

                    Text { text: " 🔍"; color: backend.themeMuted; font.pixelSize: 14 }
                    TextField {
                        id: searchFormulaField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: "Search formulas (e.g. celsius, prime, dice, kinetic)..."
                        placeholderTextColor: backend.themeMuted
                        color: backend.themeForeground
                        font.pixelSize: 13
                        background: null
                        onTextChanged: root.searchQuery = text.toLowerCase()
                    }
                    Button {
                        visible: searchFormulaField.text.length > 0
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        flat: true
                        contentItem: Text { text: "✕"; color: backend.themeMuted; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: searchFormulaField.text = ""
                    }
                }
            }
        }

        // Category Filter Chips
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            contentHeight: 36
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            RowLayout {
                spacing: 6

                Repeater {
                    model: [
                        { key: "all", label: "All Formulas" },
                        { key: "basic", label: "Basic Arithmetic" },
                        { key: "clumps", label: "Clumps & Sequences" },
                        { key: "text", label: "Text & Ciphers" },
                        { key: "tricks", label: "Tricks & Logic" },
                        { key: "science", label: "Science & Physics" },
                    ]
                    delegate: Button {
                        checkable: true
                        checked: root.selectedCategory === modelData.key
                        contentItem: Text {
                            text: modelData.label
                            color: parent.checked ? "#ffffff" : backend.themeForeground
                            font.bold: parent.checked
                            font.pixelSize: 12
                        }
                        background: Rectangle {
                            color: parent.checked ? backend.themeAccent : (parent.hovered ? backend.themeSurfaceVariant : backend.themeSurface)
                            border.color: parent.checked ? backend.themeAccent : backend.themeBorder
                            radius: 16
                        }
                        onClicked: root.selectedCategory = modelData.key
                    }
                }
            }
        }

        // Formulas List
        ListView {
            id: formulaListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: {
                var list = root.allSamples || [];
                var res = [];
                for (var i = 0; i < list.length; i++) {
                    var item = list[i];
                    var matchCat = (root.selectedCategory === "all" || item.category === root.selectedCategory);
                    var matchQuery = (root.searchQuery === "" ||
                        item.title.toLowerCase().indexOf(root.searchQuery) !== -1 ||
                        (item.desc && item.desc.toLowerCase().indexOf(root.searchQuery) !== -1) ||
                        item.expr.toLowerCase().indexOf(root.searchQuery) !== -1);
                    if (matchCat && matchQuery) {
                        res.push(item);
                    }
                }
                return res;
            }

            delegate: Rectangle {
                width: formulaListView.width
                height: cardLayout.implicitHeight + 20
                color: backend.themeSurface
                radius: 8
                border.color: backend.themeBorder
                border.width: 1

                ColumnLayout {
                    id: cardLayout
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: modelData.title
                            color: backend.themeForeground
                            font.bold: true
                            font.pixelSize: 14
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: catLabel.implicitWidth + 12
                            color: backend.themeSurfaceVariant
                            radius: 10
                            border.color: backend.themeBorder
                            Text {
                                id: catLabel
                                anchors.centerIn: parent
                                text: modelData.categoryName || modelData.category
                                color: backend.themeMuted
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                    }

                    Text {
                        visible: modelData.desc !== undefined && modelData.desc !== ""
                        text: modelData.desc || ""
                        color: backend.themeMuted
                        font.pixelSize: 12
                        font.italic: true
                        Layout.fillWidth: true
                    }

                    // Expression Box + Run Button
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            color: backend.themeBackground
                            radius: 6
                            border.color: backend.themeBorder

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6

                                Text {
                                    text: modelData.expr
                                    color: backend.themeAccent
                                    font.family: "Monospace"
                                    font.pixelSize: 13
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        Button {
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: 86
                            contentItem: Text {
                                text: "▶ Run"
                                color: "#ffffff"
                                font.bold: true
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.down ? Qt.darker(backend.themeAccent, 1.2) : backend.themeAccent
                                radius: 6
                            }
                            onClicked: root.requestLoadFormula(modelData.expr)
                        }
                    }
                }
            }
        }
    }
}
