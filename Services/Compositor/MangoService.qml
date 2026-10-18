import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Keyboard

Item {
  id: root

  // ===== PUBLIC INTERFACE (CompositorService compatibility) =====

  property ListModel workspaces: ListModel {}
  property var windows: []
  property int focusedWindowIndex: -1
  property bool initialized: false

  signal workspaceChanged
  signal activeWindowChanged
  signal windowListChanged
  signal displayScalesChanged

  // ===== MANGOSERVICE-SPECIFIC PROPERTIES =====

  property string selectedMonitor: ""
  property string currentLayoutSymbol: ""

  // ===== INTERNAL STATE =====

  QtObject {
    id: internal

    property var monitors: ({})
    property var tags: ({})
    property var clients: ({})
    property bool monitorsReady: false
    property bool clientsReady: false

    property var outputIndices: ({})
    property int outputCounter: 0

    property string lastWindowSignature: ""
    property bool warned: false

    function outputIndex(name) {
      if (outputIndices[name] === undefined)
        outputIndices[name] = outputCounter++;
      return outputIndices[name];
    }

    function updateMonitors(payload) {
      const list = payload.monitors || [];
      monitors = {};
      for (let i = 0; i < list.length; i++) {
        const monitor = list[i];
        monitors[monitor.name] = monitor;
        outputIndex(monitor.name);
        if (monitor.active) {
          root.selectedMonitor = monitor.name;
          root.currentLayoutSymbol = monitor.layout_symbol || "";
        }
      }
      monitorsReady = true;
      rebuildWorkspaces();
      updateWindows();
      queryDisplayScales();
    }

    function updateTags(payload) {
      const list = payload.all_tags || [];
      tags = {};
      for (let i = 0; i < list.length; i++) {
        const entry = list[i];
        tags[entry.monitor] = entry.tags || [];
        outputIndex(entry.monitor);
      }
      rebuildWorkspaces();
    }

    function updateClients(payload) {
      const list = payload.clients || [];
      clients = {};
      for (let i = 0; i < list.length; i++) {
        clients[list[i].id] = list[i];
      }
      clientsReady = true;
      updateWindows();
    }

    function rebuildWorkspaces() {
      if (!monitorsReady)
        return;

      const list = [];
      for (const name in monitors) {
        const monitor = monitors[name];
        const monitorTags = tags[name] || monitor.tags || [];
        const outputIdx = outputIndex(name);

        for (let i = 0; i < monitorTags.length; i++) {
          const tag = monitorTags[i];
          const tagId = tag.index;
          const isActive = !!tag.is_active;
          list.push({
                      id: outputIdx * 100 + tagId,
                      idx: tagId,
                      name: tagId.toString(),
                      output: name,
                      isActive: isActive,
                      isFocused: isActive && !!monitor.active,
                      isUrgent: !!tag.is_urgent,
                      isOccupied: (tag.client_count || 0) > 0
                    });
        }
      }

      list.sort((a, b) => a.id - b.id);

      root.workspaces.clear();
      for (let i = 0; i < list.length; i++)
        root.workspaces.append(list[i]);

      root.workspaceChanged();
    }

    function updateWindows() {
      if (!clientsReady)
        return;

      const list = [];
      let focusedIdx = -1;

      for (const key in clients) {
        const client = clients[key];
        const outputName = client.monitor || root.selectedMonitor || "";
        const monitor = internal.monitors[outputName];
        const activeTags = (monitor && monitor.active_tags) ? monitor.active_tags : [];
        let tagId = (client.tags && client.tags.length > 0) ? client.tags[0] : 1;

        if (client.tags) {
          for (let t = 0; t < client.tags.length; t++) {
            const candidate = client.tags[t];
            if (candidate !== 0 && activeTags.indexOf(candidate) !== -1) {
              tagId = candidate;
              break;
            }
          }
        }

        if (tagId === 0) {
          tagId = 1;
          for (let t = 0; t < activeTags.length; t++) {
            if (activeTags[t] !== 0) {
              tagId = activeTags[t];
              break;
            }
          }
        }

        const outputIdx = outputIndex(outputName);
        const workspaceId = outputIdx * 100 + tagId;

        list.push({
                    id: client.id,
                    title: client.title || "",
                    appId: client.appid || "",
                    class: client.appid || "",
                    workspaceId: workspaceId,
                    isFocused: !!client.is_focused,
                    output: outputName,
                    fullscreen: !!client.is_fullscreen,
                    floating: !!client.is_floating,
                    position: {
                      x: client.x || 0,
                      y: client.y || 0
                    }
                  });
      }

      list.sort((a, b) => {
                  if (a.workspaceId !== b.workspaceId)
                    return a.workspaceId - b.workspaceId;
                  if (a.position.y !== b.position.y)
                    return a.position.y - b.position.y;
                  if (a.position.x !== b.position.x)
                    return a.position.x - b.position.x;
                  return a.id - b.id;
                });

      for (let i = 0; i < list.length; i++) {
        if (list[i].isFocused) {
          focusedIdx = i;
          break;
        }
      }

      const signature = JSON.stringify(list.map(w => [w.id, w.workspaceId, w.isFocused, w.title, w.appId]));
      if (signature !== internal.lastWindowSignature) {
        internal.lastWindowSignature = signature;
        root.windows = list;
        root.windowListChanged();
      }

      if (focusedIdx !== root.focusedWindowIndex) {
        root.focusedWindowIndex = focusedIdx;
        root.activeWindowChanged();
      }
    }

    function queryDisplayScales() {
      const scalesMap = {};
      for (const name in monitors) {
        const monitor = monitors[name];
        scalesMap[name] = {
          name: name,
          scale: monitor.scale || 1,
          width: monitor.width || 0,
          height: monitor.height || 0,
          x: monitor.x || 0,
          y: monitor.y || 0
        };
      }

      if (CompositorService && CompositorService.onDisplayScalesUpdated)
        CompositorService.onDisplayScalesUpdated(scalesMap);

      root.displayScalesChanged();
    }
  }

  // ===== WATCH PROCESSES =====

  Process {
    id: monitorsWatch
    command: ["mmsg", "watch", "all-monitors"]
    stdout: SplitParser {
      onRead: line => root.parseLine(line, internal.updateMonitors)
    }
    stderr: SplitParser {
      onRead: line => root.logError(line)
    }
    onExited: (code, status) => root.watchExited("monitors", code)
  }

  Process {
    id: tagsWatch
    command: ["mmsg", "watch", "all-tags"]
    stdout: SplitParser {
      onRead: line => root.parseLine(line, internal.updateTags)
    }
    stderr: SplitParser {
      onRead: line => root.logError(line)
    }
    onExited: (code, status) => root.watchExited("tags", code)
  }

  Process {
    id: clientsWatch
    command: ["mmsg", "watch", "all-clients"]
    stdout: SplitParser {
      onRead: line => root.parseLine(line, internal.updateClients)
    }
    stderr: SplitParser {
      onRead: line => root.logError(line)
    }
    onExited: (code, status) => root.watchExited("clients", code)
  }

  Process {
    id: keyboardWatch
    command: ["mmsg", "watch", "keyboardlayout"]
    stdout: SplitParser {
      onRead: line => {
                try {
                  const data = JSON.parse(line);
                  if (data.layout && KeyboardLayoutService)
                    KeyboardLayoutService.setCurrentLayout(data.layout);
                } catch (e) {
                  // Ignore malformed events.
                }
              }
    }
    stderr: SplitParser {
      onRead: line => root.logError(line)
    }
    onExited: (code, status) => root.watchExited("keyboard", code)
  }

  Timer {
    id: restartTimer
    interval: 3000
    repeat: false
    onTriggered: {
      if (root.initialized)
        root.startWatchers();
    }
  }

  function parseLine(line, handler) {
    if (!line || line.trim().length === 0)
      return;
    try {
      handler(JSON.parse(line));
    } catch (e) {
      Logger.w("MangoService", "Invalid JSON from mmsg:", line);
    }
  }

  function logError(line) {
    if (!internal.warned && line.trim().length > 0) {
      internal.warned = true;
      Logger.w("MangoService", line);
    }
  }

  function watchExited(name, code) {
    if (!initialized)
      return;
    Logger.w("MangoService", "mmsg " + name + " watch exited with code", code);
    restartTimer.restart();
  }

  function startWatchers() {
    monitorsWatch.running = true;
    tagsWatch.running = true;
    clientsWatch.running = true;
    keyboardWatch.running = true;
  }

  // ===== PUBLIC FUNCTIONS =====

  function initialize() {
    if (initialized)
      return;

    Logger.i("MangoService", "Initializing MangoWC integration (mmsg IPC)");
    initialized = true;
    startWatchers();
  }

  function queryDisplayScales() {
    internal.queryDisplayScales();
  }

  function switchToWorkspace(workspace) {
    const tagId = workspace.idx || 1;
    const outputName = workspace.output || root.selectedMonitor;
    if (outputName)
      Quickshell.execDetached(["mmsg", "dispatch", "viewcrossmon," + tagId + "," + outputName]);
    else
      Quickshell.execDetached(["mmsg", "dispatch", "view," + tagId]);
  }

  function focusWindow(window) {
    if (window && window.id !== undefined)
      Quickshell.execDetached(["mmsg", "dispatch", "focusid", "client," + window.id]);
  }

  function closeWindow(window) {
    if (window && window.id !== undefined)
      Quickshell.execDetached(["mmsg", "dispatch", "killclient", "client," + window.id]);
    else
      Quickshell.execDetached(["mmsg", "dispatch", "killclient"]);
  }

  function turnOffMonitors() {
    const screens = Quickshell.screens;
    const commands = [];
    for (let i = 0; i < screens.length; i++)
      commands.push("mmsg dispatch disable_monitor," + screens[i].name);
    if (commands.length > 0)
      Quickshell.execDetached(["sh", "-c", commands.join(" && ")]);
  }

  function turnOnMonitors() {
    const screens = Quickshell.screens;
    const commands = [];
    for (let i = 0; i < screens.length; i++)
      commands.push("mmsg dispatch enable_monitor," + screens[i].name);
    if (commands.length > 0)
      Quickshell.execDetached(["sh", "-c", commands.join(" && ")]);
  }

  function logout() {
    Quickshell.execDetached(["mmsg", "dispatch", "quit"]);
  }

  function cycleKeyboardLayout() {
    Logger.w("MangoService", "Keyboard layout cycling not supported");
  }

  function getFocusedScreen() {
    return null;
  }

  function spawn(command) {
    Quickshell.execDetached(["mmsg", "dispatch", "spawn_shell," + command.join(" ")]);
  }
}
