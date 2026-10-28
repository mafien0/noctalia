import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons

import qs.Commons as Commons
Rectangle {
  property bool vertical: false

  width: vertical ? Style.borderS : parent.width
  height: vertical ? parent.height : Style.borderS
  gradient: Gradient {
    orientation: vertical ? Gradient.Vertical : Gradient.Horizontal
    GradientStop {
      position: 0.0
      color: "transparent"
    }
    GradientStop {
      position: 0.1
      color: Commons.Color.mOutline
    }
    GradientStop {
      position: 0.9
      color: Commons.Color.mOutline
    }
    GradientStop {
      position: 1.0
      color: "transparent"
    }
  }
}
