import QtQuick 1.1
import com.nokia.meego 1.0

PageStackWindow {
    id: appWindow
    showStatusBar: true
    initialPage: MainPage { }
    // black UI: on the AMOLED screen black pixels are switched off
    Component.onCompleted: theme.inverted = true
}
