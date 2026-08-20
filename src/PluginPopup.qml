import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import "Engine.js" as Engine

ApplicationWindow {
    id: popupWin
    width: 380
    height: 480
    minimumWidth: 320
    minimumHeight: 380
    visible: true
    title: "Alcalc"

    readonly property bool darkMode: backend.darkMode
    readonly property real textScale: backend.textScale

    // Theme palette matching the authentic classic Paper Tape design
    readonly property color colBg: darkMode ? "#181825" : "#f0efe9"
    readonly property color colTapeBg: darkMode ? "#11111b" : "#ffffff"
    readonly property color colBorder: darkMode ? "#313244" : "#d8d6cc"
    readonly property color colPrompt: darkMode ? "#89b4fa" : "#4e61b1"
    readonly property color colText: darkMode ? "#cdd6f4" : "#1e1e2e"
    readonly property color colResult: darkMode ? "#89b4fa" : "#2b3fa6"
    readonly property color colError: darkMode ? "#f38ba8" : "#c53030"
    readonly property color colMuted: darkMode ? "#6c7086" : "#787670"
    readonly property color colBtnBg: darkMode ? "#1e1e2e" : "#eae8e0"
    readonly property color colBtnBorder: darkMode ? "#45475a" : "#c8c6bc"
    readonly property color colReturnBg: darkMode ? "#313244" : "#232220"
    readonly property color colReturnFg: darkMode ? "#cdd6f4" : "#ffffff"

    Material.theme: darkMode ? Material.Dark : Material.Light
    color: colBg

    property int historyIndex: -1

    function evaluateCurrent(isExplain) {
        var rawExpr = inputField.text.toUpperCase().trim();
        if (rawExpr.length === 0) return;

        // Check for quick helper commands
        if (rawExpr === "CLEAR" || rawExpr === "CLEAR TAPE") {
            backend.clearHistory();
            inputField.text = "";
            return;
        }
        if (rawExpr === "FORGET" || rawExpr === "FORGET ALL") {
            backend.clearVars();
            inputField.text = "";
            return;
        }

        // Expand any macros
        var macroExpanded = Engine.expandMacros(backend.macrosMap, rawExpr);
        var exprToEval = macroExpanded.expandedExpr;

        var userVars = {};
        for (var k in backend.varsMap) {
            userVars[k] = backend.varsMap[k];
        }

        var evalFn = isExplain ? Engine.explainExpression : Engine.evaluateExpression;
        var res = evalFn(exprToEval, userVars, backend.places, backend.radians);

        if (res.kind === "error") {
            var smartTip = Engine.getSmartErrorTip(res.text, rawExpr);
            var errDisplay = res.text;
            if (smartTip && smartTip.tip) {
                errDisplay += "\n  💡 " + smartTip.tip;
            }
            backend.saveHistoryEntry(rawExpr, errDisplay, true);
        } else {
            var resultStr = "";
            if (res.kind === "answer") {
                resultStr = res.text;
                backend.saveVar("ANS", res.value);
            } else {
                resultStr = "(Stored)";
            }

            // Sync updated variables back to backend
            if (res.machine && res.machine.vars) {
                for (var v in res.machine.vars) {
                    backend.saveVar(v, res.machine.vars[v]);
                }
                if (res.machine.places !== backend.places) {
                    backend.setPlaces(res.machine.places);
                }
                if (res.machine.radians !== backend.radians) {
                    backend.setRadians(res.machine.radians);
                }
            }

            if (isExplain && res.steps && res.steps.length > 0) {
                var explainOut = "";
                for (var s = 0; s < res.steps.length; s++) {
                    explainOut += (s + 1) + ". " + res.steps[s].expr + " ➔ " + res.steps[s].result + "\n";
                }
                explainOut += "= " + resultStr;
                backend.saveHistoryEntry(rawExpr, explainOut, false);
            } else {
                backend.saveHistoryEntry(rawExpr, resultStr, false);
            }
        }

        inputField.text = "";
        popupWin.historyIndex = -1;
        tapeListView.positionViewAtBeginning();
    }

    // Shortcuts
    Shortcut { sequence: "Ctrl+L"; onActivated: inputField.text = "" }
    Shortcut { sequence: "Ctrl+K"; onActivated: backend.clearHistory() }
    Shortcut { sequence: "Esc"; onActivated: {
        if (inputField.text.length > 0) {
            inputField.text = "";
        } else {
            popupWin.close();
        }
    }}

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24

            Text {
                text: "ALCALC"
                color: colPrompt
                font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 2
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "PAPER TAPE"
                color: colMuted
                font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                font.pixelSize: 11
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // Paper Tape View (Feeds Bottom-to-Top)
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: colTapeBg
            border.color: colBorder
            border.width: 1

            ListView {
                id: tapeListView
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                spacing: 8
                verticalLayoutDirection: ListView.BottomToTop
                model: backend.historyList

                footer: ColumnLayout {
                    width: tapeListView.width
                    spacing: 4

                    Text {
                        text: "Type expression and press Return (or Shift+Return for Explain)."
                        color: colMuted
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                        font.pixelSize: 12
                        font.italic: true
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    Item { Layout.preferredHeight: 6 }
                }

                delegate: ColumnLayout {
                    width: tapeListView.width
                    spacing: 2

                    // Prompt & Expression line
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: "!"
                            color: colPrompt
                            font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                            font.pixelSize: 13
                            font.bold: true
                            Layout.rightMargin: 6
                        }

                        Text {
                            text: modelData.expr || ""
                            color: colText
                            font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                            font.pixelSize: 13
                            font.bold: true
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    inputField.text = modelData.expr.toUpperCase();
                                    inputField.cursorPosition = modelData.expr.length;
                                    inputField.forceActiveFocus();
                                }
                            }
                        }
                    }

                    // Result line
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: modelData.result || ""
                            color: modelData.isError ? colError : colResult
                            font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                            font.pixelSize: 13
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    backend.copyToClipboard(modelData.result);
                                }
                            }
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                }
            }
        }

        // Input Bar + RETURN Button
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            Layout.minimumHeight: 38
            Layout.maximumHeight: 38
            spacing: 8

            // Input Box
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                Layout.minimumHeight: 38
                Layout.maximumHeight: 38
                color: colTapeBg
                border.color: inputField.activeFocus ? colText : colBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    Text {
                        text: "!"
                        color: colPrompt
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                        font.pixelSize: 14
                        font.bold: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 6
                        Layout.alignment: Qt.AlignVCenter
                    }

                    TextField {
                        id: inputField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: colText
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                        font.pixelSize: 13
                        font.capitalization: Font.AllUppercase
                        background: null
                        padding: 0
                        leftPadding: 0
                        rightPadding: 6
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        selectByMouse: true

                        Component.onCompleted: forceActiveFocus()

                        onTextChanged: {
                            var upper = text.toUpperCase();
                            if (text !== upper) {
                                var cur = cursorPosition;
                                text = upper;
                                cursorPosition = cur;
                            }
                        }

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    popupWin.evaluateCurrent(true);
                                } else {
                                    popupWin.evaluateCurrent(false);
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                var hist = backend.historyList;
                                if (hist && hist.length > 0) {
                                    popupWin.historyIndex = Math.min(hist.length - 1, popupWin.historyIndex + 1);
                                    inputField.text = hist[popupWin.historyIndex].expr.toUpperCase();
                                    inputField.cursorPosition = inputField.text.length;
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                var hist2 = backend.historyList;
                                if (hist2 && popupWin.historyIndex > 0) {
                                    popupWin.historyIndex--;
                                    inputField.text = hist2[popupWin.historyIndex].expr.toUpperCase();
                                    inputField.cursorPosition = inputField.text.length;
                                } else if (popupWin.historyIndex === 0) {
                                    popupWin.historyIndex = -1;
                                    inputField.text = "";
                                }
                                event.accepted = true;
                            }
                        }
                    }
                }
            }

            // RETURN Button
            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 38
                Layout.minimumHeight: 38
                Layout.maximumHeight: 38
                color: returnMouseArea.pressed ? Qt.darker(colReturnBg, 1.2) : colReturnBg
                border.color: colReturnBg
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "RETURN"
                    color: colReturnFg
                    font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                    font.bold: true
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }

                MouseArea {
                    id: returnMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: popupWin.evaluateCurrent(false)
                }
            }
        }
    }
}
