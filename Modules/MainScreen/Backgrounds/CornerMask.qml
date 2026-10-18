import QtQuick
import Quickshell

// Region with the same four-state corner model used by Noctalia's shapes.
// Upstream Region supports inward rounded corners only, so inverted corners
// are approximated with a square extension. This keeps masks and blur regions
// covering the bar's outward corner pixels.
Region {
  id: root

  property int cornerRadius: 0
  property int topLeftState: -1
  property int topRightState: -1
  property int bottomLeftState: -1
  property int bottomRightState: -1

  readonly property int r: Math.max(0, Math.min(cornerRadius, Math.floor(Math.min(width, height) / 2)))

  topLeftRadius: topLeftState === 0 ? r : 0
  topRightRadius: topRightState === 0 ? r : 0
  bottomLeftRadius: bottomLeftState === 0 ? r : 0
  bottomRightRadius: bottomRightState === 0 ? r : 0

  Region {
    x: root.x - root.r
    y: root.y
    width: root.topLeftState === 1 ? root.r : 0
    height: root.topLeftState === 1 ? root.r : 0
  }

  Region {
    x: root.x
    y: root.y - root.r
    width: root.topLeftState === 2 ? root.r : 0
    height: root.topLeftState === 2 ? root.r : 0
  }

  Region {
    x: root.x + root.width
    y: root.y
    width: root.topRightState === 1 ? root.r : 0
    height: root.topRightState === 1 ? root.r : 0
  }

  Region {
    x: root.x + root.width - root.r
    y: root.y - root.r
    width: root.topRightState === 2 ? root.r : 0
    height: root.topRightState === 2 ? root.r : 0
  }

  Region {
    x: root.x - root.r
    y: root.y + root.height - root.r
    width: root.bottomLeftState === 1 ? root.r : 0
    height: root.bottomLeftState === 1 ? root.r : 0
  }

  Region {
    x: root.x
    y: root.y + root.height
    width: root.bottomLeftState === 2 ? root.r : 0
    height: root.bottomLeftState === 2 ? root.r : 0
  }

  Region {
    x: root.x + root.width
    y: root.y + root.height - root.r
    width: root.bottomRightState === 1 ? root.r : 0
    height: root.bottomRightState === 1 ? root.r : 0
  }

  Region {
    x: root.x + root.width - root.r
    y: root.y + root.height
    width: root.bottomRightState === 2 ? root.r : 0
    height: root.bottomRightState === 2 ? root.r : 0
  }
}
