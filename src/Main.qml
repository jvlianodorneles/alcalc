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
    minimumWidth: 360
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
        if (upper === "HELP" || upper === "?") {
            helpDialog.open();
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
        win.historyIndex = -1;
        tapeListView.positionViewAtEnd();
    }

    function loadSamplesToTape() {
        var samples = [
            { expr: "6/3+2*5", result: "20" },
            { expr: "1..9 *13", result: "13 26 39 52 65 78 91 104 117" },
            { expr: "\"stressed\" [8..1]", result: "desserts" },
            { expr: "1..100 INSERT +", result: "5050" },
            { expr: "32 50 100 212 -32*5/9", result: "0 10 37.7778 100" }
        ];
        for (var i = 0; i < samples.length; i++) {
            backend.saveHistoryEntry(samples[i].expr, samples[i].result, false);
        }
        tapeListView.positionViewAtEnd();
    }

    // Global Shortcuts
    Shortcut { sequence: "Ctrl+L"; onActivated: inputField.text = "" }
    Shortcut { sequence: "Ctrl+K"; onActivated: backend.clearHistory() }
    Shortcut { sequence: "F1"; onActivated: helpDialog.open() }
    Shortcut { sequence: "Ctrl+H"; onActivated: helpDialog.open() }
    Shortcut { sequence: "Esc"; onActivated: {
        if (helpDialog.opened) {
            helpDialog.close();
        } else if (inputField.text.length > 0) {
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
                        spacing: 0

                        Text {
                            text: "!"
                            color: colPrompt
                            font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                            font.pixelSize: 14
                            font.bold: true
                            Layout.rightMargin: 8
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
        // INPUT FIELD WITH SEPARATED RETURN BUTTON
        // =============================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 6

            // Enclosed Input Box
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
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
                        font.pixelSize: 15
                        font.bold: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        Layout.alignment: Qt.AlignVCenter
                    }

                    TextField {
                        id: inputField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: colText
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                        font.pixelSize: 14
                        background: null
                        leftPadding: 0
                        rightPadding: 8
                        verticalAlignment: TextInput.AlignVCenter
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
                }
            }

            // Separated RETURN Button (never overlaps input border)
            Button {
                Layout.preferredWidth: 84
                Layout.fillHeight: true
                padding: 0
                contentItem: Text {
                    anchors.centerIn: parent
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

        // =============================================================
        // BOTTOM BUTTONS & STATUS BAR (Perfect H and V Centering)
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
                    Layout.preferredWidth: 84
                    padding: 0
                    contentItem: Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "PLACES"
                            color: colMuted
                            font.family: "Monospace, 'JetBrains Mono', monospace"
                            font.bold: true
                            font.pixelSize: 11
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: String(backend.places)
                            color: colPrompt
                            font.family: "Monospace, 'JetBrains Mono', monospace"
                            font.bold: true
                            font.pixelSize: 11
                            verticalAlignment: Text.AlignVCenter
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
                    Layout.preferredWidth: 90
                    padding: 0
                    contentItem: Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "RADIANS"
                            color: colMuted
                            font.family: "Monospace, 'JetBrains Mono', monospace"
                            font.bold: true
                            font.pixelSize: 11
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: String(backend.radians)
                            color: colPrompt
                            font.family: "Monospace, 'JetBrains Mono', monospace"
                            font.bold: true
                            font.pixelSize: 11
                            verticalAlignment: Text.AlignVCenter
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
                    padding: 0
                    contentItem: Row {
                        anchors.centerIn: parent
                        spacing: 4
                        width: Math.min(parent.width - 12, implicitWidth)
                        Text {
                            text: "STORED"
                            color: colMuted
                            font.family: "Monospace, 'JetBrains Mono', monospace"
                            font.bold: true
                            font.pixelSize: 11
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: win.getStoredVarsText()
                            color: colPrompt
                            font.family: "Monospace, 'JetBrains Mono', monospace"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            width: Math.min(120, implicitWidth)
                            verticalAlignment: Text.AlignVCenter
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
                    Layout.preferredWidth: 120
                    padding: 0
                    contentItem: Text {
                        anchors.centerIn: parent
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
                    ToolTip.text: "Clear calculation tape history (Ctrl+K)"
                    onClicked: backend.clearHistory()
                }
            }

            // Row 2: FORGET EVERY NAME & HELP
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Button {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 140
                    padding: 0
                    contentItem: Text {
                        anchors.centerIn: parent
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

                // HELP Button
                Button {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 70
                    padding: 0
                    contentItem: Text {
                        anchors.centerIn: parent
                        text: "HELP ?"
                        color: colPrompt
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.bold: true
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.down ? colBorder : colBtnBg
                        border.color: colPrompt
                        border.width: 1
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: "Open Apple Calculator reference manual (F1)"
                    onClicked: helpDialog.open()
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    // =============================================================
    // MODAL HELP DIALOG (Paper Tape Monospace Aesthetic)
    // =============================================================
    Popup {
        id: helpDialog
        x: 12
        y: 12
        width: win.width - 24
        height: win.height - 24
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: colTapeBg
            border.color: colBorder
            border.width: 2
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "📖 APPLE CALCULATOR LANGUAGE HELP"
                    color: colPrompt
                    font.family: "Monospace, 'JetBrains Mono', monospace"
                    font.bold: true
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }

                Button {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    padding: 0
                    contentItem: Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: colMuted
                        font.pixelSize: 12
                    }
                    background: Rectangle { color: "transparent" }
                    onClicked: helpDialog.close()
                }
            }

            // Help manual scrollable content
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: parent.width - 12
                    spacing: 12

                    // Principles
                    Text {
                        text: "KEY PRINCIPLES\n" +
                              "• Left-to-right evaluation: 6/3+2*5 = 20 (no operator precedence).\n" +
                              "• Parentheses for grouping: (6/3)+(2*5) = 12.\n" +
                              "• Negative numbers: Use '_' prefix with no space (e.g. _5 + 10 = 5).\n" +
                              "• Comments: Text inside {curly braces} is ignored."
                        color: colText
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    // Clumps & Folds
                    Text {
                        text: "CLUMPS & FOLD (INSERT)\n" +
                              "• Sequences / Vectors: 1 2 3 or range 1..10\n" +
                              "• Vector math: (1 2 3) + (10 20 30) = 11 22 33\n" +
                              "• Vector fold: 1..100 INSERT + = 5050\n" +
                              "• Factorial: 1..5 INSERT * = 120\n" +
                              "• Vector max: 10 99 42 INSERT MAX = 99"
                        color: colText
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    // Strings & Slicing
                    Text {
                        text: "STRINGS & 1-BASED INDEXING\n" +
                              "• String slice: \"stressed\" [8..1] = desserts\n" +
                              "• Array index: (10 20 30 40)[2 4] = 20 40\n" +
                              "• ASCII code: \"A\" NUMBER = 65\n" +
                              "• Char code: 65 LETTER = A"
                        color: colText
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    // Math Monads & Variables
                    Text {
                        text: "OPERATORS & VARIABLES\n" +
                              "• Stats: SUM, MEAN, MEDIAN, NORM\n" +
                              "• Primes: 1..30 PRIMES = 2 3 5 7 11 13 17 19 23 29\n" +
                              "• Math: SQRT, ABS, FACT, SIN, COS, LOG, LN, MOD, TOTHE (^)\n" +
                              "• Store var: 5 : fingers (fingers * 2 = 10)\n" +
                              "• Settings: 4 : PLACES, 1 : RADIANS, ANS"
                        color: colText
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    // Shortcuts
                    Text {
                        text: "KEYBOARD SHORTCUTS\n" +
                              "• Return / Enter: Evaluate expression\n" +
                              "• Shift + Return: Explain mode (step trace)\n" +
                              "• Up / Down: Navigate history\n" +
                              "• Ctrl + K: Clear the tape\n" +
                              "• Ctrl + L: Clear input field\n" +
                              "• F1 / Help button: Open this manual"
                        color: colMuted
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }

            // Bottom action: Load samples button
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    padding: 0
                    contentItem: Text {
                        anchors.centerIn: parent
                        text: "▶ Insert Sample Calculations to Tape"
                        color: colPrompt
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.bold: true
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.down ? colBorder : colBtnBg
                        border.color: colPrompt
                        border.width: 1
                    }
                    onClicked: {
                        win.loadSamplesToTape();
                        helpDialog.close();
                    }
                }
            }
        }
    }
}
