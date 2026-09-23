import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Icon-sized bar slot (same as weather / hass). Rate lives in the tooltip
// and the popup; the glyph stays a fixed statusSlot wide.
BarWidget {
  id: root
  moduleName: "io.github.lekonidus.currency"

  readonly property string rateText: panelLoader.item ? panelLoader.item.rateText : ""
  readonly property string statusText: panelLoader.item ? panelLoader.item.statusText : ""

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    // Force fresh Panel after edits — resolvedUrl alone can stick to a cached component.
    source: Qt.resolvedUrl("./Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "io.github.lekonidus.currency"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function refresh(): string { root.refresh(); return "ok" }
    function status(): string {
      return panelLoader.item && panelLoader.item.statusJson
        ? panelLoader.item.statusJson()
        : "{\"error\":\"panel not ready\"}"
    }
    function swap(): string {
      if (panelLoader.item && panelLoader.item.swapPair) panelLoader.item.swapPair()
      return status()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.BAR_ICON
    slotSize: Style.bar.statusSlot
    tooltipText: root.rateText || root.statusText || "Currency"
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }
}
