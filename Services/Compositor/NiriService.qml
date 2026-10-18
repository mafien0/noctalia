import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Keyboard

Item {
  id: root

  property int floatingWindowPosition: Number.MAX_SAFE_INTEGER

  property ListModel workspaces: ListModel {}
  property var windows: []
  property int focusedWindowIndex: -1

  property bool overviewActive: false

  property var keyboardLayouts: []

  signal workspaceChanged
  signal activeWindowChanged
  signal windowListChanged
  signal displayScalesChanged

  property var outputCache: ({})
  property var workspaceCache: ({})

  property var _rawWorkspaces: ({})
  property var _rawWindows: ({})
  property int _keyboardLayoutIndex: 0
  property bool _initialized: false

  function initialize() {
    if (_initialized)
      return;

    _initialized = true;
    eventStream.running = true;
    Logger.i("NiriService", "Service started");
  }

  Process {
    id: eventStream
    command: ["niri", "msg", "--json", "event-stream"]

    stdout: SplitParser {
      onRead: line => root.handleEvent(line)
    }

    stderr: SplitParser {
      onRead: line => {
                if (line.trim().length > 0)
                  Logger.w("NiriService", line);
              }
    }

    onExited: (code, status) => {
                if (!root._initialized)
                  return;
                Logger.w("NiriService", "Event stream exited with code", code);
                restartTimer.restart();
              }
  }

  Timer {
    id: restartTimer
    interval: 1000
    repeat: false
    onTriggered: {
      if (root._initialized)
        eventStream.running = true;
    }
  }

  Process {
    id: outputsQuery
    command: ["niri", "msg", "--json", "outputs"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.updateOutputs(JSON.parse(text));
        } catch (e) {
          Logger.e("NiriService", "Failed to parse outputs:", e);
        }
      }
    }
  }

  function handleEvent(line) {
    if (!line || line.trim().length === 0)
      return;

    var event;
    try {
      event = JSON.parse(line);
    } catch (e) {
      Logger.w("NiriService", "Invalid event:", line);
      return;
    }

    if (event.WorkspacesChanged) {
      setWorkspaces(event.WorkspacesChanged.workspaces || []);
    } else if (event.WindowsChanged) {
      setWindows(event.WindowsChanged.windows || []);
    } else if (event.WindowOpenedOrChanged) {
      upsertWindow(event.WindowOpenedOrChanged.window);
    } else if (event.WindowClosed) {
      removeWindow(event.WindowClosed.id);
    } else if (event.WindowFocusChanged) {
      setFocusedWindow(event.WindowFocusChanged.id);
    } else if (event.WindowLayoutsChanged) {
      updateLayouts(event.WindowLayoutsChanged.changes || []);
    } else if (event.WorkspaceActivated) {
      activateWorkspace(event.WorkspaceActivated.id, event.WorkspaceActivated.focused);
    } else if (event.WorkspaceActiveWindowChanged) {
      updateWorkspaceActiveWindow(event.WorkspaceActiveWindowChanged);
    } else if (event.OverviewOpenedOrClosed) {
      overviewActive = !!event.OverviewOpenedOrClosed.is_open;
    } else if (event.OutputsChanged) {
      outputsQuery.running = false;
      outputsQuery.running = true;
    } else if (event.ConfigLoaded) {
      outputsQuery.running = false;
      outputsQuery.running = true;
    } else if (event.KeyboardLayoutsChanged) {
      updateKeyboardLayouts(event.KeyboardLayoutsChanged.keyboard_layouts || {});
    } else if (event.KeyboardLayoutSwitched) {
      switchKeyboardLayout(event.KeyboardLayoutSwitched.idx);
    }
  }

  function setWorkspaces(rawWorkspaces) {
    _rawWorkspaces = {};
    var list = [];

    for (var i = 0; i < rawWorkspaces.length; i++) {
      var raw = rawWorkspaces[i];
      _rawWorkspaces[raw.id] = raw;
    }

    rebuildWorkspaces();
  }

  function rebuildWorkspaces() {
    var list = [];
    workspaceCache = {};

    for (var key in _rawWorkspaces) {
      var raw = _rawWorkspaces[key];
      var ws = {
        "id": raw.id,
        "idx": raw.idx,
        "name": raw.name || "",
        "output": raw.output || "",
        "isFocused": !!raw.is_focused,
        "isActive": !!raw.is_active,
        "isUrgent": !!raw.is_urgent,
        "isOccupied": raw.active_window_id !== null && raw.active_window_id !== undefined
      };
      workspaceCache[raw.id] = ws;
      list.push(ws);
    }

    list.sort((a, b) => {
                if (a.output !== b.output)
                  return a.output < b.output ? -1 : 1;
                return a.idx - b.idx;
              });

    workspaces.clear();
    for (var i = 0; i < list.length; i++) {
      workspaces.append(list[i]);
    }

    workspaceChanged();
  }

  function setWindows(rawWindows) {
    _rawWindows = {};
    for (var i = 0; i < rawWindows.length; i++) {
      _rawWindows[rawWindows[i].id] = rawWindows[i];
    }
    rebuildWindows();
  }

  function upsertWindow(raw) {
    if (!raw || raw.id === undefined)
      return;
    if (raw.is_focused) {
      for (var key in _rawWindows) {
        if (Number(key) !== Number(raw.id))
          _rawWindows[key].is_focused = false;
      }
    }
    _rawWindows[raw.id] = raw;
    rebuildWindows();
  }

  function removeWindow(id) {
    delete _rawWindows[id];
    rebuildWindows();
  }

  function setFocusedWindow(id) {
    for (var key in _rawWindows) {
      _rawWindows[key].is_focused = (Number(key) === Number(id));
    }
    rebuildWindows();
  }

  function updateLayouts(changes) {
    for (var i = 0; i < changes.length; i++) {
      var change = changes[i];
      if (!change || change.length < 2)
        continue;
      var raw = _rawWindows[change[0]];
      if (raw)
        raw.layout = change[1];
    }
    rebuildWindows();
  }

  function activateWorkspace(id, focused) {
    var target = _rawWorkspaces[id];
    if (!target)
      return;

    var output = target.output;
    for (var key in _rawWorkspaces) {
      var ws = _rawWorkspaces[key];
      if (ws.output === output && ws.id !== id)
        ws.is_active = false;
      if (focused && ws.id !== id)
        ws.is_focused = false;
    }
    target.is_active = true;
    if (focused)
      target.is_focused = true;

    rebuildWorkspaces();
  }

  function updateWorkspaceActiveWindow(data) {
    var ws = _rawWorkspaces[data.workspace_id];
    if (!ws)
      return;
    ws.active_window_id = data.active_window_id;
    rebuildWorkspaces();
  }

  function updateKeyboardLayouts(layouts) {
    keyboardLayouts = layouts.names || [];
    _keyboardLayoutIndex = layouts.current_idx || 0;
    applyKeyboardLayout();
  }

  function switchKeyboardLayout(idx) {
    _keyboardLayoutIndex = idx;
    applyKeyboardLayout();
  }

  function applyKeyboardLayout() {
    if (keyboardLayouts.length === 0)
      return;
    var name = keyboardLayouts[_keyboardLayoutIndex];
    if (name) {
      KeyboardLayoutService.setCurrentLayout(name);
      Logger.d("NiriService", "Keyboard layout:", name);
    }
  }

  function updateOutputs(outputs) {
    outputCache = {};

    for (var name in outputs) {
      var output = outputs[name];
      var logical = output.logical || {};
      var physical = output.physical_size || [];
      var modes = output.modes || [];
      var modeIdx = output.current_mode;
      var refreshRate = 0;

      if (modeIdx !== null && modeIdx !== undefined && modes[modeIdx])
        refreshRate = modes[modeIdx].refresh_rate || 0;

      outputCache[name] = {
        "name": output.name || name,
        "connected": Object.keys(logical).length > 0 && modeIdx !== null && modeIdx !== undefined,
        "scale": logical.scale || 1,
        "width": logical.width || 0,
        "height": logical.height || 0,
        "x": logical.x || 0,
        "y": logical.y || 0,
        "physical_width": physical[0] || 0,
        "physical_height": physical[1] || 0,
        "refresh_rate": refreshRate,
        "vrr_supported": !!output.vrr_supported,
        "vrr_enabled": !!output.vrr_enabled,
        "transform": logical.transform || "Normal"
      };
    }

    queryDisplayScales();
  }

  function getWindowOutput(win) {
    var ws = workspaceCache[win.workspace_id];
    return ws ? ws.output : "";
  }

  function toSortedWindowList(windowList) {
    return windowList.map(win => {
                            var ws = workspaceCache[win.workspaceId];
                            var output = (ws && ws.output) ? outputCache[ws.output] : null;

                            return {
                              window: win,
                              workspaceIdx: ws ? ws.idx : 0,
                              outputX: output ? output.x : 0,
                              outputY: output ? output.y : 0
                            };
                          }).sort((a, b) => {
                                    if (a.outputX !== b.outputX)
                                      return a.outputX - b.outputX;
                                    if (a.outputY !== b.outputY)
                                      return a.outputY - b.outputY;
                                    if (a.workspaceIdx !== b.workspaceIdx)
                                      return a.workspaceIdx - b.workspaceIdx;
                                    if (a.window.position.x !== b.window.position.x)
                                      return a.window.position.x - b.window.position.x;
                                    if (a.window.position.y !== b.window.position.y)
                                      return a.window.position.y - b.window.position.y;
                                    return a.window.id - b.window.id;
                                  }).map(info => info.window);
  }

  function rebuildWindows() {
    var list = [];

    for (var key in _rawWindows) {
      var raw = _rawWindows[key];
      var layout = raw.layout || {};
      var pos = layout.pos_in_scrolling_layout;
      var isFloating = !Array.isArray(pos);
      var x = isFloating ? floatingWindowPosition : pos[0];
      var y = isFloating ? floatingWindowPosition : pos[1];

      list.push({
                  "id": raw.id,
                  "title": raw.title || "",
                  "appId": raw.app_id || "",
                  "workspaceId": raw.workspace_id === undefined ? -1 : raw.workspace_id,
                  "isFocused": !!raw.is_focused,
                  "output": getWindowOutput(raw),
                  "position": {
                    "x": x,
                    "y": y
                  }
                });
    }

    windows = toSortedWindowList(list);
    updateFocusedWindow();
    windowListChanged();
    activeWindowChanged();
  }

  function updateFocusedWindow() {
    focusedWindowIndex = -1;
    for (var i = 0; i < windows.length; i++) {
      if (windows[i].isFocused) {
        focusedWindowIndex = i;
        break;
      }
    }
  }

  function queryDisplayScales() {
    if (CompositorService && CompositorService.onDisplayScalesUpdated) {
      CompositorService.onDisplayScalesUpdated(outputCache);
    }
    displayScalesChanged();
  }

  function dispatch(args) {
    try {
      Quickshell.execDetached(["niri", "msg", "action"].concat(args));
    } catch (e) {
      Logger.e("NiriService", "Failed to dispatch:", args, e);
    }
  }

  function switchToWorkspace(workspace) {
    dispatch(["focus-workspace", workspace.idx.toString()]);
  }

  function scrollWorkspaceContent(direction) {
    dispatch([direction < 0 ? "focus-column-left" : "focus-column-right"]);
  }

  function focusWindow(window) {
    dispatch(["focus-window", "--id", window.id.toString()]);
  }

  function closeWindow(window) {
    dispatch(["close-window", "--id", window.id.toString()]);
  }

  function turnOffMonitors() {
    dispatch(["power-off-monitors"]);
  }

  function turnOnMonitors() {
    dispatch(["power-on-monitors"]);
  }

  function logout() {
    dispatch(["quit", "--skip-confirmation"]);
  }

  function cycleKeyboardLayout() {
    dispatch(["switch-layout", "next"]);
  }

  function getFocusedScreen() {
    return null;
  }

  function spawn(command) {
    dispatch(["spawn", "--"].concat(command));
  }
}
