import QtQuick
import Quickshell
import Quickshell.Io

// Runs bin/phonesync watch for as long as the widget is on the bar. The
// helper holds the lines to the phones and does the syncing itself; it
// prints one JSON line per change, which lands in the properties below, and
// takes one command per line on stdin.
Item {
  id: root

  readonly property string helper: decodeURIComponent(Qt.resolvedUrl("bin/phonesync").toString().replace(/^file:\/\//, ""))

  property bool started: false
  property string computerName: ""
  property string theme: ""
  property bool avahi: true
  property var peers: []
  property var found: []
  // {name, app, code} while a pairing waits for the user, else null.
  property var pairing: null
  property string status: ""
  property string note: ""

  readonly property var connected: peers.filter(function(p) { return p.connected })

  function handle(line) {
    var o
    try { o = JSON.parse(line) } catch (e) { return }
    if (o.type === "state") {
      started = true
      computerName = String(o.name || "")
      theme = String(o.theme || "")
      avahi = o.avahi !== false
      peers = o.peers || []
      found = o.found || []
      pairing = o.pairing || null
      status = String(o.status || "")
    } else if (o.type === "synced") {
      note = o.direction === "in"
        ? "Took " + o.theme + " from " + o.device
        : "Sent " + o.theme + " to " + o.device
      noteTimer.restart()
    }
  }

  function send(cmd) {
    if (watcher.running) watcher.write(cmd + "\n")
  }

  function pair(host, port) { send("pair " + host + (port ? " " + port : "")) }
  function answer(yes) { send("answer " + (yes ? "yes" : "no")) }
  function forget(id) { send("forget " + id) }
  function push() { send("push") }
  function scan() { send("scan") }

  Process {
    id: watcher
    command: ["python3", root.helper, "watch"]
    running: true
    stdinEnabled: true
    stdout: SplitParser { onRead: function(line) { root.handle(line) } }
    // The helper only stops with the shell; if it falls over, start it again.
    onExited: restart.start()
  }

  Timer {
    id: restart
    interval: 5000
    onTriggered: watcher.running = true
  }

  Timer {
    id: noteTimer
    interval: 6000
    onTriggered: root.note = ""
  }
}
