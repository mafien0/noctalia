import QtQuick
import Quickshell

// Region with the same four-state corner model used by Noctalia's shapes.
// Upstream Region supports inward rounded corners only, so inverted corners are
// emulated with an extension square minus the quarter-disc that bounds the
// outward arc. That reproduces the per-row coverage of the old fork Region API
// exactly, keeping masks and blur regions aligned with the drawn shape.
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

  // Top-left, horizontal inversion: sliver left of the corner
  Region {
    x: root.x - root.r
    y: root.y
    width: root.topLeftState === 1 ? root.r : 0
    height: root.topLeftState === 1 ? root.r : 0
    Region {
      shape: RegionShape.Ellipse
      x: root.x - 2 * root.r
      y: root.y
      width: 2 * root.r
      height: 2 * root.r
      intersection: Intersection.Subtract
    }
  }

  // Top-left, vertical inversion: sliver above the corner
  Region {
    x: root.x
    y: root.y - root.r
    width: root.topLeftState === 2 ? root.r : 0
    height: root.topLeftState === 2 ? root.r : 0
    Region {
      shape: RegionShape.Ellipse
      x: root.x
      y: root.y - 2 * root.r
      width: 2 * root.r
      height: 2 * root.r
      intersection: Intersection.Subtract
    }
  }

  // Top-right, horizontal inversion
  Region {
    x: root.x + root.width
    y: root.y
    width: root.topRightState === 1 ? root.r : 0
    height: root.topRightState === 1 ? root.r : 0
    Region {
      shape: RegionShape.Ellipse
      x: root.x + root.width
      y: root.y
      width: 2 * root.r
      height: 2 * root.r
      intersection: Intersection.Subtract
    }
  }

  // Top-right, vertical inversion
  Region {
    x: root.x + root.width - root.r
    y: root.y - root.r
    width: root.topRightState === 2 ? root.r : 0
    height: root.topRightState === 2 ? root.r : 0
    Region {
      shape: RegionShape.Ellipse
      x: root.x + root.width - 2 * root.r
      y: root.y - 2 * root.r
      width: 2 * root.r
      height: 2 * root.r
      intersection: Intersection.Subtract
    }
  }

  // Bottom-left, horizontal inversion
  Region {
    x: root.x - root.r
    y: root.y + root.height - root.r
    width: root.bottomLeftState === 1 ? root.r : 0
    height: root.bottomLeftState === 1 ? root.r : 0
    Region {
      shape: RegionShape.Ellipse
      x: root.x - 2 * root.r
      y: root.y + root.height - 2 * root.r
      width: 2 * root.r
      height: 2 * root.r
      intersection: Intersection.Subtract
    }
  }

  // Bottom-left, vertical inversion
  Region {
    x: root.x
    y: root.y + root.height
    width: root.bottomLeftState === 2 ? root.r : 0
    height: root.bottomLeftState === 2 ? root.r : 0
    Region {
      shape: RegionShape.Ellipse
      x: root.x
      y: root.y + root.height
      width: 2 * root.r
      height: 2 * root.r
      intersection: Intersection.Subtract
    }
  }

  // Bottom-right, horizontal inversion
  Region {
    x: root.x + root.width
    y: root.y + root.height - root.r
    width: root.bottomRightState === 1 ? root.r : 0
    height: root.bottomRightState === 1 ? root.r : 0
    Region {
      shape: RegionShape.Ellipse
      x: root.x + root.width
      y: root.y + root.height - 2 * root.r
      width: 2 * root.r
      height: 2 * root.r
      intersection: Intersection.Subtract
    }
  }

  // Bottom-right, vertical inversion
  Region {
    x: root.x + root.width - root.r
    y: root.y + root.height
    width: root.bottomRightState === 2 ? root.r : 0
    height: root.bottomRightState === 2 ? root.r : 0
    Region {
      shape: RegionShape.Ellipse
      x: root.x + root.width - 2 * root.r
      y: root.y + root.height
      width: 2 * root.r
      height: 2 * root.r
      intersection: Intersection.Subtract
    }
  }
}
