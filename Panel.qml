import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Engine.js" as Engine

Panel {
  id: root
  moduleName: "dorneles.alcalc"
  ipcTarget: "dorneles.alcalc"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property var historyList: []
  property var varsMap: ({})
  property int places: 4
  property int radians: 1
  property int historyIndex: -1

  function stateDir() {
    return Quickshell.env("HOME") + "/.local/state/omarchy/alcalc"
  }

  // Live file watching
  property FileView histFile: FileView {
    path: stateDir() + "/history.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        root.historyList = JSON.parse(text())
      } catch (e) {}
    }
  }

  property FileView varsFile: FileView {
    path: stateDir() + "/vars.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        root.varsMap = JSON.parse(text())
      } catch (e) {}
    }
  }

  function open() {
    root.controller.show()
    Qt.callLater(function() {
      if (inputField) inputField.forceActiveFocus()
    })
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function copyText(text) {
    if (!text || text.length === 0) return
    Quickshell.execDetached(["wl-copy", text])
  }

  function evaluateCurrent(isExplain) {
    var rawExpr = inputField.text.toUpperCase().trim()
    if (rawExpr.length === 0) return

    if (rawExpr === "CLEAR" || rawExpr === "CLEAR TAPE") {
      Quickshell.execDetached(["bash", "-c", "mkdir -p '" + stateDir() + "' && echo '[]' > '" + stateDir() + "/history.json'"])
      root.historyList = []
      inputField.text = ""
      return
    }

    if (rawExpr === "FORGET" || rawExpr === "FORGET ALL") {
      Quickshell.execDetached(["bash", "-c", "mkdir -p '" + stateDir() + "' && echo '{}' > '" + stateDir() + "/vars.json'"])
      root.varsMap = {}
      inputField.text = ""
      return
    }

    // Expand macros
    var macroExpanded = Engine.expandMacros({}, rawExpr)
    var exprToEval = macroExpanded.expandedExpr

    var userVars = {}
    for (var k in root.varsMap) {
      userVars[k] = root.varsMap[k]
    }

    var evalFn = isExplain ? Engine.explainExpression : Engine.evaluateExpression
    var res = evalFn(exprToEval, userVars, root.places, root.radians)

    var newEntry = {
      expr: rawExpr,
      result: "",
      isError: false,
      time: new Date().toLocaleTimeString()
    }

    if (res.kind === "error") {
      newEntry.isError = true
      var smartTip = Engine.getSmartErrorTip(res.text, rawExpr)
      var errDisplay = res.text
      if (smartTip && smartTip.tip) {
        errDisplay += "\n  💡 " + smartTip.tip
      }
      newEntry.result = errDisplay
    } else {
      if (res.kind === "answer") {
        newEntry.result = res.text
        root.varsMap["ANS"] = res.value
      } else {
        newEntry.result = "(Stored)"
      }

      if (res.machine && res.machine.vars) {
        for (var v in res.machine.vars) {
          root.varsMap[v] = res.machine.vars[v]
        }
      }

      if (isExplain && res.steps && res.steps.length > 0) {
        var explainOut = ""
        for (var s = 0; s < res.steps.length; s++) {
          explainOut += (s + 1) + ". " + res.steps[s].expr + " ➔ " + res.steps[s].result + "\n"
        }
        explainOut += "= " + newEntry.result
        newEntry.result = explainOut
      }
    }

    var newHist = [newEntry].concat(root.historyList.slice(0, 99))
    root.historyList = newHist

    // Save to disk for cross-process synchronization
    var histJson = JSON.stringify(newHist, null, 2)
    var varsJson = JSON.stringify(root.varsMap, null, 2)
    Quickshell.execDetached(["bash", "-c", "mkdir -p '" + stateDir() + "' && cat << 'EOF' > '" + stateDir() + "/history.json'\n" + histJson + "\nEOF\ncat << 'EOF' > '" + stateDir() + "/vars.json'\n" + varsJson + "\nEOF"])

    inputField.text = ""
    root.historyIndex = -1
    tapeListView.positionViewAtBeginning()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem || (hostWidget ? hostWidget : null)
    owner: root.barIdentity
    bar: root.bar || (hostWidget ? hostWidget.bar : null)
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(Style.space(450), Style.space(480))
    focusTarget: inputField

    Item {
      anchors.fill: parent

      ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(8)

        // Header
        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(26)

          Text {
            text: "ALCALC"
            color: Color.accent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
          }

          Item { Layout.fillWidth: true }

          // Clear tape button
          Rectangle {
            id: clearBtn
            Layout.preferredWidth: Style.space(26)
            Layout.preferredHeight: Style.space(26)
            radius: Style.radius(4)
            color: clearMouseArea.pressed ? Util.alpha(Color.foreground, 0.15) : (clearMouseArea.containsMouse ? Util.alpha(Color.foreground, 0.08) : "transparent")

            Text {
              anchors.centerIn: parent
              text: "\uf1f8"
              color: clearMouseArea.containsMouse ? Color.urgent : Color.muted
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
            }

            MouseArea {
              id: clearMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                Quickshell.execDetached(["bash", "-c", "mkdir -p '" + stateDir() + "' && echo '[]' > '" + stateDir() + "/history.json'"])
                root.historyList = []
              }
            }

            PanelToolTip {
              visible: clearMouseArea.containsMouse
              text: "Clear paper tape"
            }
          }

          // Open full app button
          Rectangle {
            id: launchBtn
            Layout.preferredWidth: Style.space(26)
            Layout.preferredHeight: Style.space(26)
            radius: Style.radius(4)
            color: launchMouseArea.pressed ? Util.alpha(Color.foreground, 0.15) : (launchMouseArea.containsMouse ? Util.alpha(Color.foreground, 0.08) : "transparent")

            Text {
              anchors.centerIn: parent
              text: "\uf08e"
              color: launchMouseArea.containsMouse ? Color.accent : Color.muted
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
            }

            MouseArea {
              id: launchMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.close()
                if (root.bar) root.bar.run("alcalc")
                else Quickshell.execDetached(["alcalc"])
              }
            }

            PanelToolTip {
              visible: launchMouseArea.containsMouse
              text: "Open full application"
            }
          }
        }

        // Paper Tape Container (Feeds Bottom-to-Top)
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Util.alpha(Color.background, 0.5)
          border.color: Util.alpha(Color.foreground, 0.12)
          border.width: 1
          radius: Style.radius(6)

          ListView {
            id: tapeListView
            anchors.fill: parent
            anchors.margins: Style.space(8)
            clip: true
            spacing: Style.space(6)
            verticalLayoutDirection: ListView.BottomToTop
            model: root.historyList

            footer: ColumnLayout {
              width: tapeListView.width
              spacing: Style.space(2)

              Text {
                text: "Type expression and press Return (Shift+Return for Explain)."
                color: Color.muted
                font.family: "Monospace, monospace"
                font.pixelSize: Style.font.small
                font.italic: true
                wrapMode: Text.Wrap
                Layout.fillWidth: true
              }

              Item { Layout.preferredHeight: Style.space(4) }
            }

            delegate: ColumnLayout {
              width: tapeListView.width
              spacing: Style.space(2)

              // Expression
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(4)

                Text {
                  text: "!"
                  color: Color.accent
                  font.family: "Monospace, monospace"
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                Text {
                  text: modelData.expr || ""
                  color: Color.popups.text
                  font.family: "Monospace, monospace"
                  font.pixelSize: Style.font.body
                  font.bold: true
                  wrapMode: Text.Wrap
                  Layout.fillWidth: true

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      inputField.text = modelData.expr.toUpperCase()
                      inputField.cursorPosition = modelData.expr.length
                      inputField.forceActiveFocus()
                    }
                  }
                }
              }

              // Result
              Text {
                text: modelData.result || ""
                color: modelData.isError ? "#f38ba8" : Color.accent
                font.family: "Monospace, monospace"
                font.pixelSize: Style.font.body
                wrapMode: Text.Wrap
                Layout.fillWidth: true

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.copyText(modelData.result)
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
          Layout.preferredHeight: Style.space(36)
          Layout.minimumHeight: Style.space(36)
          Layout.maximumHeight: Style.space(36)
          spacing: Style.space(6)

          // Input Box
          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Util.alpha(Color.background, 0.5)
            border.color: inputField.activeFocus ? Color.accent : Util.alpha(Color.foreground, 0.12)
            border.width: 1
            radius: Style.radius(6)

            RowLayout {
              anchors.fill: parent
              spacing: 0

              Text {
                text: "!"
                color: Color.accent
                font.family: "Monospace, monospace"
                font.pixelSize: Style.font.body
                font.bold: true
                Layout.leftMargin: Style.space(8)
                Layout.rightMargin: Style.space(6)
              }

              TextField {
                id: inputField
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Color.popups.text
                font.family: "Monospace, monospace"
                font.pixelSize: Style.font.body
                font.capitalization: Font.AllUppercase
                background: Item {}
                padding: 0
                verticalAlignment: TextInput.AlignVCenter
                focus: true
                selectByMouse: true

                onTextChanged: {
                  var upper = text.toUpperCase()
                  if (text !== upper) {
                    var cur = cursorPosition
                    text = upper
                    cursorPosition = cur
                  }
                }

                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (event.modifiers & Qt.ShiftModifier) {
                      root.evaluateCurrent(true)
                    } else {
                      root.evaluateCurrent(false)
                    }
                    event.accepted = true
                  } else if (event.key === Qt.Key_Up) {
                    if (root.historyList && root.historyList.length > 0) {
                      root.historyIndex = Math.min(root.historyList.length - 1, root.historyIndex + 1)
                      inputField.text = (root.historyList[root.historyIndex].expr || "").toUpperCase()
                      inputField.cursorPosition = inputField.text.length
                    }
                    event.accepted = true
                  } else if (event.key === Qt.Key_Down) {
                    if (root.historyList && root.historyIndex > 0) {
                      root.historyIndex--
                      inputField.text = (root.historyList[root.historyIndex].expr || "").toUpperCase()
                      inputField.cursorPosition = inputField.text.length
                    } else if (root.historyIndex === 0) {
                      root.historyIndex = -1
                      inputField.text = ""
                    }
                    event.accepted = true
                  } else if (event.key === Qt.Key_Escape) {
                    if (inputField.text.length > 0) {
                      inputField.text = ""
                    } else {
                      root.close()
                    }
                    event.accepted = true
                  }
                }
              }
            }
          }

          // RETURN Button
          Rectangle {
            Layout.preferredWidth: Style.space(76)
            Layout.fillHeight: true
            color: returnMouseArea.pressed ? Qt.darker(Color.accent, 1.25) : Color.accent
            radius: Style.radius(6)

            Text {
              anchors.centerIn: parent
              text: "RETURN"
              color: "#ffffff"
              font.family: "Monospace, monospace"
              font.bold: true
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }

            MouseArea {
              id: returnMouseArea
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.evaluateCurrent(false)
            }
          }
        }
      }
    }
  }
}
