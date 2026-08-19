import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 14

            // Title
            Text {
                text: "📖 Apple Calculator Language (ACL) Reference Manual"
                color: backend.themeForeground
                font.bold: true
                font.pixelSize: 16
            }

            Text {
                text: "ACL is an array-oriented, left-to-right calculator language created by Apple. Operations are performed sequentially left-to-right without algebraic operator precedence unless parentheses `( )` are used."
                color: backend.themeMuted
                font.pixelSize: 13
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            // Quick rules
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: rulesCol.implicitHeight + 20
                color: backend.themeSurface
                radius: 8
                border.color: backend.themeBorder

                ColumnLayout {
                    id: rulesCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Text { text: "🔑 Core Language Principles"; color: backend.themeAccent; font.bold: true; font.pixelSize: 14 }
                    Text { text: "• Left-to-right evaluation: `6/3+2*5` evaluates as `((6/3)+2)*5 = 20`."; color: backend.themeForeground; font.pixelSize: 12 }
                    Text { text: "• Explicit grouping: `(6/3)+(2*5)` evaluates to `12`."; color: backend.themeForeground; font.pixelSize: 12 }
                    Text { text: "• Negative numbers: Use `_` prefix without spaces (e.g. `_42` or `_3.14`)."; color: backend.themeForeground; font.pixelSize: 12 }
                    Text { text: "• Clumps / Vectors: Space-separated numbers form an array (e.g. `10 20 30`)."; color: backend.themeForeground; font.pixelSize: 12 }
                    Text { text: "• Range generation: `1..10` generates `1 2 3 4 5 6 7 8 9 10`."; color: backend.themeForeground; font.pixelSize: 12 }
                    Text { text: "• Fold / Reduction: `clump INSERT op` reduces the array (e.g. `1..10 INSERT +` = 55)."; color: backend.themeForeground; font.pixelSize: 12 }
                    Text { text: "• 1-Based Indexing: `\"stressed\" [8..1]` returns `desserts`."; color: backend.themeForeground; font.pixelSize: 12 }
                    Text { text: "• Variable Assignment: `5 : fingers` assigns `fingers = 5`."; color: backend.themeForeground; font.pixelSize: 12 }
                    Text { text: "• Precision & Angle Settings: `4 : PLACES`, `1 : RADIANS` (1=Rad, 0=Deg)."; color: backend.themeForeground; font.pixelSize: 12 }
                    Text { text: "• Comments: `{ comment text here }`."; color: backend.themeForeground; font.pixelSize: 12 }
                }
            }

            // Operators table
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: tableCol.implicitHeight + 20
                color: backend.themeSurface
                radius: 8
                border.color: backend.themeBorder

                ColumnLayout {
                    id: tableCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text { text: "📋 Keyword & Operator Directory"; color: backend.themeAccent; font.bold: true; font.pixelSize: 14 }

                    Repeater {
                        model: [
                            { cat: "Arithmetic Dyads", items: "+, -, *, /, MOD, TOTHE (power), MIN, MAX, <, >, =, <=, >=, <>, AND, OR, XOR, COMB (nCr), PERM (nPr), DOT" },
                            { cat: "Vector Aggregations", items: "SUM, PROD (PRODUCT), MEAN (AVG), MEDIAN, NORM (Euclidean magnitude), GCD (GCF), LCM" },
                            { cat: "Array Transformations", items: "SORT, REVERSE, PRIMES, PRIME (primality test), PICK (random element), LENGTH (LEN)" },
                            { cat: "Math & Trig Monads", items: "SQRT, ABS, SIGN, FACT (factorial), NOT, FLOOR, CEILING, ROUND, TRUNCATE, SIN, COS, TAN, ARCSIN, ARCCOS, ARCTAN, LOG, LN, ODD, EVEN" },
                            { cat: "Text & Base Conversion", items: "STRING, VALUE, NUMBER (char code), LETTER (ASCII to char), HEX, BIN, OCT, FROMHEX, FROMBIN, FROMOCT" },
                            { cat: "Constants & Settings", items: "ANS (previous answer), PI, E, PLACES (0-18 decimals), RADIANS (1 or 0)" },
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: itemRow.implicitHeight + 12
                            color: index % 2 === 0 ? backend.themeSurfaceVariant : "transparent"
                            radius: 4

                            RowLayout {
                                id: itemRow
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 8

                                Text {
                                    text: modelData.cat
                                    color: backend.themeForeground
                                    font.bold: true
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 150
                                }

                                Text {
                                    text: modelData.items
                                    color: backend.themeMuted
                                    font.family: "Monospace"
                                    font.pixelSize: 12
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }

            // Keyboard Shortcuts
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: shortcutsCol.implicitHeight + 20
                color: backend.themeSurface
                radius: 8
                border.color: backend.themeBorder

                ColumnLayout {
                    id: shortcutsCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Text { text: "⌨️ Application Keyboard Shortcuts"; color: backend.themeAccent; font.bold: true; font.pixelSize: 14 }
                    Text { text: "• `Enter`: Evaluate expression and save to history tape"; color: backend.themeForeground; font.pixelSize: 12 }
                    Text { text: "• `Shift + Enter`: Evaluate with step-by-step reduction trace (Explain Mode)"; color: backend.themeForeground; font.pixelSize: 12 }
                    Text { text: "• `↑` / `↓` Arrow keys: Navigate through previously executed expressions"; color: backend.themeForeground; font.pixelSize: 12 }
                    Text { text: "• `Esc`: Clear current input / close window if input is empty"; color: backend.themeForeground; font.pixelSize: 12 }
                    Text { text: "• `Ctrl + 1` .. `Ctrl + 5`: Switch between Calc, Tape, Formulas, Variables, and Help"; color: backend.themeForeground; font.pixelSize: 12 }
                    Text { text: "• `Ctrl + L`: Clear display and input"; color: backend.themeForeground; font.pixelSize: 12 }
                }
            }
        }
    }
}
