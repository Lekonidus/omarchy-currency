import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

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

  // USD/EUR are the usual "from"; ILS is the usual "to".
  property string fromCode: Model.normalizeCode(setting("from", "USD")) || "USD"
  property string toCode: Model.normalizeCode(setting("to", "ILS")) || "ILS"
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

  onFromCodeChanged: Qt.callLater(refresh)
  onToCodeChanged: Qt.callLater(refresh)
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

  function persistPair(from, to) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    entry.from = from
    entry.to = to
    root.settings = entry
    root.fromCode = from
    root.toCode = to
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setFrom(code) {
    var next = Model.normalizeCode(code)
    if (!next || next === fromCode) return
    persistPair(next, toCode)
  }

  function setTo(code) {
    var next = Model.normalizeCode(code)
    if (!next || next === toCode) return
    persistPair(fromCode, next)
  }

  function refresh() {
    if (fetchProc.running) fetchProc.running = false
    loading = true
    statusText = ""
    fetchProc.command = ["curl", "-fsSL", "--max-time", "8", Model.frankfurterUrl(fromCode)]
    fetchProc.running = true
  }

  function swapPair() {
    persistPair(toCode, fromCode)
  }

  function pickerOpen() {
    return fromPicker.popupOpen || toPicker.popupOpen
  }

  function fieldFocused() {
    return amountField.activeFocus || pickerOpen()
  }

  Component.onCompleted: refresh()

  Timer {
    interval: 60 * 60 * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: fetchProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.loading = false
        var parsed = Model.parseFrankfurter(text)
        if (!parsed) {
          root.statusText = "Rate fetch failed"
          return
        }
        root.rates = parsed.rates
        root.statusText = parsed.date ? ("ECB " + parsed.date) : ""
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (!fetchProc.running && root.loading) {
          root.loading = false
          if (text && text.length) root.statusText = "Offline"
        }
      }
    }
    onExited: function(code) {
      if (code !== 0 && root.loading) {
        root.loading = false
        if (!root.statusText) root.statusText = "Offline"
      }
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

        SearchableDropdown {
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

        SearchableDropdown {
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
          text: isNaN(root.converted)
            ? (root.loading ? "..." : "No rate")
            : (Model.formatMoney(root.converted) + " " + root.toCode)
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
