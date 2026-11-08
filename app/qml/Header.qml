import QtQuick 1.1

// View header as in the N9 UI guidelines: 72 px, light title, thin divider
Rectangle {
    property alias text: titleText.text
    property alias subText: subTitle.text

    width: parent.width
    height: 72
    color: "transparent"

    Text {
        id: titleText
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        elide: Text.ElideRight
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: subTitle.text == "" ? 0 : -10
        font.family: "Nokia Pure Text Light"
        font.pixelSize: 32
        color: "white"
    }

    Text {
        id: subTitle
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.top: titleText.bottom
        anchors.right: parent.right
        anchors.rightMargin: 16
        elide: Text.ElideRight
        font.family: "Nokia Pure Text"
        font.pixelSize: 18
        color: "#8C8C8C"
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: "#333333"
    }
}
