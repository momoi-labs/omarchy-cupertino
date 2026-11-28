import QtQuick
import QtQuick.Shapes

Rectangle {
  id: icon

  property string kind: ""
  property real size: 22

  readonly property var shapes: ({
    appearance: { color: "#1d1d1f", stroke: "M8 3 A5 5 0 1 1 8 13 A5 5 0 1 1 8 3", fill: "M8 3 A5 5 0 0 1 8 13 Z" },
    wallpaper: { color: "#30a8c8", stroke: "M3.5 3.5 H12.5 Q14 3.5 14 5 V11 Q14 12.5 12.5 12.5 H3.5 Q2 12.5 2 11 V5 Q2 3.5 3.5 3.5 Z M2.4 11.4 L6 7.8 L9 10.8 L10.6 9.2 L13.6 12.2", fill: "M10.6 5 A1.3 1.3 0 1 1 10.6 7.6 A1.3 1.3 0 1 1 10.6 5" },
    titlebars: { color: "#1d1d1f", stroke: "M4 3.5 H12 Q14 3.5 14 5.5 V10.5 Q14 12.5 12 12.5 H4 Q2 12.5 2 10.5 V5.5 Q2 3.5 4 3.5 Z M2 6.5 H14", fill: "M4.6 4.3 A0.75 0.75 0 1 1 4.6 5.8 A0.75 0.75 0 1 1 4.6 4.3 M6.8 4.3 A0.75 0.75 0 1 1 6.8 5.8 A0.75 0.75 0 1 1 6.8 4.3" },
    menubar: { color: "#8e8e93", stroke: "M4 3.5 H12 Q14 3.5 14 5.5 V10.5 Q14 12.5 12 12.5 H4 Q2 12.5 2 10.5 V5.5 Q2 3.5 4 3.5 Z", fill: "M3.2 3.5 H12.8 Q14 3.5 14 4.7 V6.3 H2 V4.7 Q2 3.5 3.2 3.5 Z" },
    dock: { color: "#8e8e93", stroke: "M4 3.5 H12 Q14 3.5 14 5.5 V10.5 Q14 12.5 12 12.5 H4 Q2 12.5 2 10.5 V5.5 Q2 3.5 4 3.5 Z", fill: "M4.6 9.3 H11.4 Q12.4 9.3 12.4 10.3 Q12.4 11.3 11.4 11.3 H4.6 Q3.6 11.3 3.6 10.3 Q3.6 9.3 4.6 9.3 Z" },
    controlcenter: { color: "#8e8e93", stroke: "M5 3.4 H11 Q13.6 3.4 13.6 5.4 Q13.6 7.4 11 7.4 H5 Q2.4 7.4 2.4 5.4 Q2.4 3.4 5 3.4 Z M5 8.8 H11 Q13.6 8.8 13.6 10.8 Q13.6 12.8 11 12.8 H5 Q2.4 12.8 2.4 10.8 Q2.4 8.8 5 8.8 Z", fill: "M10.9 4.3 A1.1 1.1 0 1 1 10.9 6.5 A1.1 1.1 0 1 1 10.9 4.3 M5.1 9.7 A1.1 1.1 0 1 1 5.1 11.9 A1.1 1.1 0 1 1 5.1 9.7" },
    switcher: { color: "#8e8e93", stroke: "M4.6 4.6 H11.4 Q14.2 4.6 14.2 8 Q14.2 11.4 11.4 11.4 H4.6 Q1.8 11.4 1.8 8 Q1.8 4.6 4.6 4.6 Z", fill: "M4.2 7 H6 V9 H4.2 Z M7.1 7 H8.9 V9 H7.1 Z M10 7 H11.8 V9 H10 Z" },
    keyboard: { color: "#8e8e93", stroke: "M3.8 4 H12.2 Q14.2 4 14.2 6 V10 Q14.2 12 12.2 12 H3.8 Q1.8 12 1.8 10 V6 Q1.8 4 3.8 4 Z M4.5 6.8 H4.6 M7 6.8 H7.1 M9.5 6.8 H9.6 M11.8 6.8 H11.9 M5 9.6 H11", fill: "" },
    search: { color: "#8e8e93", stroke: "M7 3 A4 4 0 1 1 7 11 A4 4 0 1 1 7 3 M9.9 9.9 L13 13", fill: "" },
    aresta: { color: "#0a7aff", stroke: "M6.6 3 H9.4 Q13 3 13 6.6 V9.4 Q13 13 9.4 13 H6.6 Q3 13 3 9.4 V6.6 Q3 3 6.6 3 Z M6 8 H10 M8 6 V10", fill: "" }
  })
  readonly property var shape: shapes[kind] || shapes.aresta

  width: size
  height: size
  radius: size * 0.27
  color: shape.color
  border.width: 1
  border.color: Qt.rgba(1, 1, 1, 0.1)

  Shape {
    anchors.centerIn: parent
    width: 16
    height: 16
    scale: icon.size / 22
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: "#ffffff"
      strokeWidth: 1.4
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: icon.shape.stroke }
    }

    ShapePath {
      strokeColor: "transparent"
      fillColor: "#ffffff"
      PathSvg { path: icon.shape.fill || "M0 0" }
    }
  }
}
