import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Phone Sync in the bar: a phone icon that lights up while a paired launcher
// is connected, and a panel to set up KDE Connect, pair, and push the theme.
Panel {
  id: root
  moduleName: "zanoshky.phonesync"
  ipcTarget: "zanoshky.phonesync"
  manageIpc: false

  readonly property Item panelFlick: panel.loadedContent ? panel.loadedContent.panelFlick : null

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool live: sync.connected.length > 0
  readonly property bool asked: sync.asking.length > 0

  property int cursor: 0
  property bool cursorActive: false

  // One flat list of rows, so the keyboard can walk it.
  readonly property var rows: {
    var r = []
    if (sync.kdeconnect !== "" && !sync.ready) r.push({ kind: "setup" })
    for (var i = 0; i < sync.devices.length; i++) r.push({ kind: "device", device: sync.devices[i] })
    if (sync.connected.length > 0) r.push({ kind: "push" })
    return r
  }

  function heroMeta() {
    if (sync.kdeconnect === "") return "Looking for KDE Connect"
    if (sync.kdeconnect === "missing") return "KDE Connect is not installed"
    if (sync.kdeconnect === "stopped") return "KDE Connect is not running"
    if (asked) return sync.asking[0].name + " asks to pair"
    if (live) return "In step with " + sync.connected.map(function(d) { return d.name }).join(", ")
    if (sync.paired.length > 0) return "Paired, phone not in reach"
    return "No phone paired yet"
  }

  function deviceDetail(d) {
    if (d.asks) return "Asks to pair. Same key on the phone? " + d.key
    if (d.requested) return "Waiting for the phone. Key " + d.key
    if (d.paired && d.reachable) return d.theme ? "Paired, showing " + d.theme.theme : "Paired, connected"
    if (d.paired) return "Paired, not in reach"
    return d.launcher ? "Ready to pair" : "KDE Connect device, ready to pair"
  }

  function deviceGlyph(d) {
    if (d.type === "tablet") return "󰓶"
    if (d.type === "desktop" || d.type === "laptop") return "󰌢"
    return "󰄜"
  }

  // The main thing a row does on Enter or click.
  function activate(row) {
    if (!row) return
    if (row.kind === "setup") sync.setup()
    else if (row.kind === "push") sync.push()
    else {
      var d = row.device
      if (d.asks) sync.accept(d.id)
      else if (d.requested) sync.reject(d.id)
      else if (!d.paired && d.reachable) sync.pair(d.id)
      else if (d.paired && d.reachable && d.launcher) sync.push()
    }
  }

  function moveCursor(dy) {
    cursorActive = true
    cursor = Math.max(0, Math.min(rows.length - 1, cursor + dy))
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onRowsChanged: if (cursor >= rows.length) cursor = Math.max(0, rows.length - 1)
  onOpenedChanged: if (opened) {
    cursorActive = false
    cursor = 0
    sync.refresh()
    Qt.callLater(function() { if (panel.loadedContent) panel.loadedContent.forceActiveFocus() })
  }

  Service { id: sync }

  ShellIpc {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function push(): string { sync.push(); return "ok" }
    function status(): string { return root.heroMeta() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        Text {
          anchors.centerIn: parent
          text: root.asked ? "󱘖" : "󰄜"
          color: root.asked ? Commons.Color.accent : root.barForeground
          opacity: root.live || root.asked ? 1.0 : 0.5
          font.family: root.fontFamily
          font.pixelSize: button.iconSize
        }
      }
    }
    onPressed: function(code) {
      if (code === Qt.MiddleButton) sync.push()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(560))

    content: PanelKeyCatcher {
      property alias panelFlick: panelFlick
      implicitHeight: column.implicitHeight
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dy)
      }
      onActivateRequested: if (root.cursorActive) root.activate(root.rows[root.cursor])
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "s" || t === "S") sync.push()
        else if (t === "r" || t === "R") sync.refresh()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Phone Sync"
            meta: root.heroMeta()
            detail: sync.ready && sync.computerName ? "This computer: " + sync.computerName : ""
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.live ? 1.0 : 0.5
            iconComponent: Component {
              Text {
                text: "󰄜"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: text !== ""
            width: parent.width
            text: sync.note !== "" ? sync.note : sync.lastError
            color: sync.note === "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Column {
            id: rowColumn
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.rows
              ListRow {
                required property var modelData
                required property int index
                width: rowColumn.width
                row: modelData
                rowIndex: index
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: sync.ready && sync.devices.length === 0
            width: parent.width
            text: "Turn link on in Hyprtile or Phosphor on your phone, on the same wifi. It shows up here to pair."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          PanelSeparator { foreground: root.foreground }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "Pick a theme here or on the phone and the other follows. The newer pick wins when they were apart."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  component ListRow: CursorSurface {
    id: r
    property var row: ({})
    property int rowIndex: 0
    readonly property var d: row.device || ({})

    hasCursor: root.cursorActive && root.cursor === rowIndex
    foreground: root.foreground
    implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: { root.cursorActive = true; root.cursor = r.rowIndex }
      onClicked: root.activate(r.row)
    }

    RowLayout {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: r.row.kind === "setup" ? "󰒓" : r.row.kind === "push" ? "󰏘" : root.deviceGlyph(r.d)
        color: r.d.asks ? Commons.Color.accent : root.foreground
        opacity: r.row.kind === "device" && !r.d.reachable ? 0.5 : 1.0
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: r.row.kind === "setup" ? (sync.kdeconnect === "missing" ? "Set up KDE Connect" : "Start KDE Connect")
            : r.row.kind === "push" ? "Send " + sync.theme + " to the phone" : r.d.name
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: r.row.kind === "setup" ? "Installs it and opens its ports in the firewall"
            : r.row.kind === "push" ? "It goes over right away when you pick a theme too" : root.deviceDetail(r.d)
          color: r.d.asks ? Commons.Color.accent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      PanelActionButton {
        visible: r.row.kind === "device" && (r.d.asks || (!r.d.paired && !r.d.requested && r.d.reachable))
        iconText: "󰄬"
        tooltipText: r.d.asks ? "Pair, the keys match" : "Pair"
        foreground: root.foreground
        fontFamily: root.fontFamily
        Layout.alignment: Qt.AlignVCenter
        onClicked: r.d.asks ? sync.accept(r.d.id) : sync.pair(r.d.id)
      }

      PanelActionButton {
        visible: r.row.kind === "device" && (r.d.asks || r.d.requested || r.d.paired)
        iconText: r.d.paired ? "󰌊" : "󰅖"
        tooltipText: r.d.paired ? "Unpair" : r.d.asks ? "Do not pair" : "Stop asking"
        foreground: root.foreground
        hoverColor: root.urgent
        fontFamily: root.fontFamily
        Layout.alignment: Qt.AlignVCenter
        onClicked: r.d.paired ? sync.unpair(r.d.id) : sync.reject(r.d.id)
      }
    }
  }
}
