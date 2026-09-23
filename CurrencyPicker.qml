import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

// Controlled searchable currency picker.
// Parent owns `value`. This component never assigns to `value` — it only
// emits changed(code). That avoids SearchableDropdown's selectCurrent writing
// value= and breaking parent bindings (labels stuck on USD while math swaps).
Item {
  id: root

  property string label: ""
  property string value: ""
  property var options: []
  property string placeholderText: "Search..."
  property string emptyText: "No matches"
  property color foreground: Color.foreground
  property color accent: Color.accent
  property color popupBackground: Color.popups.background
  property color popupBorder: Color.popups.border
  property string fontFamily: Style.font.family
  property int rowHeight: Style.spacing.controlHeight
  property int popupRowHeight: Style.spacing.popupRowHeight
  property int popupMinHeight: Style.spacing.searchablePopupMinHeight

  readonly property var popupBorderSpec: Border.localOrSurfaceSpec(
    "popups", "border", popupBorder, Color.popups.border, Style.normalBorderWidth)
  readonly property bool popupOpen: popup.opened
  // Property (not a function call in the Text binding) so the trigger always
  // tracks `value` / `options` changes.
  readonly property string displayLabel: {
    for (var i = 0; i < options.length; i++) {
      var o = options[i]
      var code = (o && typeof o === "object") ? String(o.value) : String(o)
      if (code === value)
        return (o && typeof o === "object") ? String(o.label) : String(o)
    }
    return value
  }

  signal changed(string value)

  function optionValue(o) {
    return (o && typeof o === "object") ? String(o.value) : String(o)
  }
  function optionLabel(o) {
    return (o && typeof o === "object") ? String(o.label) : String(o)
  }
  function optionDescription(o) {
    return (o && typeof o === "object" && o.description) ? String(o.description) : ""
  }

  property var filtered: options
  function recomputeFiltered() {
    var q = searchField.text.toLowerCase()
    if (!q) { filtered = options; return }
    var out = []
    for (var i = 0; i < options.length; i++) {
      var lbl = optionLabel(options[i]).toLowerCase()
      var desc = optionDescription(options[i]).toLowerCase()
      var val = optionValue(options[i]).toLowerCase()
      if (lbl.indexOf(q) !== -1 || desc.indexOf(q) !== -1 || val.indexOf(q) !== -1)
        out.push(options[i])
    }
    filtered = out
  }

  onOptionsChanged: recomputeFiltered()
  Component.onCompleted: recomputeFiltered()

  function open() { popup.open() }
  function close() { popup.close() }

  implicitWidth: Style.spacing.searchableDropdownWidth
  implicitHeight: label !== "" ? rowHeight + Style.spacing.huge : rowHeight

  Column {
    anchors.fill: parent
    spacing: Style.spacing.labelGap

    Text {
      textFormat: Text.PlainText
      visible: root.label !== ""
      text: root.label
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    BorderSurface {
      id: trigger
      width: parent.width
      height: root.rowHeight
      radius: Style.cornerRadius

      readonly property bool _focused: trigger.activeFocus || popup.opened
      readonly property bool _hot: triggerHover.hovered
      readonly property var _borderSpec: Border.controlSpec(
        trigger._focused ? "focus" : (trigger._hot ? "hover-cursor" : "normal"),
        root.foreground, root.accent)

      color: Style.controlFill(trigger._focused, trigger._hot, root.foreground, root.accent)
      borderSpec: _borderSpec
      activeFocusOnTab: true

      HoverHandler { id: triggerHover }

      Text {
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.right: chevron.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: trigger.borderLeft + Style.spacing.controlPaddingX
        anchors.rightMargin: Style.spacing.md
        text: root.displayLabel || root.placeholderText
        color: root.displayLabel ? root.foreground : Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        id: chevron
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: trigger.borderRight + Style.spacing.controlGap
        text: "󰅀"
        color: Qt.darker(root.foreground, 1.2)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          trigger.forceActiveFocus()
          popup.opened ? popup.close() : popup.open()
        }
      }

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
            || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
          popup.opened ? popup.close() : popup.open()
          event.accepted = true
        } else if (event.key === Qt.Key_Escape && popup.opened) {
          popup.close(); event.accepted = true
        }
      }

      QQC.Popup {
        id: popup
        x: 0
        y: trigger.height + Style.spacing.xxs
        width: trigger.width
        implicitHeight: Math.max(root.popupMinHeight,
                                 Math.min(resultList.contentHeight + Style.space(50),
                                          root.popupRowHeight * 6 + 5 * Style.spacing.labelGap + Style.space(50)))
        padding: Style.spacing.hairline
        leftPadding: Border.left(root.popupBorderSpec) + Style.spacing.hairline
        rightPadding: Border.right(root.popupBorderSpec) + Style.spacing.hairline
        topPadding: Border.top(root.popupBorderSpec) + Style.spacing.hairline
        bottomPadding: Border.bottom(root.popupBorderSpec) + Style.spacing.hairline
        focus: true

        background: BorderSurface {
          color: root.popupBackground
          borderSpec: root.popupBorderSpec
          radius: Style.cornerRadius
        }

        onOpened: {
          searchField.text = ""
          root.recomputeFiltered()
          Qt.callLater(function() { searchField.forceActiveFocus() })
        }
        onClosed: searchField.text = ""

        contentItem: Column {
          spacing: 0

          Item {
            width: parent.width
            height: root.popupRowHeight + Style.spacing.controlPaddingX

            TextField {
              id: searchField
              anchors.fill: parent
              anchors.margins: Style.spacing.md
              placeholderText: root.placeholderText
              foreground: root.foreground
              accent: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              onTextChanged: {
                root.recomputeFiltered()
                if (resultList.count > 0) resultList.currentIndex = 0
              }
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  popup.close(); event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                  if (resultList.count > 0) {
                    resultList.currentIndex = 0
                    resultList.forceActiveFocus()
                  }
                  event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  if (resultList.count > 0) {
                    resultList.currentIndex = 0
                    resultList.pickCurrent()
                  }
                  event.accepted = true
                }
              }
            }
          }

          Rectangle {
            width: parent.width
            height: 1
            color: Util.alpha(root.foreground, 0.10)
          }

          Item {
            width: parent.width
            height: popup.height - root.popupRowHeight - Style.spacing.controlPaddingX - Style.spacing.xxs - 1

            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              visible: resultList.count === 0
              text: root.emptyText
              color: Qt.darker(root.foreground, 1.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            ListView {
              id: resultList
              anchors.fill: parent
              spacing: Style.spacing.labelGap
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              model: root.filtered
              currentIndex: -1
              keyNavigationEnabled: false

              function pickCurrent() {
                if (currentIndex < 0 || currentIndex >= root.filtered.length) return
                // Emit only — never write root.value.
                root.changed(root.optionValue(root.filtered[currentIndex]))
                popup.close()
              }

              Keys.priority: Keys.BeforeItem
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  popup.close(); event.accepted = true
                } else if (event.key === Qt.Key_Down || event.text === "j") {
                  if (resultList.currentIndex < resultList.count - 1)
                    resultList.currentIndex = resultList.currentIndex + 1
                  event.accepted = true
                } else if (event.key === Qt.Key_Up || event.text === "k") {
                  if (resultList.currentIndex <= 0) searchField.forceActiveFocus()
                  else resultList.currentIndex = resultList.currentIndex - 1
                  event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  resultList.pickCurrent(); event.accepted = true
                }
              }

              delegate: Rectangle {
                required property var modelData
                required property int index
                width: resultList.width
                height: Math.max(root.popupRowHeight, rowContent.implicitHeight + Style.spacing.rowPaddingX)
                color: index === resultList.currentIndex
                  ? Style.hoverFillFor(root.foreground, root.accent)
                  : "transparent"

                Column {
                  id: rowContent
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.spacing.controlPaddingX
                  anchors.rightMargin: Style.spacing.controlPaddingX
                  spacing: Style.spacing.xxs

                  Text {
                    textFormat: Text.PlainText
                    text: root.optionLabel(modelData)
                    color: index === resultList.currentIndex
                      ? Style.hoverStateColor(root.foreground, root.accent)
                      : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                    width: parent.width
                  }
                  Text {
                    textFormat: Text.PlainText
                    visible: text !== ""
                    text: root.optionDescription(modelData)
                    color: Qt.darker(root.foreground, 1.5)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    width: parent.width
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPositionChanged: resultList.currentIndex = parent.index
                  onClicked: {
                    resultList.currentIndex = parent.index
                    resultList.pickCurrent()
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
