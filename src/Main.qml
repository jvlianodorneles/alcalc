import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import "Engine.js" as Engine

ApplicationWindow {
    id: win
    width: 440
    height: 580
    minimumWidth: 350
    minimumHeight: 420
    visible: true
    title: "Alcalc - Paper Tape"

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

    // History navigation index
    property int historyIndex: -1

    function getStoredVarsText() {
        var keys = Object.keys(backend.varsMap || {});
        // Filter out internal vars if any, keep user vars
        var userKeys = [];
        for (var i = 0; i < keys.length; i++) {
            if (keys[i] !== "ANS") userKeys.push(keys[i]);
        }
        if (userKeys.length === 0) {
            return "nothing yet";
        }
        return userKeys.join(", ");
    }

    function evaluateCurrent(isExplain) {
        var rawExpr = inputField.text.trim();
        if (rawExpr.length === 0) return;

        // Check for interactive helper commands
        var upper = rawExpr.toUpperCase();
        if (upper === "CLEAR" || upper === "CLEAR TAPE") {
            backend.clearHistory();
            inputField.text = "";
            return;
        }
        if (upper === "FORGET" || upper === "FORGET ALL") {
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
        root.historyIndex = -1;
        tapeListView.positionViewAtEnd();
    }

    // Global Shortcuts
    Shortcut { sequence: "Ctrl+L"; onActivated: inputField.text = "" }
    Shortcut { sequence: "Ctrl+K"; onActivated: backend.clearHistory() }
    Shortcut { sequence: "Esc"; onActivated: {
        if (inputField.text.length > 0) {
            inputField.text = "";
        } else {
            win.close();
        }
    }}

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // =============================================================
        // HEADER: PAPER TAPE LABEL
        // =============================================================
        Text {
            text: "PAPER TAPE"
            color: colMuted
            font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 2
        }

        // =============================================================
        // MAIN PAPER TAPE CONTAINER
        // =============================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: colTapeBg
            border.color: colBorder
            border.width: 1

            ListView {
                id: tapeListView
                anchors.fill: parent
                anchors.margins: 12
                clip: true
                spacing: 12
                model: backend.historyList

                // Initial instructions at top of tape
                header: ColumnLayout {
                    width: tapeListView.width
                    spacing: 6

                    Text {
                        text: "Type an expression and press Return. Notes to yourself go in {braces}."
                        color: colMuted
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                        font.pixelSize: 13
                        font.italic: true
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    Item { Layout.preferredHeight: 8 }
                }

                delegate: ColumnLayout {
                    width: tapeListView.width
                    spacing: 3

                    // Prompt & Expression line
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "!"
                            color: colPrompt
                            font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            text: modelData.expr || ""
                            color: colText
                            font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    inputField.text = modelData.expr;
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
                            font.pixelSize: 14
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

                Component.onCompleted: tapeListView.positionViewAtEnd()
            }
        }

        // =============================================================
        // INPUT FIELD WITH RETURN BUTTON
        // =============================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: colTapeBg
            border.color: inputField.activeFocus ? colText : colBorder
            border.width: inputField.activeFocus ? 2 : 1

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Text {
                    text: "!"
                    color: colPrompt
                    font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                    font.pixelSize: 16
                    font.bold: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 6
                }

                TextField {
                    id: inputField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: colText
                    font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                    font.pixelSize: 14
                    background: null
                    focus: true
                    selectByMouse: true

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (event.modifiers & Qt.ShiftModifier) {
                                win.evaluateCurrent(true);
                            } else {
                                win.evaluateCurrent(false);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            var hist = backend.historyList;
                            if (hist && hist.length > 0) {
                                win.historyIndex = Math.min(hist.length - 1, win.historyIndex + 1);
                                inputField.text = hist[win.historyIndex].expr;
                                inputField.cursorPosition = inputField.text.length;
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            var hist2 = backend.historyList;
                            if (hist2 && win.historyIndex > 0) {
                                win.historyIndex--;
                                inputField.text = hist2[win.historyIndex].expr;
                                inputField.cursorPosition = inputField.text.length;
                            } else if (win.historyIndex === 0) {
                                win.historyIndex = -1;
                                inputField.text = "";
                            }
                            event.accepted = true;
                        }
                    }
                }

                Button {
                    Layout.preferredWidth: 84
                    Layout.fillHeight: true
                    contentItem: Text {
                        text: "RETURN"
                        color: colReturnFg
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                        font.bold: true
                        font.pixelSize: 11
                        font.letterSpacing: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.down ? Qt.darker(colReturnBg, 1.2) : colReturnBg
                    }
                    onClicked: win.evaluateCurrent(false)
                }
            }
        }

        // =============================================================
        // BOTTOM BUTTONS & STATUS BAR
        // =============================================================
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            // Row 1: PLACES, RADIANS, STORED, CLEAR THE TAPE
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // PLACES button
                Button {
                    Layout.preferredHeight: 30
                    contentItem: RowLayout {
                        spacing: 4
                        Text {
                            text: "PLACES"
                            color: colMuted
                            font.family: "Monospace, 'JetBrains Mono', monospace"
                            font.bold: true
                            font.pixelSize: 11
                        }
                        Text {
                            text: String(backend.places)
                            color: colPrompt
                            font.family: "Monospace, 'JetBrains Mono', monospace"
                            font.bold: true
                            font.pixelSize: 11
                        }
                    }
                    background: Rectangle {
                        color: parent.down ? colBorder : colBtnBg
                        border.color: colBtnBorder
                        border.width: 1
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: "Click to cycle decimal places (2, 4, 6, 8, 0)"
                    onClicked: {
                        var nextP = (backend.places === 2) ? 4 : (backend.places === 4) ? 6 : (backend.places === 6) ? 8 : (backend.places === 8) ? 0 : 2;
                        backend.setPlaces(nextP);
                    }
                }

                // RADIANS button
                Button {
                    Layout.preferredHeight: 30
                    contentItem: RowLayout {
                        spacing: 4
                        Text {
                            text: "RADIANS"
                            color: colMuted
                            font.family: "Monospace, 'JetBrains Mono', monospace"
                            font.bold: true
                            font.pixelSize: 11
                        }
                        Text {
                            text: String(backend.radians)
                            color: colPrompt
                            font.family: "Monospace, 'JetBrains Mono', monospace"
                            font.bold: true
                            font.pixelSize: 11
                        }
                    }
                    background: Rectangle {
                        color: parent.down ? colBorder : colBtnBg
                        border.color: colBtnBorder
                        border.width: 1
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: "Click to toggle angle mode (1 = Radians, 0 = Degrees)"
                    onClicked: backend.setRadians(backend.radians ? 0 : 1)
                }

                // STORED button
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    contentItem: RowLayout {
                        spacing: 4
                        Text {
                            text: "STORED"
                            color: colMuted
                            font.family: "Monospace, 'JetBrains Mono', monospace"
                            font.bold: true
                            font.pixelSize: 11
                        }
                        Text {
                            text: win.getStoredVarsText()
                            color: colPrompt
                            font.family: "Monospace, 'JetBrains Mono', monospace"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    background: Rectangle {
                        color: parent.down ? colBorder : colBtnBg
                        border.color: colBtnBorder
                        border.width: 1
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: "Active variables in memory: " + win.getStoredVarsText()
                }

                // CLEAR THE TAPE button
                Button {
                    Layout.preferredHeight: 30
                    contentItem: Text {
                        text: "CLEAR THE TAPE"
                        color: colMuted
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.bold: true
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.down ? colBorder : colBtnBg
                        border.color: colBtnBorder
                        border.width: 1
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: "Clear calculation tape history"
                    onClicked: backend.clearHistory()
                }
            }

            // Row 2: FORGET EVERY NAME
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Button {
                    Layout.preferredHeight: 28
                    contentItem: Text {
                        text: "FORGET EVERY NAME"
                        color: colMuted
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.bold: true
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.down ? colBorder : colBtnBg
                        border.color: colBtnBorder
                        border.width: 1
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: "Erase all custom stored variables from memory"
                    onClicked: backend.clearVars()
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}
