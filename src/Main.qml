import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import "components"

ApplicationWindow {
    id: win
    width: 500
    height: 640
    minimumWidth: 380
    minimumHeight: 460
    visible: true
    title: "Alcalc - Apple Calculator Language"

    readonly property bool darkMode: backend.darkMode
    readonly property real textScale: backend.textScale

    Material.theme: darkMode ? Material.Dark : Material.Light
    Material.accent: backend.themeAccent
    color: backend.themeBackground

    // Global Shortcuts
    Shortcut { sequence: "Ctrl+1"; onActivated: mainTabBar.currentIndex = 0 }
    Shortcut { sequence: "Ctrl+2"; onActivated: mainTabBar.currentIndex = 1 }
    Shortcut { sequence: "Ctrl+3"; onActivated: mainTabBar.currentIndex = 2 }
    Shortcut { sequence: "Ctrl+4"; onActivated: mainTabBar.currentIndex = 3 }
    Shortcut { sequence: "Ctrl+5"; onActivated: mainTabBar.currentIndex = 4 }
    Shortcut { sequence: "Ctrl+L"; onActivated: calcView.expressionText = "" }
    Shortcut { sequence: "Ctrl+Shift+C"; onActivated: calcView.copyResult() }
    Shortcut { sequence: "Esc"; onActivated: {
        if (calcView.expressionText.length > 0) {
            calcView.expressionText = "";
        } else {
            win.close();
        }
    }}

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // =============================================================
        // HEADER BAR: TITLE + MODE PILLS
        // =============================================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "🧮"
                font.pixelSize: 20
            }

            Text {
                text: "Alcalc"
                color: backend.themeForeground
                font.bold: true
                font.pixelSize: 18
            }

            Text {
                text: "• Apple Calculator"
                color: backend.themeMuted
                font.pixelSize: 13
                Layout.fillWidth: true
            }

            // Radians / Degrees Toggle Pill
            Button {
                Layout.preferredHeight: 30
                Layout.preferredWidth: 64
                contentItem: Text {
                    text: backend.radians ? "RAD" : "DEG"
                    color: backend.themeAccent
                    font.bold: true
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: backend.themeSurface
                    border.color: backend.themeBorder
                    radius: 15
                }
                ToolTip.visible: hovered
                ToolTip.text: "Angle mode: " + (backend.radians ? "Radians (Click for Degrees)" : "Degrees (Click for Radians)")
                onClicked: backend.setRadians(backend.radians ? 0 : 1)
            }

            // Decimal Places Stepper Pill
            Button {
                Layout.preferredHeight: 30
                Layout.preferredWidth: 84
                contentItem: Text {
                    text: "Places: " + backend.places
                    color: backend.themeForeground
                    font.bold: true
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: backend.themeSurface
                    border.color: backend.themeBorder
                    radius: 15
                }
                ToolTip.visible: hovered
                ToolTip.text: "Decimal precision: " + backend.places + " (Click to cycle 2, 4, 6, 8, 0)"
                onClicked: {
                    var nextP = (backend.places === 4) ? 6 : (backend.places === 6) ? 8 : (backend.places === 8) ? 0 : (backend.places === 0) ? 2 : 4;
                    backend.setPlaces(nextP);
                }
            }
        }

        // =============================================================
        // MAIN NAVIGATION TABS
        // =============================================================
        TabBar {
            id: mainTabBar
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            background: Rectangle {
                color: backend.themeSurface
                radius: 6
                border.color: backend.themeBorder
            }

            TabButton {
                text: "🧮 Calc"
                font.bold: mainTabBar.currentIndex === 0
                font.pixelSize: 12
            }
            TabButton {
                text: "📜 Tape" + (backend.historyList.length > 0 ? " (" + backend.historyList.length + ")" : "")
                font.bold: mainTabBar.currentIndex === 1
                font.pixelSize: 12
            }
            TabButton {
                text: "📚 Formulas"
                font.bold: mainTabBar.currentIndex === 2
                font.pixelSize: 12
            }
            TabButton {
                text: "🧩 Vars & Macros"
                font.bold: mainTabBar.currentIndex === 3
                font.pixelSize: 12
            }
            TabButton {
                text: "❓ Help"
                font.bold: mainTabBar.currentIndex === 4
                font.pixelSize: 12
            }
        }

        // =============================================================
        // TAB VIEWS CONTAINER
        // =============================================================
        StackLayout {
            id: mainStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: mainTabBar.currentIndex

            // Tab 0: Calculator REPL
            CalcView {
                id: calcView
            }

            // Tab 1: History Tape
            TapeView {
                id: tapeView
                onRequestLoadExpression: function(expr) {
                    calcView.setExpression(expr, true);
                    mainTabBar.currentIndex = 0;
                }
            }

            // Tab 2: Curated Formulas
            FormulasView {
                id: formulasView
                onRequestLoadFormula: function(expr) {
                    calcView.setExpression(expr, true);
                    mainTabBar.currentIndex = 0;
                }
            }

            // Tab 3: Variables & Macros
            VarsMacrosView {
                id: varsMacrosView
                onRequestRunMacro: function(macroName) {
                    calcView.setExpression(macroName, true);
                    mainTabBar.currentIndex = 0;
                }
            }

            // Tab 4: Cheatsheet Manual
            CheatsheetView {
                id: cheatsheetView
            }
        }
    }
}
