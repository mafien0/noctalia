pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Singleton {
  id: root

  // Register a component that needs audio data, call this when a visualizer becomes active.
  // Pass a unique identifier (e.g., "lockscreen", "controlcenter:screen1", "plugin:fancy-audiovisualizer")
  function registerComponent(componentId) {
    root._registeredComponents[componentId] = true;
    root._registeredComponents = Object.assign({}, root._registeredComponents);
    Logger.d("Spectrum", "Component registered:", componentId, "- total:", root._registeredCount);
    root.syncProcess();
  }

  // Unregister a component when it no longer needs audio data.
  function unregisterComponent(componentId) {
    delete root._registeredComponents[componentId];
    root._registeredComponents = Object.assign({}, root._registeredComponents);
    Logger.d("Spectrum", "Component unregistered:", componentId, "- total:", root._registeredCount);
    root.syncProcess();
  }

  // Check if a component is registered
  function isRegistered(componentId) {
    return root._registeredComponents[componentId] === true;
  }

  // Component registration - any component needing audio data registers here
  property var _registeredComponents: ({})
  readonly property int _registeredCount: Object.keys(_registeredComponents).length
  property bool _shouldRun: _registeredCount > 0

  property var values: []
  property bool isIdle: true
  property bool available: false
  property bool _missingNoticeShown: false

  readonly property int bandCount: Settings.data.audio.spectrumMirrored ? 32 : 64
  readonly property int frameRate: Settings.data.audio.spectrumFrameRate || 30

  readonly property string cavaConfig: {
    return [
      "[general]",
      "framerate = " + frameRate,
      "bars = " + bandCount,
      "lower_cutoff_freq = 50",
      "higher_cutoff_freq = 12000",
      "sleep_timer = 0",
      "[input]",
      "method = pipewire",
      "source = auto",
      "[output]",
      "method = raw",
      "raw_target = /dev/stdout",
      "data_format = ascii",
      "ascii_max_range = 100",
      "bar_delimiter = 59",
      "frame_delimiter = 10",
      "channels = mono",
      ""
    ].join("\n");
  }

  Component.onCompleted: cavaCheck.running = true

  on_ShouldRunChanged: syncProcess()
  onAvailableChanged: syncProcess()

  Process {
    id: cavaCheck
    command: ["sh", "-c", "command -v cava"]

    onExited: (code, status) => {
                root.available = code === 0;
                if (root.available) {
                  root.syncProcess();
                } else {
                  root.markMissing();
                }
              }
  }

  Connections {
    target: Settings.data.audio
    function onSpectrumMirroredChanged() {
      root.restartProcess();
    }
    function onSpectrumFrameRateChanged() {
      root.restartProcess();
    }
  }

  Process {
    id: cava
    command: ["sh", "-c", "printf '%s' \"$CAVA_CONFIG\" | cava -p /dev/stdin"]
    environment: ({
                    "CAVA_CONFIG": root.cavaConfig
                  })

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => root.handleFrame(line)
    }

    stderr: SplitParser {
      onRead: line => root.handleCavaStderr(line)
    }

    onExited: (code, status) => {
                if (code === 127) {
                  root.markMissing();
                  return;
                }
                if (root._shouldRun && root.available)
                  restartTimer.restart();
              }
  }

  Timer {
    id: restartTimer
    interval: 1000
    repeat: false
    onTriggered: {
      if (root._shouldRun && root.available)
        cava.running = true;
    }
  }

  function syncProcess() {
    if (_shouldRun && available) {
      if (!cava.running)
        cava.running = true;
    } else {
      restartTimer.stop();
      if (cava.running)
        cava.running = false;
      values = [];
      isIdle = true;
    }
  }

  function restartProcess() {
    restartTimer.stop();
    if (cava.running)
      cava.running = false;
    if (_shouldRun && available)
      restartTimer.restart();
  }

  function handleCavaStderr(line) {
    if (!line || line.trim().length === 0 || !available)
      return;

    Logger.w("Spectrum", line);

    if (line.indexOf("cava: command not found") !== -1 || line.indexOf("cava: not found") !== -1)
      markMissing();
  }

  function markMissing() {
    available = false;
    restartTimer.stop();
    if (cava.running)
      cava.running = false;
    values = [];
    isIdle = true;

    if (_missingNoticeShown)
      return;

    _missingNoticeShown = true;
    Logger.e("Spectrum", "cava not found - audio visualizers disabled");
    Qt.callLater(() => ToastService.showError(I18n.tr("common.visualizer"), I18n.tr("toast.cava-not-found")));
  }

  function handleFrame(line) {
    if (!line || line.length === 0)
      return;

    const parts = line.trim().split(";");
    const parsed = [];
    let peak = 0;

    for (let i = 0; i < parts.length; i++) {
      const raw = parts[i].trim();
      if (raw.length === 0)
        continue;
      const value = parseFloat(raw);
      const normalized = isFinite(value) ? Math.max(0, Math.min(1, value / 100)) : 0;
      parsed.push(normalized);
      if (normalized > peak)
        peak = normalized;
    }

    if (parsed.length === 0)
      return;

    values = parsed;
    isIdle = peak < 0.005;
  }
}
