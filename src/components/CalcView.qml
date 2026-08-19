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
            spacing: 8

            // -------------------------------------------------------------
            // SECTION 1: EXPRESSION INPUT BOX
            // -------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                color: backend.themeSurface
                radius: 6
                border.color: inputField.activeFocus ? backend.themeAccent : backend.themeBorder
                border.width: inputField.activeFocus ? 2 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 6

                    Text {
                        text: "❯"
                        color: backend.themeAccent
                        font.pixelSize: 16
                        font.bold: true
                        Layout.leftMargin: 4
                    }

                    TextField {
                        id: inputField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: "1..10 INSERT + or 6/3+2*5"
                        placeholderTextColor: backend.themeMuted
                        color: backend.themeForeground
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.pixelSize: 14
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
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        flat: true
                        contentItem: Text {
                            text: "✕"
                            color: backend.themeMuted
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
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
                        Layout.preferredWidth: 74
                        Layout.preferredHeight: 34
                        contentItem: Text {
                            text: "Eval ⏎"
                            color: "#ffffff"
                            font.bold: true
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.down ? Qt.darker(backend.themeAccent, 1.2) : backend.themeAccent
                            radius: 5
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
                Layout.preferredHeight: root.isError ? errorLayout.implicitHeight + 16 : 56
                visible: root.currentResult.length > 0 || root.isError
                color: root.isError ? (backend.darkMode ? "#3a1d25" : "#fde8e8") : backend.themeSurfaceVariant
                radius: 6
                border.color: root.isError ? backend.themeError : backend.themeBorder
                border.width: 1

                // Result display
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    visible: !root.isError
                    spacing: 8

                    Text {
                        text: "= " + root.currentResult
                        color: backend.themeForeground
                        font.family: "Monospace, 'JetBrains Mono', monospace"
                        font.pixelSize: 18
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Copy button
                    Button {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: root.lastCopiedText.length > 0 ? 82 : 72
                        contentItem: Text {
                            text: root.lastCopiedText.length > 0 ? "✓ Copied" : "󰆏 Copy"
                            color: root.lastCopiedText.length > 0 ? backend.themeSuccess : backend.themeForeground
                            font.bold: true
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: backend.themeSurface
                            border.color: backend.themeBorder
                            radius: 5
                        }
                        onClicked: root.copyResult()
                    }

                    // Explain toggle button
                    Button {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: 76
                        contentItem: Text {
                            text: root.explainVisible ? "🔍 Hide" : "🔍 Explain"
                            color: backend.themeAccent
                            font.bold: true
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: backend.themeSurface
                            border.color: backend.themeBorder
                            radius: 5
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
                    anchors.margins: 10
                    visible: root.isError
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "⚠️ " + root.errorText
                            color: backend.themeError
                            font.bold: true
                            font.pixelSize: 13
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }

                    // Smart tip row
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.smartTipObj !== null
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: tipText.implicitHeight + 12
                            color: backend.darkMode ? "#2b2230" : "#fff8e6"
                            radius: 5
                            border.color: "#d97706"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 6

                                Text {
                                    id: tipText
                                    text: "💡 " + (root.smartTipObj ? root.smartTipObj.tip : "")
                                    color: backend.darkMode ? "#fcd34d" : "#b45309"
                                    font.pixelSize: 12
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }

                                Button {
                                    visible: root.smartTipObj && root.smartTipObj.suggestedFix !== null
                                    Layout.preferredHeight: 28
                                    Layout.preferredWidth: 76
                                    contentItem: Text {
                                        text: "Auto-Fix"
                                        color: "#ffffff"
                                        font.bold: true
                                        font.pixelSize: 11
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
                Layout.preferredHeight: explainColumn.implicitHeight + 16
                visible: root.explainVisible && root.explainSteps.length > 0
                color: backend.themeSurface
                radius: 6
                border.color: backend.themeAccent
                border.width: 1

                ColumnLayout {
                    id: explainColumn
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    Text {
                        text: "🔍 Step-by-Step Reduction Trace:"
                        color: backend.themeAccent
                        font.bold: true
                        font.pixelSize: 12
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
                                spacing: 6

                                Text {
                                    text: (index + 1) + "."
                                    color: backend.themeMuted
                                    font.pixelSize: 11
                                    font.bold: true
                                    Layout.preferredWidth: 18
                                }
                                Text {
                                    text: modelData.expr
                                    color: backend.themeForeground
                                    font.family: "Monospace"
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: "➔"
                                    color: backend.themeMuted
                                    font.pixelSize: 11
                                }
                                Text {
                                    text: modelData.result
                                    color: backend.themeAccent
                                    font.family: "Monospace"
                                    font.bold: true
                                    font.pixelSize: 12
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
                Layout.preferredHeight: keypadColumn.implicitHeight + 14
                color: backend.themeSurface
                radius: 6
                border.color: backend.themeBorder
                border.width: 1

                ColumnLayout {
                    id: keypadColumn
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    TabBar {
                        id: keypadTabBar
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        background: Rectangle { color: "transparent" }

                        TabButton { text: "Arithmetic"; font.pixelSize: 10; padding: 2 }
                        TabButton { text: "Clumps"; font.pixelSize: 10; padding: 2 }
                        TabButton { text: "Monads"; font.pixelSize: 10; padding: 2 }
                        TabButton { text: "Strings"; font.pixelSize: 10; padding: 2 }
                        TabButton { text: "Vars/Const"; font.pixelSize: 10; padding: 2 }
                    }

                    StackLayout {
                        id: keypadStack
                        Layout.fillWidth: true
                        currentIndex: keypadTabBar.currentIndex

                        // Page 0: Arithmetic (4 columns)
                        GridLayout {
                            columns: 4
                            rowSpacing: 5
                            columnSpacing: 5

                            Repeater {
                                model: [
                                    { label: "+", token: " + ", tip: "Addition" },
                                    { label: "-", token: " - ", tip: "Subtraction" },
                                    { label: "*", token: " * ", tip: "Multiplication" },
                                    { label: "/", token: " / ", tip: "Division" },
                                    { label: "TOTHE", token: " TOTHE ", tip: "Raise to power (e.g. 2 TOTHE 8 = 256)" },
                                    { label: "MOD", token: " MOD ", tip: "Modulo remainder" },
                                    { label: "_ neg", token: "_", tip: "Negative number prefix (e.g. _5)" },
                                    { label: "SQRT", token: " SQRT", tip: "Square root" },
                                    { label: "(", token: "(", tip: "Open parenthesis" },
                                    { label: ")", token: ")", tip: "Close parenthesis" },
                                    { label: "MIN", token: " MIN ", tip: "Minimum of values" },
                                    { label: "MAX", token: " MAX ", tip: "Maximum of values" },
                                ]
                                delegate: Button {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    ToolTip.visible: hovered
                                    ToolTip.text: modelData.tip
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
                                        radius: 4
                                    }
                                    onClicked: root.insertToken(modelData.token)
                                }
                            }
                        }

                        // Page 1: Clumps & Range (4 columns)
                        GridLayout {
                            columns: 4
                            rowSpacing: 5
                            columnSpacing: 5

                            Repeater {
                                model: [
                                    { label: ".. Range", token: "..", tip: "Generate sequence range (e.g. 1..10)" },
                                    { label: "INSERT +", token: " INSERT +", tip: "Sum fold reduction across vector" },
                                    { label: "INSERT *", token: " INSERT *", tip: "Product fold reduction across vector" },
                                    { label: "INSERT MAX", token: " INSERT MAX", tip: "Maximum fold reduction" },
                                    { label: "[ ] Index", token: "[]", tip: "1-based vector and string indexing" },
                                    { label: "SORT", token: " SORT", tip: "Sort vector elements ascending" },
                                    { label: "REVERSE", token: " REVERSE", tip: "Reverse vector or string" },
                                    { label: "DOT", token: " DOT ", tip: "Vector dot product" },
                                    { label: "1..10", token: "1..10", tip: "Insert 1..10 sequence" },
                                    { label: "0..100", token: "0..100", tip: "Insert 0..100 sequence" },
                                    { label: "INSERT MIN", token: " INSERT MIN", tip: "Minimum fold reduction" },
                                    { label: "INSERT AND", token: " INSERT AND", tip: "Boolean AND fold reduction" },
                                ]
                                delegate: Button {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    ToolTip.visible: hovered
                                    ToolTip.text: modelData.tip
                                    contentItem: Text {
                                        text: modelData.label
                                        color: backend.themeForeground
                                        font.bold: true
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: parent.down ? backend.themeAccent : (parent.hovered ? backend.themeSurfaceVariant : backend.themeBackground)
                                        border.color: backend.themeBorder
                                        radius: 4
                                    }
                                    onClicked: root.insertToken(modelData.token)
                                }
                            }
                        }

                        // Page 2: Monads / Stats (4 columns)
                        GridLayout {
                            columns: 4
                            rowSpacing: 5
                            columnSpacing: 5

                            Repeater {
                                model: [
                                    { label: "SUM", token: " SUM", tip: "Sum all elements in vector" },
                                    { label: "MEAN", token: " MEAN", tip: "Arithmetic mean / average" },
                                    { label: "MEDIAN", token: " MEDIAN", tip: "Median value of vector" },
                                    { label: "NORM", token: " NORM", tip: "Euclidean norm / vector magnitude" },
                                    { label: "PRIMES", token: " PRIMES", tip: "Filter prime numbers from vector" },
                                    { label: "PRIME", token: " PRIME", tip: "Primality test (1 if prime, 0 otherwise)" },
                                    { label: "GCD", token: " GCD", tip: "Greatest common divisor" },
                                    { label: "LCM", token: " LCM", tip: "Least common multiple" },
                                    { label: "FACT", token: " FACT", tip: "Factorial function" },
                                    { label: "SIN", token: " SIN", tip: "Sine function" },
                                    { label: "COS", token: " COS", tip: "Cosine function" },
                                    { label: "LOG", token: " LOG", tip: "Base-10 logarithm" },
                                ]
                                delegate: Button {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    ToolTip.visible: hovered
                                    ToolTip.text: modelData.tip
                                    contentItem: Text {
                                        text: modelData.label
                                        color: backend.themeForeground
                                        font.bold: true
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: parent.down ? backend.themeAccent : (parent.hovered ? backend.themeSurfaceVariant : backend.themeBackground)
                                        border.color: backend.themeBorder
                                        radius: 4
                                    }
                                    onClicked: root.insertToken(modelData.token)
                                }
                            }
                        }

                        // Page 3: Strings & Base (4 columns)
                        GridLayout {
                            columns: 4
                            rowSpacing: 5
                            columnSpacing: 5

                            Repeater {
                                model: [
                                    { label: "LENGTH", token: " LENGTH", tip: "Length of string or vector" },
                                    { label: "VALUE", token: " VALUE", tip: "Parse number from string" },
                                    { label: "NUMBER", token: " NUMBER", tip: "Convert character to code point" },
                                    { label: "LETTER", token: " LETTER", tip: "Convert code point to character" },
                                    { label: "HEX", token: " HEX", tip: "Convert decimal to hexadecimal" },
                                    { label: "FROMHEX", token: " FROMHEX", tip: "Parse hexadecimal to decimal" },
                                    { label: "BIN", token: " BIN", tip: "Convert decimal to binary" },
                                    { label: "FROMBIN", token: " FROMBIN", tip: "Parse binary to decimal" },
                                    { label: "OCT", token: " OCT", tip: "Convert decimal to octal" },
                                    { label: "FROMOCT", token: " FROMOCT", tip: "Parse octal to decimal" },
                                    { label: "STRING", token: " STRING", tip: "Convert number to string" },
                                    { label: "PICK", token: " PICK", tip: "Randomly pick one element" },
                                ]
                                delegate: Button {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    ToolTip.visible: hovered
                                    ToolTip.text: modelData.tip
                                    contentItem: Text {
                                        text: modelData.label
                                        color: backend.themeForeground
                                        font.bold: true
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: parent.down ? backend.themeAccent : (parent.hovered ? backend.themeSurfaceVariant : backend.themeBackground)
                                        border.color: backend.themeBorder
                                        radius: 4
                                    }
                                    onClicked: root.insertToken(modelData.token)
                                }
                            }
                        }

                        // Page 4: Constants & Vars (4 columns)
                        GridLayout {
                            columns: 4
                            rowSpacing: 5
                            columnSpacing: 5

                            Repeater {
                                model: [
                                    { label: "ANS", token: "ANS", tip: "Previous evaluated answer" },
                                    { label: "PI", token: "PI", tip: "Pi constant (3.14159...)" },
                                    { label: "E", token: "E", tip: "Euler's constant e (2.71828...)" },
                                    { label: ": Assign", token: " : ", tip: "Assign value to variable (e.g. 5 : fingers)" },
                                    { label: "PLACES", token: "PLACES", tip: "Decimal precision (e.g. 4 : PLACES)" },
                                    { label: "RADIANS", token: "RADIANS", tip: "Angle mode (1 = Rad, 0 = Deg)" },
                                    { label: "{ Comment }", token: "{  }", tip: "Enclose comment in braces" },
                                    { label: "ABS", token: " ABS", tip: "Absolute value" },
                                    { label: "ODD", token: " ODD", tip: "Odd test (1 if odd, 0 if even)" },
                                    { label: "EVEN", token: " EVEN", tip: "Even test (1 if even, 0 if odd)" },
                                    { label: "FLOOR", token: " FLOOR", tip: "Round down to integer" },
                                    { label: "CEILING", token: " CEILING", tip: "Round up to integer" },
                                ]
                                delegate: Button {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    ToolTip.visible: hovered
                                    ToolTip.text: modelData.tip
                                    contentItem: Text {
                                        text: modelData.label
                                        color: backend.themeForeground
                                        font.bold: true
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: parent.down ? backend.themeAccent : (parent.hovered ? backend.themeSurfaceVariant : backend.themeBackground)
                                        border.color: backend.themeBorder
                                        radius: 4
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
