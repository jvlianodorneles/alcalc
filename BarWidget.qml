import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dorneles.alcalc"

  readonly property bool currentShowLastAns: setting("showLastAns", false)
  property var varsState: ({})
  readonly property string lastAns: (varsState && varsState.ANS && varsState.ANS.items && varsState.ANS.items[0]) ? String(varsState.ANS.items[0].v) : ""

  // Watch vars.json for live answer updates
  property FileView varsFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/alcalc/vars.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        root.varsState = JSON.parse(text())
      } catch (e) {}
    }
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Loader for popup panel
  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // IPC handler for keybindings and shell commands
  IpcHandler {
    target: "dorneles.alcalc"

    function toggle(): void { root.togglePanel() }
    function open(): void { root.open() }
    function close(): void { root.close() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: (currentShowLastAns && root.lastAns !== "") ? ("\uf1ec " + root.lastAns) : "\uf1ec"
    active: root.opened
    fontSize: Style.bar.iconFont
    tooltipText: root.lastAns !== "" ? ("Alcalc (ANS: " + root.lastAns + ")\n• Click: Open Paper Tape\n• Right-click: Launch App") : "Alcalc (Apple Calculator Language)\n• Click: Open Paper Tape\n• Right-click: Launch App"

    onPressed: function(btn) {
      if (btn === Qt.RightButton) {
        if (root.bar) root.bar.run("alcalc")
      } else {
        root.togglePanel()
      }
    }
  }
}
