import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Widgets

NCollapsible {
  id: root

  // Public API
  property var tags: []  // Array of tag strings
  property string selectedTag: ""
  property alias label: root.label
  property alias description: root.description
  property alias expanded: root.expanded

  // Formatting function for tag display (optional override)
  property var formatTag: function (tag) {
    if (tag === "")
      return I18n.tr("launcher.categories.all");
    // Default: capitalize first letter
    return tag.charAt(0).toUpperCase() + tag.slice(1);
  }

  Layout.fillWidth: true
  contentSpacing: Style.marginXS

  Flow {
    Layout.fillWidth: true
    spacing: Style.marginXS
    flow: Flow.LeftToRight

    Repeater {
      model: [""].concat(root.tags)

      delegate: NButton {
        text: root.formatTag(modelData)
        backgroundColor: root.selectedTag === modelData ? Commons.Color.mPrimary : Commons.Color.mSurfaceVariant
        textColor: root.selectedTag === modelData ? Commons.Color.mOnPrimary : Commons.Color.mOnSurfaceVariant
        onClicked: root.selectedTag = modelData
        fontSize: Style.fontSizeS
        iconSize: Style.fontSizeS
        fontWeight: Style.fontWeightSemiBold
        buttonRadius: Style.iRadiusM
      }
    }
  }
}
