import QtQuick
import Quickshell
import Quickshell.Io

// Runs bin/phonesync watch for as long as the widget is on the bar. The
// helper does the syncing itself and prints one JSON line per change, which
// lands in the properties below. Actions are one shot helper calls.
Item {
  id: root

  readonly property string helper: decodeURIComponent(Qt.resolvedUrl("bin/phonesync").toString().replace(/^file:\/\//, ""))

  // "missing", "stopped" or "ok"; "" until the helper first answers.
  property string kdeconnect: ""
  property string computerName: ""
  property string theme: ""
  property var devices: []
  property string note: ""
  property string lastError: ""

  readonly property var paired: devices.filter(function(d) { return d.paired })
  readonly property var connected: devices.filter(function(d) { return d.paired && d.reachable && d.launcher })
  readonly property var asking: devices.filter(function(d) { return d.asks })
  readonly property bool ready: kdeconnect === "ok"

  function handle(line) {
    var o
    try { o = JSON.parse(line) } catch (e) { return }
    if (o.type === "state") {
      kdeconnect = String(o.kdeconnect || "")
      computerName = String(o.name || "")
      theme = String(o.theme || "")
      devices = o.devices || []
    } else if (o.type === "synced") {
      note = o.direction === "in"
        ? "Took " + o.theme + " from " + o.device
        : "Sent " + o.theme + " to " + o.device
      noteTimer.restart()
    } else if (o.type === "error") {
      lastError = String(o.message || "")
    }
  }

  function run(args) {
    if (action.running) return
    action.command = ["python3", helper].concat(args)
    action.running = true
  }

  function pair(id) { run(["pair", id]) }
  function accept(id) { run(["accept", id]) }
  function reject(id) { run(["reject", id]) }
  function unpair(id) { run(["unpair", id]) }
  function push() { run(["push"]); note = "Sending " + theme; noteTimer.restart() }
  function refresh() { run(["refresh"]) }
  function setup() {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "python3 '" + helper + "' setup"])
  }

  Process {
    id: watcher
    command: ["python3", root.helper, "watch"]
    running: true
    stdout: SplitParser { onRead: function(line) { root.handle(line) } }
    // The helper only stops when the shell does; if it falls over, start it again.
    onExited: restart.start()
  }

  Timer {
    id: restart
    interval: 5000
    onTriggered: watcher.running = true
  }

  Process {
    id: action
    command: []
    onExited: function(code) { if (code !== 0) root.lastError = "KDE Connect did not take that. Is the phone still on the same wifi?" }
  }

  Timer {
    id: noteTimer
    interval: 6000
    onTriggered: root.note = ""
  }
}
