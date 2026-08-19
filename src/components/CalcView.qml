import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Engine.js" as Engine

Item {
    id: root

    property alias expressionText: inputField.text
    signal requestExplain(string expr)
    signal requestFormulaLoad(string expr)

    property var historyList: []
    property int historyIndex: -1
    property string currentResult: ""
    property bool isError: false
    property string errorText: ""
    property var smartTipObj: null
    property var explainSteps: []
    property bool explainVisible: false
    property string lastCopiedText: ""

    function setExpression(expr, autoEval) {
        inputField.text = expr;
        inputField.cursorPosition = expr.length;
        inputField.forceActiveFocus();
        if (autoEval) {
            evaluateNow(false);
        }
    }

    function evaluateNow(isExplain) {
        var rawExpr = inputField.text.trim();
        if (rawExpr.length === 0) return;

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
            root.isError = true;
            root.errorText = res.text;
            root.smartTipObj = Engine.getSmartErrorTip(res.text, rawExpr);
            root.currentResult = "";
            root.explainSteps = [];
            backend.saveHistoryEntry(rawExpr, res.text, true);
        } else {
            root.isError = false;
            root.errorText = "";
            root.smartTipObj = null;

            if (res.kind === "answer") {
                root.currentResult = res.text;
                // Auto update ANS
                backend.saveVar("ANS", res.value);
                backend.saveHistoryEntry(rawExpr, res.text, false);
            } else {
                root.currentResult = "(Stored variable or setting)";
                backend.saveHistoryEntry(rawExpr, "(Stored)", false);
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

            if (isExplain && res.steps) {
                root.explainSteps = res.steps;
                root.explainVisible = true;
            } else if (!isExplain) {
                root.explainVisible = false;
            }
        }

        root.historyIndex = -1;
    }

    function applyFix() {
        if (root.smartTipObj && root.smartTipObj.suggestedFix) {
            inputField.text = root.smartTipObj.suggestedFix;
            inputField.cursorPosition = inputField.text.length;
            inputField.forceActiveFocus();
            root.smartTipObj = null;
        }
    }

    function insertToken(token) {
        var pos = inputField.cursorPosition;
        var txt = inputField.text;
        var newTxt = txt.substring(0, pos) + token + txt.substring(pos);
        inputField.text = newTxt;
        inputField.cursorPosition = pos + token.length;
        inputField.forceActiveFocus();
    }

    function copyResult() {
        if (root.currentResult.length > 0) {
            backend.copyToClipboard(root.currentResult);
            root.lastCopiedText = root.currentResult;
            copiedTimer.restart();
        }
    }

    Timer {
        id: copiedTimer
        interval: 1800
        onTriggered: root.lastCopiedText = ""
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 12

            // -------------------------------------------------------------
            // SECTION 1: EXPRESSION INPUT BOX
            // -------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                color: backend.themeSurface
                radius: 8
                border.color: inputField.activeFocus ? backend.themeAccent : backend.themeBorder
                border.width: inputField.activeFocus ? 2 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    Text {
                        text: "❯"
                        color: backend.themeAccent
                        font.pixelSize: 18
                        font.bold: true
                        Layout.leftMargin: 6
                    }

                    TextField {
                        id: inputField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: "Type an expression, e.g. 1..10 INSERT + or 6/3+2*5"
                        placeholderTextColor: backend.themeMuted
                        color: backend.themeForeground
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', monospace"
                        font.pixelSize: 16
                        background: null
                        focus: true

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    root.evaluateNow(true);
                                } else {
                                    root.evaluateNow(false);
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                var hist = backend.historyList;
                                if (hist && hist.length > 0) {
                                    root.historyIndex = Math.min(hist.length - 1, root.historyIndex + 1);
                                    inputField.text = hist[root.historyIndex].expr;
                                    inputField.cursorPosition = inputField.text.length;
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                var hist2 = backend.historyList;
                                if (hist2 && root.historyIndex > 0) {
                                    root.historyIndex--;
                                    inputField.text = hist2[root.historyIndex].expr;
                                    inputField.cursorPosition = inputField.text.length;
                                } else if (root.historyIndex === 0) {
                                    root.historyIndex = -1;
                                    inputField.text = "";
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                if (inputField.text.length > 0) {
                                    inputField.text = "";
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    // Clear button
                    Button {
                        visible: inputField.text.length > 0
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        flat: true
                        contentItem: Text {
                            text: "✕"
                            color: backend.themeMuted
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 14
                        }
                        background: Rectangle {
                            color: parent.hovered ? backend.themeSurfaceVariant : "transparent"
                            radius: 4
                        }
                        onClicked: {
                            inputField.text = "";
                            inputField.forceActiveFocus();
                        }
                    }

                    // Eval button
                    Button {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 38
                        contentItem: Text {
                            text: "Eval ⏎"
                            color: "#ffffff"
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.down ? Qt.darker(backend.themeAccent, 1.2) : backend.themeAccent
                            radius: 6
                        }
                        onClicked: root.evaluateNow(false)
                    }
                }
            }

            // -------------------------------------------------------------
            // SECTION 2: RESULT CARD / SMART ERROR
            // -------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.isError ? errorLayout.implicitHeight + 20 : 64
                visible: root.currentResult.length > 0 || root.isError
                color: root.isError ? (backend.darkMode ? "#3a1d25" : "#fde8e8") : backend.themeSurfaceVariant
                radius: 8
                border.color: root.isError ? backend.themeError : backend.themeBorder
                border.width: 1

                // Result display
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: !root.isError
                    spacing: 10

                    Text {
                        text: "= " + root.currentResult
                        color: backend.themeForeground
                        font.family: "Monospace, 'JetBrains Mono', 'Fira Code', monospace"
                        font.pixelSize: 20
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Copy button
                    Button {
                        Layout.preferredHeight: 34
                        Layout.preferredWidth: root.lastCopiedText.length > 0 ? 90 : 76
                        contentItem: Text {
                            text: root.lastCopiedText.length > 0 ? "✓ Copied" : "󰆏 Copy"
                            color: root.lastCopiedText.length > 0 ? backend.themeSuccess : backend.themeForeground
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: backend.themeSurface
                            border.color: backend.themeBorder
                            radius: 6
                        }
                        onClicked: root.copyResult()
                    }

                    // Explain toggle button
                    Button {
                        Layout.preferredHeight: 34
                        Layout.preferredWidth: 80
                        contentItem: Text {
                            text: root.explainVisible ? "🔍 Hide" : "🔍 Explain"
                            color: backend.themeAccent
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: backend.themeSurface
                            border.color: backend.themeBorder
                            radius: 6
                        }
                        onClicked: {
                            if (!root.explainVisible) {
                                root.evaluateNow(true);
                            } else {
                                root.explainVisible = false;
                            }
                        }
                    }
                }

                // Error display layout
                ColumnLayout {
                    id: errorLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: root.isError
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "⚠️ " + root.errorText
                            color: backend.themeError
                            font.bold: true
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }

                    // Smart tip row
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.smartTipObj !== null
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: tipText.implicitHeight + 16
                            color: backend.darkMode ? "#2b2230" : "#fff8e6"
                            radius: 6
                            border.color: "#d97706"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Text {
                                    id: tipText
                                    text: "💡 " + (root.smartTipObj ? root.smartTipObj.tip : "")
                                    color: backend.darkMode ? "#fcd34d" : "#b45309"
                                    font.pixelSize: 13
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }

                                Button {
                                    visible: root.smartTipObj && root.smartTipObj.suggestedFix !== null
                                    Layout.preferredHeight: 28
                                    Layout.preferredWidth: 80
                                    contentItem: Text {
                                        text: "Auto-Fix"
                                        color: "#ffffff"
                                        font.bold: true
                                        font.pixelSize: 12
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: "#d97706"
                                        radius: 4
                                    }
                                    onClicked: root.applyFix()
                                }
                            }
                        }
                    }
                }
            }

            // -------------------------------------------------------------
            // SECTION 3: STEP-BY-STEP EXPLAIN DRAWER
            // -------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: explainColumn.implicitHeight + 20
                visible: root.explainVisible && root.explainSteps.length > 0
                color: backend.themeSurface
                radius: 8
                border.color: backend.themeAccent
                border.width: 1

                ColumnLayout {
                    id: explainColumn
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Text {
                        text: "🔍 Step-by-Step Reduction Trace:"
                        color: backend.themeAccent
                        font.bold: true
                        font.pixelSize: 13
                    }

                    Repeater {
                        model: root.explainSteps
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            color: index % 2 === 0 ? backend.themeSurfaceVariant : "transparent"
                            radius: 4

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 8

                                Text {
                                    text: (index + 1) + "."
                                    color: backend.themeMuted
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.preferredWidth: 20
                                }
                                Text {
                                    text: modelData.expr
                                    color: backend.themeForeground
                                    font.family: "Monospace"
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: "➔"
                                    color: backend.themeMuted
                                    font.pixelSize: 12
                                }
                                Text {
                                    text: modelData.result
                                    color: backend.themeAccent
                                    font.family: "Monospace"
                                    font.bold: true
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }
            }

            // -------------------------------------------------------------
            // SECTION 4: OPERATOR TOOLBAR & KEYPAD
            // -------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: keypadColumn.implicitHeight + 16
                color: backend.themeSurface
                radius: 8
                border.color: backend.themeBorder
                border.width: 1

                ColumnLayout {
                    id: keypadColumn
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    TabBar {
                        id: keypadTabBar
                        Layout.fillWidth: true
                        background: Rectangle { color: "transparent" }

                        TabButton { text: "Arithmetic"; font.pixelSize: 12 }
                        TabButton { text: "Clumps & Range"; font.pixelSize: 12 }
                        TabButton { text: "Monads / Stats"; font.pixelSize: 12 }
                        TabButton { text: "Strings & Base"; font.pixelSize: 12 }
                        TabButton { text: "Constants & Vars"; font.pixelSize: 12 }
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 110
                        currentIndex: keypadTabBar.currentIndex

                        // Page 0: Arithmetic
                        GridLayout {
                            columns: 6
                            rowSpacing: 6
                            columnSpacing: 6

                            Repeater {
                                model: [
                                    { label: "+", token: " + " },
                                    { label: "-", token: " - " },
                                    { label: "*", token: " * " },
                                    { label: "/", token: " / " },
                                    { label: "TOTHE (^)", token: " TOTHE " },
                                    { label: "MOD", token: " MOD " },
                                    { label: "_ (neg)", token: "_" },
                                    { label: "(", token: "(" },
                                    { label: ")", token: ")" },
                                    { label: "MIN", token: " MIN " },
                                    { label: "MAX", token: " MAX " },
                                    { label: "SQRT", token: " SQRT" },
                                ]
                                delegate: Button {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    contentItem: Text {
                                        text: modelData.label
                                        color: backend.themeForeground
                                        font.bold: true
                                        font.pixelSize: 12
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: parent.down ? backend.themeAccent : (parent.hovered ? backend.themeSurfaceVariant : backend.themeBackground)
                                        border.color: backend.themeBorder
                                        radius: 5
                                    }
                                    onClicked: root.insertToken(modelData.token)
                                }
                            }
                        }

                        // Page 1: Clumps & Range
                        GridLayout {
                            columns: 4
                            rowSpacing: 6
                            columnSpacing: 6

                            Repeater {
                                model: [
                                    { label: ".. (Range)", token: ".." },
                                    { label: "INSERT + (Sum)", token: " INSERT +" },
                                    { label: "INSERT * (Prod)", token: " INSERT *" },
                                    { label: "INSERT MAX", token: " INSERT MAX" },
                                    { label: "[ ] (Index)", token: "[]" },
                                    { label: "SORT", token: " SORT" },
                                    { label: "REVERSE", token: " REVERSE" },
                                    { label: "DOT (Vector)", token: " DOT " },
                                ]
                                delegate: Button {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    contentItem: Text {
                                        text: modelData.label
                                        color: backend.themeForeground
                                        font.bold: true
                                        font.pixelSize: 12
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: parent.down ? backend.themeAccent : (parent.hovered ? backend.themeSurfaceVariant : backend.themeBackground)
                                        border.color: backend.themeBorder
                                        radius: 5
                                    }
                                    onClicked: root.insertToken(modelData.token)
                                }
                            }
                        }

                        // Page 2: Monads / Stats
                        GridLayout {
                            columns: 4
                            rowSpacing: 6
                            columnSpacing: 6

                            Repeater {
                                model: [
                                    { label: "SUM", token: " SUM" },
                                    { label: "MEAN (Avg)", token: " MEAN" },
                                    { label: "MEDIAN", token: " MEDIAN" },
                                    { label: "NORM (Mag)", token: " NORM" },
                                    { label: "PRIMES", token: " PRIMES" },
                                    { label: "PRIME", token: " PRIME" },
                                    { label: "GCD", token: " GCD" },
                                    { label: "LCM", token: " LCM" },
                                    { label: "FACT (!)", token: " FACT" },
                                    { label: "SIN", token: " SIN" },
                                    { label: "COS", token: " COS" },
                                    { label: "LOG", token: " LOG" },
                                ]
                                delegate: Button {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    contentItem: Text {
                                        text: modelData.label
                                        color: backend.themeForeground
                                        font.bold: true
                                        font.pixelSize: 12
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: parent.down ? backend.themeAccent : (parent.hovered ? backend.themeSurfaceVariant : backend.themeBackground)
                                        border.color: backend.themeBorder
                                        radius: 5
                                    }
                                    onClicked: root.insertToken(modelData.token)
                                }
                            }
                        }

                        // Page 3: Strings & Base
                        GridLayout {
                            columns: 4
                            rowSpacing: 6
                            columnSpacing: 6

                            Repeater {
                                model: [
                                    { label: "LENGTH", token: " LENGTH" },
                                    { label: "VALUE", token: " VALUE" },
                                    { label: "NUMBER", token: " NUMBER" },
                                    { label: "LETTER", token: " LETTER" },
                                    { label: "HEX", token: " HEX" },
                                    { label: "FROMHEX", token: " FROMHEX" },
                                    { label: "BIN", token: " BIN" },
                                    { label: "FROMBIN", token: " FROMBIN" },
                                ]
                                delegate: Button {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    contentItem: Text {
                                        text: modelData.label
                                        color: backend.themeForeground
                                        font.bold: true
                                        font.pixelSize: 12
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: parent.down ? backend.themeAccent : (parent.hovered ? backend.themeSurfaceVariant : backend.themeBackground)
                                        border.color: backend.themeBorder
                                        radius: 5
                                    }
                                    onClicked: root.insertToken(modelData.token)
                                }
                            }
                        }

                        // Page 4: Constants & Vars
                        GridLayout {
                            columns: 4
                            rowSpacing: 6
                            columnSpacing: 6

                            Repeater {
                                model: [
                                    { label: "ANS", token: "ANS" },
                                    { label: "PI", token: "PI" },
                                    { label: "E", token: "E" },
                                    { label: ": (Assign)", token: " : " },
                                    { label: "PLACES", token: "PLACES" },
                                    { label: "RADIANS", token: "RADIANS" },
                                    { label: "{ Comment }", token: "{  }" },
                                    { label: "PICK", token: " PICK" },
                                ]
                                delegate: Button {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    contentItem: Text {
                                        text: modelData.label
                                        color: backend.themeForeground
                                        font.bold: true
                                        font.pixelSize: 12
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: parent.down ? backend.themeAccent : (parent.hovered ? backend.themeSurfaceVariant : backend.themeBackground)
                                        border.color: backend.themeBorder
                                        radius: 5
                                    }
                                    onClicked: root.insertToken(modelData.token)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
