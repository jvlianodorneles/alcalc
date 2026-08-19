import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import "Engine.js" as Engine

ApplicationWindow {
    id: win
    width: 440
    height: 600
    minimumWidth: 360
    minimumHeight: 460
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
    property int sampleIndex: 0
    readonly property var sampleList: [
        "6/3+2*5",
        "1..100 INSERT +",
        "\"STRESSED\" [8..1]",
        "5 : FINGERS",
        "1..30 PRIMES",
        "32 50 100 212 -32*5/9",
        "1..5 INSERT *",
        "(10 20 30) MEAN"
    ]

    function insertSampleToInput(sampleText) {
        if (!sampleText) {
            sampleText = sampleList[sampleIndex % sampleList.length];
            sampleIndex++;
        }
        inputField.text = sampleText.toUpperCase();
        inputField.cursorPosition = inputField.text.length;
        helpDialog.close();
        inputField.forceActiveFocus();
    }

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
        var rawExpr = inputField.text.toUpperCase().trim();
        if (rawExpr.length === 0) return;

        // Check for interactive helper commands
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
        if (rawExpr === "HELP" || rawExpr === "?") {
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
        tapeListView.positionViewAtBeginning();
    }

    // Global Shortcuts
    Shortcut { sequence: "Ctrl+L"; onActivated: inputField.text = "" }
    Shortcut { sequence: "Ctrl+K"; onActivated: backend.clearHistory() }
    Shortcut { sequence: "F1"; onActivated: helpDialog.open() }
    Shortcut { sequence: "Ctrl+H"; onActivated: helpDialog.open() }
    Shortcut { sequence: "Esc"; onActivated: {
        if (helpDialog.opened) {
            helpDialog.close();
        } else if (storedDialog.opened) {
            storedDialog.close();
        } else if (aboutDialog.opened) {
            aboutDialog.close();
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
        // HEADER: TITLE & ABOUT ICON BUTTON (Right Side)
        // =============================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            Layout.fillHeight: false
            spacing: 8

            Text {
                text: "PAPER TAPE"
                color: colMuted
                font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 2
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            // About Icon Button (Right side of title bar)
            Rectangle {
                id: aboutIconBtn
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                color: aboutIconArea.pressed ? colBorder : (aboutIconArea.containsMouse ? Qt.lighter(colBtnBg, 1.1) : "transparent")
                border.color: aboutIconArea.containsMouse ? colBtnBorder : "transparent"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "ℹ"
                    color: aboutIconArea.containsMouse ? colPrompt : colMuted
                    font.pixelSize: 13
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    id: aboutIconArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: aboutDialog.open()
                }

                ToolTip.visible: aboutIconArea.containsMouse
                ToolTip.text: "About Alcalc"
            }
        }

        // =============================================================
        // MAIN PAPER TAPE CONTAINER (Feeds Bottom-to-Top)
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
                spacing: 10
                verticalLayoutDirection: ListView.BottomToTop
                model: backend.historyList

                // Guide text at top (above oldest items in BottomToTop mode)
                footer: ColumnLayout {
                    width: tapeListView.width
                    spacing: 6

                    Item { Layout.preferredHeight: 6 }

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
            }
        }

        // =============================================================
        // INPUT BAR WITH RETURN RECTANGLE (100% IDENTICAL BOX HEIGHT: 38PX)
        // =============================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            Layout.minimumHeight: 38
            Layout.maximumHeight: 38
            Layout.fillHeight: false
            spacing: 8

            // Enclosed Input Box (Height: 38px, Border: 1px)
            Rectangle {
                id: inputRectBox
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                Layout.minimumHeight: 38
                Layout.maximumHeight: 38
                Layout.fillHeight: false
                color: colTapeBg
                border.color: inputField.activeFocus ? colText : colBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Prompt "!" with equal margins
                    Text {
                        text: "!"
                        color: colPrompt
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                        font.pixelSize: 14
                        font.bold: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 8
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Single-line uppercase input field
                    TextField {
                        id: inputField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: colText
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                        font.pixelSize: 14
                        font.capitalization: Font.AllUppercase
                        background: null
                        padding: 0
                        leftPadding: 0
                        rightPadding: 8
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        selectByMouse: true

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
                                    win.evaluateCurrent(true);
                                } else {
                                    win.evaluateCurrent(false);
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                var hist = backend.historyList;
                                if (hist && hist.length > 0) {
                                    win.historyIndex = Math.min(hist.length - 1, win.historyIndex + 1);
                                    inputField.text = hist[win.historyIndex].expr.toUpperCase();
                                    inputField.cursorPosition = inputField.text.length;
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                var hist2 = backend.historyList;
                                if (hist2 && win.historyIndex > 0) {
                                    win.historyIndex--;
                                    inputField.text = hist2[win.historyIndex].expr.toUpperCase();
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

            // Standalone RETURN Box (Exact same Rectangle box, Height: 38px, Border: 1px)
            Rectangle {
                id: returnRectBox
                Layout.preferredWidth: 84
                Layout.preferredHeight: 38
                Layout.minimumHeight: 38
                Layout.maximumHeight: 38
                Layout.fillHeight: false
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
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    id: returnMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.evaluateCurrent(false)
                }
            }
        }

        // =============================================================
        // BOTTOM BUTTONS & STATUS BAR (Spacious 2-Row Distribution)
        // =============================================================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: 6

            // Row 1: PLACES, RADIANS, CLEAR TAPE, HELP ? (Height: 52px)
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                Layout.minimumHeight: 52
                Layout.maximumHeight: 52
                Layout.fillHeight: false
                spacing: 6

                // PLACES Button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    Layout.fillHeight: false
                    color: placesArea.pressed ? colBorder : (placesArea.containsMouse ? Qt.lighter(colBtnBg, 1.05) : colBtnBg)
                    border.color: colBtnBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "<font color='" + colMuted + "'>PLACES</font> <font color='" + colPrompt + "'>" + backend.places + "</font>"
                        textFormat: Text.RichText
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                        font.bold: true
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: placesArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var nextP = (backend.places === 2) ? 4 : (backend.places === 4) ? 6 : (backend.places === 6) ? 8 : (backend.places === 8) ? 0 : 2;
                            backend.setPlaces(nextP);
                        }
                    }

                    ToolTip.visible: placesArea.containsMouse
                    ToolTip.text: "Click to cycle decimal places (2, 4, 6, 8, 0)"
                }

                // RADIANS Button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    Layout.fillHeight: false
                    color: radiansArea.pressed ? colBorder : (radiansArea.containsMouse ? Qt.lighter(colBtnBg, 1.05) : colBtnBg)
                    border.color: colBtnBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "<font color='" + colMuted + "'>RADIANS</font> <font color='" + colPrompt + "'>" + backend.radians + "</font>"
                        textFormat: Text.RichText
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                        font.bold: true
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: radiansArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.setRadians(backend.radians ? 0 : 1)
                    }

                    ToolTip.visible: radiansArea.containsMouse
                    ToolTip.text: "Click to toggle angle mode (1 = Radians, 0 = Degrees)"
                }

                // CLEAR TAPE Button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    Layout.fillHeight: false
                    color: clearTapeArea.pressed ? colBorder : (clearTapeArea.containsMouse ? Qt.lighter(colBtnBg, 1.05) : colBtnBg)
                    border.color: colBtnBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "CLEAR TAPE"
                        color: colMuted
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                        font.bold: true
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: clearTapeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.clearHistory()
                    }

                    ToolTip.visible: clearTapeArea.containsMouse
                    ToolTip.text: "Clear calculation tape history (Ctrl+K)"
                }

                // HELP ? Button
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 52
                    Layout.fillHeight: false
                    color: helpBtnArea.pressed ? colBorder : (helpBtnArea.containsMouse ? Qt.lighter(colBtnBg, 1.05) : colBtnBg)
                    border.color: colPrompt
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "HELP ?"
                        color: colPrompt
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                        font.bold: true
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: helpBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: helpDialog.open()
                    }

                    ToolTip.visible: helpBtnArea.containsMouse
                    ToolTip.text: "Open Apple Calculator reference manual (F1)"
                }
            }

            // Row 2: STORED (Wide 250px+) & FORGET EVERY NAME (Height: 48px)
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.minimumHeight: 48
                Layout.maximumHeight: 48
                Layout.fillHeight: false
                spacing: 6

                // STORED Button (Wide 250px+ area with click-to-inspect)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    Layout.fillHeight: false
                    color: storedArea.pressed ? colBorder : (storedArea.containsMouse ? Qt.lighter(colBtnBg, 1.05) : colBtnBg)
                    border.color: colBtnBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 20, implicitWidth)
                        text: "<font color='" + colMuted + "'>STORED</font> <font color='" + colPrompt + "'>" + win.getStoredVarsText() + "</font>"
                        textFormat: Text.RichText
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                        font.bold: true
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: storedArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: storedDialog.open()
                    }

                    ToolTip.visible: storedArea.containsMouse
                    ToolTip.text: "Active variables: " + win.getStoredVarsText() + " (Click to inspect/manage)"
                }

                // FORGET EVERY NAME Button
                Rectangle {
                    Layout.preferredHeight: 48
                    Layout.preferredWidth: 156
                    Layout.fillHeight: false
                    color: forgetArea.pressed ? colBorder : (forgetArea.containsMouse ? Qt.lighter(colBtnBg, 1.05) : colBtnBg)
                    border.color: colBtnBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "FORGET EVERY NAME"
                        color: colMuted
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.bold: true
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: forgetArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.clearVars()
                    }

                    ToolTip.visible: forgetArea.containsMouse
                    ToolTip.text: "Erase all custom stored variables from memory"
                }
            }
        }
    }

    // =============================================================
    // MODAL STORED VARIABLES INSPECTOR DIALOG
    // =============================================================
    Popup {
        id: storedDialog
        x: 14
        y: 20
        width: win.width - 28
        height: Math.min(win.height - 40, 360)
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
                    text: "STORED VARIABLES IN MEMORY"
                    color: colPrompt
                    font.family: "Monospace, 'JetBrains Mono', monospace"
                    font.bold: true
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: colMuted
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: storedDialog.close()
                    }
                }
            }

            // Variables list
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: parent.width - 12
                    spacing: 6

                    Text {
                        visible: Object.keys(backend.varsMap).length === 0
                        text: "No custom variables stored yet.\nAssign variables with ':' (e.g. 5: FINGERS or 1..5: VEC)."
                        color: colMuted
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.pixelSize: 12
                        font.italic: true
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: Object.keys(backend.varsMap)
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            color: index % 2 === 0 ? colBtnBg : "transparent"
                            border.color: colBorder
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 8

                                Text {
                                    text: modelData
                                    color: colPrompt
                                    font.family: "Monospace, 'JetBrains Mono', monospace"
                                    font.bold: true
                                    font.pixelSize: 13
                                    Layout.preferredWidth: 90
                                }

                                Text {
                                    text: "= " + Engine.render(backend.varsMap[modelData], backend.places)
                                    color: colText
                                    font.family: "Monospace, 'JetBrains Mono', monospace"
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    color: "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        color: colError
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.removeVar(modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Bottom action: Clear All Vars
            RowLayout {
                Layout.fillWidth: true

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    color: colBtnBg
                    border.color: colError
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Clear All Variables"
                        color: colError
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.bold: true
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            backend.clearVars();
                            storedDialog.close();
                        }
                    }
                }
            }
        }
    }

    // =============================================================
    // MODAL TABBED HELP DIALOG (Clean, Compact, No Scrolling Needed)
    // =============================================================
    Popup {
        id: helpDialog
        x: 12
        y: 12
        width: win.width - 24
        height: Math.min(win.height - 24, 460)
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property int currentTab: 0

        background: Rectangle {
            color: colTapeBg
            border.color: colBorder
            border.width: 2
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Header
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "APPLE CALCULATOR MANUAL"
                    color: colPrompt
                    font.family: "Monospace, 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace"
                    font.bold: true
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: colMuted
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: helpDialog.close()
                    }
                }
            }

            // Tab Navigation Bar
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 4

                Repeater {
                    model: ["SYNTAX", "VECTORS", "STRINGS/MATH", "SAMPLES"]
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        color: helpDialog.currentTab === index ? colPrompt : colBtnBg
                        border.color: helpDialog.currentTab === index ? colPrompt : colBtnBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: helpDialog.currentTab === index ? "#ffffff" : colMuted
                            font.family: "Monospace, 'JetBrains Mono', monospace"
                            font.bold: true
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: helpDialog.currentTab = index
                        }
                    }
                }
            }

            // Tab Contents (Fit 100% vertically without scrolling)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: colBtnBg
                border.color: colBorder
                border.width: 1

                // Tab 0: Syntax & Key Principles
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    visible: helpDialog.currentTab === 0

                    Text {
                        text: "• LEFT-TO-RIGHT EVALUATION (No operator precedence):\n" +
                              "  6 / 3 + 2 * 5  ➔  20\n\n" +
                              "• PARENTHESES FOR GROUPING:\n" +
                              "  (6 / 3) + (2 * 5)  ➔  12\n\n" +
                              "• NEGATIVE NUMBERS (_ prefix, no space):\n" +
                              "  _5 + 10  ➔  5\n\n" +
                              "• INLINE NOTES & COMMENTS:\n" +
                              "  100 * 1.2 {tax included}\n\n" +
                              "• VARIABLE ASSIGNMENT:\n" +
                              "  5 : FINGERS   |   1..5 : VEC"
                        color: colText
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', monospace"
                        font.pixelSize: 11
                        lineHeight: 1.15
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                    Item { Layout.fillHeight: true }
                }

                // Tab 1: Vectors, Ranges & Fold (INSERT)
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    visible: helpDialog.currentTab === 1

                    Text {
                        text: "• CLUMPS / VECTORS & RANGES:\n" +
                              "  1 2 3 4   or   1..10\n\n" +
                              "• VECTOR ARITHMETIC:\n" +
                              "  (1 2 3) * 10  ➔  10 20 30\n" +
                              "  (1 2 3) + (10 20 30)  ➔  11 22 33\n\n" +
                              "• FOLD REDUCTION (INSERT):\n" +
                              "  1..100 INSERT +  ➔  5050\n" +
                              "  1..5 INSERT *  ➔  120 (Factorial)\n" +
                              "  10 99 42 INSERT MAX  ➔  99"
                        color: colText
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', monospace"
                        font.pixelSize: 11
                        lineHeight: 1.15
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                    Item { Layout.fillHeight: true }
                }

                // Tab 2: Strings, Slicing & Math Operators
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    visible: helpDialog.currentTab === 2

                    Text {
                        text: "• STRING SLICING & 1-BASED INDEX:\n" +
                              "  \"STRESSED\" [8..1]  ➔  DESSERTS\n" +
                              "  (10 20 30 40)[2 4]  ➔  20 40\n\n" +
                              "• ASCII & CHAR CONVERSION:\n" +
                              "  \"A\" NUMBER  ➔  65   |   65 LETTER  ➔  A\n\n" +
                              "• MATH MONADS:\n" +
                              "  SQRT, ABS, FACT, SIN, COS, LOG, LN, TOTHE (^)\n\n" +
                              "• STATISTICS & PRIMES:\n" +
                              "  SUM, MEAN, MEDIAN, NORM, 1..30 PRIMES"
                        color: colText
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', monospace"
                        font.pixelSize: 11
                        lineHeight: 1.15
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                    Item { Layout.fillHeight: true }
                }

                // Tab 3: Interactive Clickable Samples & Shortcuts
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8
                    visible: helpDialog.currentTab === 3

                    Text {
                        text: "CLICK ANY SAMPLE TO INSERT DIRECTLY INTO INPUT:"
                        color: colPrompt
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.bold: true
                        font.pixelSize: 10
                    }

                    GridLayout {
                        columns: 2
                        columnSpacing: 6
                        rowSpacing: 6
                        Layout.fillWidth: true

                        Repeater {
                            model: win.sampleList
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                color: sampleChipArea.pressed ? colBorder : (sampleChipArea.containsMouse ? Qt.lighter(colTapeBg, 1.1) : colTapeBg)
                                border.color: colBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: colText
                                    font.family: "Monospace, 'JetBrains Mono', monospace"
                                    font.bold: true
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    width: parent.width - 8
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                MouseArea {
                                    id: sampleChipArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.insertSampleToInput(modelData)
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        text: "SHORTCUTS: Return = Eval | Shift+Return = Trace | Up/Down = Hist"
                        color: colMuted
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.pixelSize: 9
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }
            }

            // Bottom Action: Insert Next Sample Directly into Input Box
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                color: insertBtnArea.pressed ? colBorder : (insertBtnArea.containsMouse ? Qt.lighter(colBtnBg, 1.08) : colBtnBg)
                border.color: colPrompt
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "▶ Insert Sample into Expression Input Box"
                    color: colPrompt
                    font.family: "Monospace, 'JetBrains Mono', monospace"
                    font.bold: true
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    id: insertBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.insertSampleToInput()
                }

                ToolTip.visible: insertBtnArea.containsMouse
                ToolTip.text: "Loads a ready-to-calculate sample expression directly into the input field and focuses it."
            }
        }
    }

    // =============================================================
    // MODAL ABOUT DIALOG (Historical Sources & References)
    // =============================================================
    Popup {
        id: aboutDialog
        x: 12
        y: 12
        width: win.width - 24
        height: Math.min(win.height - 24, 520)
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
                    text: "ABOUT ALCALC"
                    color: colPrompt
                    font.family: "Monospace, 'JetBrains Mono', 'Fira Code', monospace"
                    font.bold: true
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: colMuted
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: aboutDialog.close()
                    }
                }
            }

            // Scrollable Content
            ScrollView {
                id: aboutScrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                contentWidth: availableWidth

                ColumnLayout {
                    width: aboutScrollView.availableWidth
                    spacing: 10

                    Text {
                        text: "ALCALC v1.0.0"
                        color: colText
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', monospace"
                        font.bold: true
                        font.pixelSize: 13
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }

                    Text {
                        text: "Historical Sources & References"
                        color: colPrompt
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', monospace"
                        font.bold: true
                        font.pixelSize: 12
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }

                    Text {
                        text: "This app strictly implements the Apple Calculator Language, created by Jef Raskin in 1979, following Wade Tregaskis's reference implementation for tie-break rules."
                        color: colText
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.pixelSize: 11
                        lineHeight: 1.2
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: colBorder
                    }

                    Text {
                        textFormat: Text.RichText
                        text: "<p style='margin:0 0 8px 0;'><b>1.</b> Wade Tregaskis, <i>The Apple Calculator Language</i> (reference implementation and tie-break notes) — <a href='https://wadetregaskis.com/the-apple-calculator-language/' style='color:" + colPrompt + ";'>wadetregaskis.com</a></p>" +
                              "<p style='margin:0 0 8px 0;'><b>2.</b> Jef Raskin, <i>The Apple Calculator Language Primer</i>, 13 October 1979. The document this page implements, in The Macintosh Project: Selected Papers from Jef Raskin (First Macintosh Designer), Circa 1979, document 14A, version 10. — <a href='https://web.stanford.edu/dept/SUL/sites/mac/primary/docs/bom/language.html' style='color:" + colPrompt + ";'>web.stanford.edu</a></p>" +
                              "<p style='margin:0 0 8px 0;'><b>3.</b> Alex Soojung-Kim Pang, <i>Making the Macintosh: Technology and Culture in Silicon Valley</i>, Stanford University Libraries, the online archive that published the primer. Its index of primary documents holds the rest of Raskin’s papers from the same period. — <a href='https://web.stanford.edu/dept/SUL/sites/mac/index.html' style='color:" + colPrompt + ";'>web.stanford.edu</a></p>" +
                              "<p style='margin:0 0 8px 0;'><b>4.</b> Apple Computer, Inc. Records, M1007, Series 3, Box 10, Folder 1, Dept. of Special Collections, Stanford University Libraries. — <a href='https://archives.stanford.edu/catalog/m1007' style='color:" + colPrompt + ";'>archives.stanford.edu</a></p>"
                        color: colText
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.pixelSize: 10
                        lineHeight: 1.25
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                        onLinkActivated: function(link) { Qt.openUrlExternally(link); }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: colBorder
                    }

                    Text {
                        textFormat: Text.RichText
                        text: "<span style='color:" + colMuted + ";'>• Author: Juliano Dorneles | License: MIT<br>• Repository: <a href='https://github.com/jvlianodorneles/alcalc' style='color:" + colPrompt + ";'>github.com/jvlianodorneles/alcalc</a></span>"
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.pixelSize: 10
                        lineHeight: 1.2
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                        onLinkActivated: function(link) { Qt.openUrlExternally(link); }
                    }
                }
            }

            // Bottom Action: Close Button
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: aboutCloseArea.pressed ? colBorder : (aboutCloseArea.containsMouse ? Qt.lighter(colBtnBg, 1.08) : colBtnBg)
                border.color: colPrompt
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "OK"
                    color: colPrompt
                    font.family: "Monospace, 'JetBrains Mono', monospace"
                    font.bold: true
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    id: aboutCloseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: aboutDialog.close()
                }
            }
        }
    }
}
