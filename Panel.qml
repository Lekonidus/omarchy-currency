import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "PanelLogic.js" as Logic

Panel {
  id: root
  moduleName: "io.github.lekonidus.currency"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string pluginDir: {
    var path = Qt.resolvedUrl(".").toString()
    if (path.indexOf("file://") === 0) path = path.slice(7)
    if (path.length > 1 && path.charAt(path.length - 1) === "/") path = path.slice(0, -1)
    return path
  }

  property string fromCode: "USD"
  property string toCode: "ILS"
  property string amountText: "1"
  property var rates: ({})
  property string statusText: ""
  property bool loading: false

  readonly property var fromOptions: Model.currencyOptions(["USD", "EUR"])
  readonly property var toOptions: Model.currencyOptions(["ILS", "USD", "EUR"])

  readonly property real unitRate: {
    var rate = Model.rateBetween(fromCode, toCode, rates)
    return rate === null ? NaN : rate
  }
  readonly property real converted: {
    var value = Model.convert(amountText, fromCode, toCode, rates)
    return value === null ? NaN : value
  }
  readonly property string rateText: {
    if (isNaN(unitRate)) return loading ? "Fetching..." : ""
    return Model.rateLabel(fromCode, toCode, unitRate)
  }
  readonly property string resultText: {
    if (isNaN(converted)) return loading ? "..." : "No rate"
    return Model.formatMoney(converted) + " " + toCode
  }

  onSettingsChanged: applySettingsPair()
  onOpenedChanged: if (opened) {
    Qt.callLater(function() {
      amountField.selectAll()
      amountField.forceActiveFocus()
    })
  }

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { opened ? close() : open() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function applySettingsPair() {
    var pair = Model.normalizePair(setting("from", "USD"), setting("to", "ILS"), "USD", "ILS")
    fromCode = pair.from
    toCode = pair.to
  }

  function persistPair(from, to) {
    var pair = Model.normalizePair(from, to, fromCode, toCode)
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    entry.from = pair.from
    entry.to = pair.to
    root.settings = entry
    root.fromCode = pair.from
    root.toCode = pair.to
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setFrom(code) {
    var next = Model.normalizeCode(code)
    if (!Model.isKnownCode(next) || next === fromCode) return
    persistPair(next, toCode)
  }

  function setTo(code) {
    var next = Model.normalizeCode(code)
    if (!Model.isKnownCode(next) || next === toCode) return
    persistPair(fromCode, next)
  }

  function swapPair() {
    var next = Logic.applySwap(fromCode, toCode)
    persistPair(next.from, next.to)
  }

  function refresh() {
    if (fetchProc.running) fetchProc.running = false
    loading = true
    statusText = ""
    fetchProc.command = [root.pluginDir + "/bin/fetch-rates", Model.frankfurterUrl()]
    fetchProc.running = true
  }

  function pickerOpen() {
    return fromPicker.popupOpen || toPicker.popupOpen
  }

  function fieldFocused() {
    return amountField.activeFocus || pickerOpen()
  }

  function statusJson() {
    var snap = Logic.uiSnapshot(fromCode, toCode, amountText, rates, Model)
    snap.loading = loading
    snap.statusText = statusText
    snap.fromPicker = fromPicker ? fromPicker.value : ""
    snap.toPicker = toPicker ? toPicker.value : ""
    snap.labelsMatch = Logic.labelsMatchCodes(
      fromPicker ? fromPicker.value : "",
      toPicker ? toPicker.value : "",
      fromCode, toCode)
    return JSON.stringify(snap)
  }

  Component.onCompleted: {
    applySettingsPair()
    refresh()
  }

  Timer {
    interval: 60 * 60 * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: fetchProc
    stdout: StdioCollector { id: fetchOut }
    stderr: StdioCollector { }
    onExited: function(code) {
      root.loading = false
      if (code !== 0) {
        if (code === 3) root.statusText = "Response too large"
        else if (code === 4) root.statusText = "Timed out"
        else if (!root.statusText) root.statusText = "Offline"
        return
      }
      var parsed = Model.parseFrankfurter(fetchOut.text)
      if (!parsed) {
        root.statusText = "Rate fetch failed"
        return
      }
      root.rates = parsed.rates
      root.statusText = parsed.date ? ("ECB " + parsed.date) : ""
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.fieldFocused()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
        else if (t === "s" || t === "S") root.swapPair()
      }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "Currency"
          meta: root.statusText || (root.loading ? "Fetching..." : "Frankfurter / ECB")
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        TextField {
          id: amountField
          width: parent.width
          text: root.amountText
          placeholderText: "Amount"
          foreground: root.foreground
          font.family: root.fontFamily
          inputMethodHints: Qt.ImhFormattedNumbersOnly
          onTextChanged: root.amountText = text
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
          }
        }

        CurrencyPicker {
          id: fromPicker
          width: parent.width
          label: "From"
          fontFamily: root.fontFamily
          foreground: root.foreground
          placeholderText: "Search currency..."
          options: root.fromOptions
          value: root.fromCode
          onChanged: function(v) { root.setFrom(v) }
        }

        CurrencyPicker {
          id: toPicker
          width: parent.width
          label: "To"
          fontFamily: root.fontFamily
          foreground: root.foreground
          placeholderText: "Search currency..."
          options: root.toOptions
          value: root.toCode
          onChanged: function(v) { root.setTo(v) }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.resultText
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          wrapMode: Text.WordWrap
        }

        Text {
          width: parent.width
          visible: !isNaN(root.unitRate)
          textFormat: Text.PlainText
          text: root.rateText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Row {
          spacing: Style.space(8)

          Button {
            text: "Swap"
            iconText: "\uf0ec"
            foreground: root.foreground
            fontFamily: root.fontFamily
            bordered: true
            onClicked: root.swapPair()
          }

          Button {
            text: "Refresh"
            foreground: root.foreground
            fontFamily: root.fontFamily
            bordered: true
            onClicked: root.refresh()
          }
        }
      }
    }
  }
}
