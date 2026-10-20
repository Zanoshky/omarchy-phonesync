import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Phone Sync in the bar: a phone icon that lights up while a paired phone is
// connected, and a panel to pair phones and push the theme.
Panel {
  id: root
  moduleName: "zanoshky.phonesync"
  ipcTarget: "zanoshky.phonesync"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool live: sync.connected.length > 0
  readonly property bool asking: sync.pairing !== null

  property int cursor: 0
  property bool cursorActive: false
  property bool typing: false

  // One flat list of rows, so the keyboard can walk it.
  readonly property var rows: {
    var r = []
    if (asking) {
      r.push({ kind: "yes" })
      r.push({ kind: "no" })
      return r
    }
    for (var i = 0; i < sync.peers.length; i++) r.push({ kind: "peer", peer: sync.peers[i] })
    for (var j = 0; j < sync.found.length; j++) r.push({ kind: "found", phone: sync.found[j] })
    r.push({ kind: "address" })
    if (live) r.push({ kind: "push" })
    return r
  }

  function appName(app) {
    return app === "hyprtile" ? "Hyprtile" : app === "phosphor" ? "Phosphor" : (app || "phone")
  }

  function heroMeta() {
    if (!sync.started) return "Starting"
    if (asking) return "Pairing with " + sync.pairing.name
    if (live) return "In step with " + sync.connected.map(function(p) { return p.name }).join(", ")
    if (sync.peers.length > 0) return "Paired, phone not in reach"
    if (sync.found.length > 0) return "Phone found, pair it below"
    return "No phone paired yet"
  }

  function peerDetail(p) {
    if (p.forgot) return "The phone forgot this computer. Forget it here and pair again."
    if (!p.connected) return appName(p.app) + ", not in reach"
    return appName(p.app) + (p.shows ? ", showing " + p.shows : ", connected")
  }

  function pairAddress(text) {
    var s = String(text || "").trim().replace(/[: ]+/, " ").split(" ")
    if (!/^[0-9a-zA-Z.\-]+$/.test(s[0] || "")) return
    sync.pair(s[0], /^[0-9]+$/.test(s[1] || "") ? s[1] : "")
  }

  // The main thing a row does on Enter or click.
  function activate(row) {
    if (!row) return
    if (row.kind === "yes") sync.answer(true)
    else if (row.kind === "no") sync.answer(false)
    else if (row.kind === "push") sync.push()
    else if (row.kind === "found") sync.pair(row.phone.host, row.phone.port)
    else if (row.kind === "peer" && row.peer.connected) sync.push()
    else if (row.kind === "address") root.typing = true
  }

  function moveCursor(dy) {
    cursorActive = true
    cursor = Math.max(0, Math.min(rows.length - 1, cursor + dy))
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onRowsChanged: if (cursor >= rows.length) cursor = Math.max(0, rows.length - 1)
  onAskingChanged: if (asking) { cursor = 0; typing = false; open() }
  onOpenedChanged: if (opened) {
    cursorActive = false
    cursor = 0
    typing = false
    sync.scan()
    Qt.callLater(function() { keys.forceActiveFocus() })
  }

  Service { id: sync }

  // A plain IpcHandler, since ShellIpc is new in Omarchy 4.5. Where the
  // shell has IpcRegistry it is registered too, so omarchy-shell reaches it.
  IpcHandler {
    id: ipc
    target: root.ipcTarget
    Component.onCompleted: if (typeof IpcRegistry !== "undefined") IpcRegistry.register(ipc)
    Component.onDestruction: if (typeof IpcRegistry !== "undefined") IpcRegistry.unregister(ipc)
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
          text: root.asking ? "󱘖" : "󰄜"
          color: root.asking ? Commons.Color.accent : root.barForeground
          opacity: root.live || root.asking ? 1.0 : 0.5
          font.family: root.fontFamily
          font.pixelSize: button.iconSize !== undefined ? button.iconSize : Math.min(Style.space(12), button.opticalSize)
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
    focusTarget: keys
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    // A plain child, not content:, which Omarchy 4.0 does not have.
    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      blocked: root.typing
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dy)
      }
      onActivateRequested: if (root.cursorActive) root.activate(root.rows[root.cursor])
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "s" || t === "S") sync.push()
        else if (t === "r" || t === "R") sync.scan()
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: parent.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Phone Sync"
            meta: root.heroMeta()
            detail: sync.computerName ? "This computer: " + sync.computerName : ""
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

          // The pairing code, big, while the phone shows the same question.
          Column {
            visible: root.asking
            width: parent.width
            spacing: Style.space(6)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: root.asking ? sync.pairing.code.substring(0, 3) + " " + sync.pairing.code.substring(3) : ""
              color: Commons.Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              text: root.asking ? root.appName(sync.pairing.app) + " on " + sync.pairing.name + " shows a code too. Pair only if both are the same, and tap pair on the phone as well." : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: text !== ""
            width: parent.width
            text: sync.note !== "" ? sync.note : sync.status
            color: root.dim
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

          PanelSeparator { foreground: root.foreground }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: root.asking ? "" : (sync.avahi
              ? "On the phone, turn link on in Hyprtile or Phosphor, on the same wifi. Pick a theme here or on the phone and the other follows; the newer pick wins."
              : "avahi is not installed, so phones are not found by themselves. Pair by the address in the phone's link menu.")
            visible: text !== ""
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
    readonly property var p: row.peer || ({})
    readonly property var f: row.phone || ({})

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
        text: ({ yes: "󰄬", no: "󰅖", push: "󰏘", address: "󰩟", found: "󰄜", peer: "󰄜" })[r.row.kind] || ""
        color: r.row.kind === "yes" ? Commons.Color.accent : root.foreground
        opacity: r.row.kind === "peer" && !r.p.connected ? 0.5 : 1.0
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        visible: !(r.row.kind === "address" && root.typing)
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: ({
            yes: "Same code, pair",
            no: "Not the same",
            push: "Send " + sync.theme + " to the phone",
            address: "Pair by address",
            found: r.f.name || "",
            peer: r.p.name || ""
          })[r.row.kind] || ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: r.row.kind === "peer" ? root.peerDetail(r.p)
            : r.row.kind === "found" ? root.appName(r.f.app) + ", link on, ready to pair"
            : r.row.kind === "address" ? "The address is in the phone's link menu"
            : r.row.kind === "push" ? "It also goes over by itself when you pick a theme"
            : ""
          visible: text !== ""
          color: r.p.forgot ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      TextField {
        id: addressField
        visible: r.row.kind === "address" && root.typing
        Layout.fillWidth: true
        placeholderText: "192.168.1.20"
        foreground: root.foreground
        onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
        Keys.onEscapePressed: { root.typing = false; keys.forceActiveFocus() }
        onAccepted: { root.pairAddress(text); root.typing = false; keys.forceActiveFocus() }
      }

      PanelActionButton {
        visible: r.row.kind === "found"
        iconText: "󰌹"
        tooltipText: "Pair"
        foreground: root.foreground
        fontFamily: root.fontFamily
        Layout.alignment: Qt.AlignVCenter
        onClicked: sync.pair(r.f.host, r.f.port)
      }

      PanelActionButton {
        visible: r.row.kind === "peer"
        iconText: "󰌊"
        tooltipText: "Forget this phone"
        foreground: root.foreground
        hoverColor: root.urgent
        fontFamily: root.fontFamily
        Layout.alignment: Qt.AlignVCenter
        onClicked: sync.forget(r.p.id)
      }
    }
  }
}
