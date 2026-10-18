pragma Singleton

import QtQuick
import Quickshell

Singleton {
  readonly property string baseVersion: "4.7.8"
  readonly property bool isDevelopment: true
  readonly property string developmentSuffix: "-git"
  readonly property string currentVersion: "v" + baseVersion + (isDevelopment ? developmentSuffix : "")
}
