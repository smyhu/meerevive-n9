import QtQuick 1.1
import com.nokia.meego 1.0
import "strings.js" as S

// Runs one engine command and shows its output as it comes.
Page {
    id: page

    property string command: ""
    property string heading: ""
    property string item: ""
    property bool started: false
    property bool running: false
    property bool rebootWanted: false
    property int code: 0
    property bool full: engine.fullLog()
    property variant lines: []   // every line; "> " = full output of a command

    function tr(k) { return S.t(uiLang, k) }

    function shown(l) { return page.full || l.indexOf("> ") != 0; }

    function add(text) {
        if (text == "") return;
        var all = page.lines;
        var add = [];
        var parts = text.split("\n");
        for (var i = 0; i < parts.length; i++) {
            var l = parts[i];
            all.push(l);
            if (l.indexOf("*** Reboot needed") == 0) page.rebootWanted = true;
            if (shown(l)) add.push(l.indexOf("> ") == 0 ? "   " + l.substring(2) : l);
        }
        page.lines = all;
        if (add.length > 0) out.text = out.text == "" ? add.join("\n") : out.text + "\n" + add.join("\n");
        toEnd();
    }

    function toEnd() {
        if (flick.contentHeight > flick.height) flick.contentY = flick.contentHeight - flick.height;
    }

    function rebuild() {
        var shownLines = [];
        for (var i = 0; i < page.lines.length; i++) {
            var l = page.lines[i];
            if (shown(l)) shownLines.push(l.indexOf("> ") == 0 ? "   " + l.substring(2) : l);
        }
        out.text = shownLines.join("\n");
        toEnd();
    }

    onStatusChanged: {
        if (status == PageStatus.Active && !started) {
            started = true;
            running = engine.run(command);
            if (!running) add("ERROR: busy");
        }
    }

    Connections {
        target: engine
        onLine: page.add(engine.takeLines())
        onFinished: {
            page.add(engine.takeLines());
            page.code = engine.exitCode();
            page.running = false;
            if (page.rebootWanted && page.code == 0) rebootDialog.open();
        }
    }

    // radial gradient, prepared in RGB565 with dithering (as in AuthMee/Lyrion)
    Image { source: "background.png"; y: -36; smooth: false }

    Header {
        id: header
        text: page.heading
        subText: page.item
    }

    Text {
        id: statusLine
        anchors { top: header.bottom; left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 64; topMargin: 10 }
        text: page.running ? tr("working") : (page.code == 0 ? tr("doneOk") : S.a(uiLang, "doneErr", page.code))
        color: page.running ? "#8C8C8C" : (page.code == 0 ? "#6EC44F" : "#FF5A4F")
        font.family: "Nokia Pure Text"
        font.pixelSize: 20
        elide: Text.ElideRight
    }

    Flickable {
        id: flick
        anchors { top: statusLine.bottom; left: parent.left; right: parent.right; bottom: parent.bottom
                  leftMargin: 16; rightMargin: 16; topMargin: 10 }
        contentHeight: out.paintedHeight + 16
        clip: true
        Text {
            id: out
            width: flick.width
            wrapMode: Text.WrapAnywhere
            color: "#E6E6E6"
            font.family: "Nokia Pure Text"
            font.pixelSize: 18
            textFormat: Text.PlainText
        }
    }
    ScrollDecorator { flickableItem: flick }

    BusyIndicator {
        anchors { right: parent.right; rightMargin: 16; verticalCenter: statusLine.verticalCenter }
        platformStyle: BusyIndicatorStyle { size: "small" }
        running: page.running
        visible: page.running
    }

    QueryDialog {
        id: rebootDialog
        titleText: tr("reboot")
        message: tr("rebootNeeded")
        acceptButtonText: tr("yes")
        rejectButtonText: tr("no")
        onAccepted: {
            page.heading = tr("reboot");
            page.item = "";
            page.rebootWanted = false;
            out.text = "";
            page.lines = [];
            page.running = engine.run("reboot");
        }
    }

    tools: ToolBarLayout {
        ToolIcon {
            platformIconId: "toolbar-back"
            enabled: !page.running
            onClicked: pageStack.pop()
        }
        ToolButton {
            text: tr("logFull")
            checkable: true
            checked: page.full
            onClicked: {
                page.full = checked;
                engine.setFullLog(page.full);
                page.rebuild();
            }
        }
    }
}
