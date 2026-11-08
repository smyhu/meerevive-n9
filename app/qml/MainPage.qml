import QtQuick 1.1
import com.nokia.meego 1.0
import "strings.js" as S

Page {
    id: page

    property bool loading: false
    property bool failed: false
    property string failText: ""
    property int selCount: 0
    property int menuIndex: -1
    property bool needRefresh: true
    property bool leftovers: false

    function tr(k) { return S.t(uiLang, k) }

    function refresh() {
        if (engine.refresh()) { loading = true; failed = false }
    }

    function countSel() {
        var n = 0;
        for (var i = 0; i < comps.count; i++) if (comps.get(i).sel) n++;
        selCount = n;
    }

    function selectNeeded() {
        for (var i = 0; i < comps.count; i++) {
            var s = comps.get(i).st;
            comps.setProperty(i, "sel", s == "missing" || s == "outdated" || s == "store" || s == "partial");
        }
        countSel();
    }

    function selectNone() {
        for (var i = 0; i < comps.count; i++) comps.setProperty(i, "sel", false);
        countSel();
    }

    // runs an engine command on the log page
    function runCommand(cmd, heading, item) {
        needRefresh = !(cmd == "check" || cmd == "log" || cmd == "backup" || cmd == "reboot");
        pageStack.push(Qt.resolvedUrl("LogPage.qml"), { command: cmd, heading: heading, item: item ? item : "" });
    }

    function installSelected() {
        var ids = [];
        for (var i = 0; i < comps.count; i++) if (comps.get(i).sel) ids.push(comps.get(i).cid);
        if (ids.length == 0) return;
        runCommand("install " + ids.join(" "), tr("install"), S.a(uiLang, "itemsN", ids.length));
    }

    function stateColor(s) {
        if (s == "installed") return "#6EC44F";
        if (s == "missing") return "#8C8C8C";
        if (s == "n/a") return "#555555";
        return "#FF9A1F";
    }

    ListModel { id: comps }

    Connections {
        target: engine
        onListReady: {
            page.loading = false;
            var r = JSON.parse(engine.takeList());
            if (!r.ok) {
                if (comps.count == 0) { page.failed = true; page.failText = r.error; page.selCount = 0; }
                return;
            }
            // same components as before: update rows in place (keeps the scroll position)
            var same = comps.count == r.items.length;
            for (var k = 0; same && k < r.items.length; k++) same = comps.get(k).cid == r.items[k].id;
            for (var j = 0; j < r.items.length; j++) {
                var it = r.items[j];
                var row = { cid: it.id, st: it.state, cur: it.current, ver: it.version,
                            req: it.requires, label: S.title(uiLang, it.id, it.title) };
                if (same) {
                    var wasSel = comps.get(j).sel;
                    for (var key in row) comps.setProperty(j, key, row[key]);
                    comps.setProperty(j, "sel", wasSel && it.state != "installed" && it.state != "n/a");
                } else {
                    row.sel = false;
                    if (j == 0) comps.clear();
                    comps.append(row);
                }
            }
            page.leftovers = engine.tlsLeftovers();
            page.countSel();
        }
    }

    onStatusChanged: {
        if (status == PageStatus.Active && needRefresh) { needRefresh = false; refresh(); }
    }

    // radial gradient, prepared in RGB565 with dithering (as in AuthMee/Lyrion)
    Image { source: "background.png"; y: -36; smooth: false }

    Header {
        id: header
        text: tr("title")
        subText: S.t(uiLang, "subtitle").replace("%1", appVersion)
                 .replace("%2", tr(engine.variant()))
    }

    BusyIndicator {
        anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 20 }
        running: page.loading && comps.count > 0
        visible: running
        platformStyle: BusyIndicatorStyle { size: "small" }
    }

    ListView {
        id: list
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        model: comps
        visible: comps.count > 0
        delegate: Item {
            id: row
            width: list.width
            height: Math.max(96, texts.height + 28)
            property bool usable: model.st != "n/a"

            Rectangle {
                anchors.fill: parent
                color: "#1A1A1A"
                visible: mouse.pressed
            }
            CheckBox {
                id: box
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                checked: model.sel
                enabled: row.usable
                onClicked: { comps.setProperty(index, "sel", checked); page.countSel(); }
            }
            Image {
                id: icon
                anchors { left: box.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                width: 64; height: 64
                sourceSize.width: 64; sourceSize.height: 64
                smooth: true
                source: iconDir + "/" + model.cid + ".png"
                opacity: row.usable ? 1.0 : 0.4
            }
            Column {
                id: texts
                anchors { left: icon.right; leftMargin: 14; right: parent.right; rightMargin: 12
                          verticalCenter: parent.verticalCenter }
                spacing: 2
                Text {
                    width: parent.width
                    text: model.label
                    color: row.usable ? "white" : "#666666"
                    font.family: "Nokia Pure Text"
                    font.pixelSize: 24
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: S.t(uiLang, "st_" + model.st) +
                          (model.cur != "" && model.ver != "" && model.cur != model.ver && model.st != "missing" ?
                           "  ·  " + (model.cur == "old" ? S.t(uiLang, "oldVersion") : model.cur) + " → " + model.ver : "") +
                          (model.req != "" && model.st == "missing" ? "  ·  " + S.a(uiLang, "needs", model.req) : "")
                    color: page.stateColor(model.st)
                    font.family: "Nokia Pure Text"
                    font.pixelSize: 18
                    elide: Text.ElideRight
                }
            }
            MouseArea {
                id: mouse
                anchors { left: box.right; right: parent.right; top: parent.top; bottom: parent.bottom }
                onClicked: {
                    if (!row.usable) return;
                    comps.setProperty(index, "sel", !model.sel);
                    page.countSel();
                }
                onPressAndHold: {
                    if (!row.usable) return;
                    page.menuIndex = index;
                    rowMenu.open();
                }
            }
        }
    }
    ScrollDecorator { flickableItem: list }

    Column {
        anchors.centerIn: parent
        spacing: 24
        visible: page.loading && comps.count == 0
        BusyIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            running: page.loading
            platformStyle: BusyIndicatorStyle { size: "large" }
        }
        Label { anchors.horizontalCenter: parent.horizontalCenter; text: tr("loading") }
    }

    Column {
        anchors { left: parent.left; right: parent.right; margins: 24; verticalCenter: parent.verticalCenter }
        spacing: 24
        visible: page.failed && !page.loading && comps.count == 0
        Label { width: parent.width; text: tr("listError"); font.pixelSize: 28; wrapMode: Text.WordWrap }
        Label { width: parent.width; text: page.failText; color: "#8C8C8C"; font.pixelSize: 18; wrapMode: Text.WrapAnywhere }
        Button { anchors.horizontalCenter: parent.horizontalCenter; text: tr("retry"); onClicked: page.refresh() }
    }

    ContextMenu {
        id: rowMenu
        MenuLayout {
            MenuItem {
                text: tr("install")
                visible: page.menuIndex >= 0 && page.menuIndex < comps.count && comps.get(page.menuIndex).st != "installed"
                onClicked: {
                    var c = comps.get(page.menuIndex);
                    page.runCommand("install " + c.cid, tr("install"), c.label);
                }
            }
            MenuItem {
                text: tr("remove")
                visible: page.menuIndex >= 0 && page.menuIndex < comps.count && comps.get(page.menuIndex).st != "missing"
                onClicked: removeDialog.open()
            }
        }
    }

    QueryDialog {
        id: removeDialog
        titleText: tr("remove")
        message: (page.menuIndex >= 0 && page.menuIndex < comps.count) ? S.a(uiLang, "removeAsk", comps.get(page.menuIndex).label) : ""
        acceptButtonText: tr("remove")
        rejectButtonText: tr("cancel")
        onAccepted: {
            var c = comps.get(page.menuIndex);
            page.runCommand("remove " + c.cid, tr("remove"), c.label);
        }
    }

    QueryDialog {
        id: backupDialog
        titleText: tr("backup")
        message: tr("backupHint")
        acceptButtonText: tr("backup")
        rejectButtonText: tr("cancel")
        onAccepted: page.runCommand("backup", tr("backup"))
    }

    QueryDialog {
        id: rebootDialog
        titleText: tr("reboot")
        message: tr("rebootAsk")
        acceptButtonText: tr("yes")
        rejectButtonText: tr("no")
        onAccepted: page.runCommand("reboot", tr("reboot"))
    }

    QueryDialog {
        id: aboutDialog
        icon: "file:///usr/share/icons/hicolor/80x80/apps/meerevive-n9.png"
        titleText: "MeeRevive " + appVersion
        message: tr("aboutText") + "<br><br>" + tr("credit") +
                 "<br><br>MIT · <a href=\"https://github.com/smyhu/meerevive-n9\" style=\"color:#4DA6FF; text-decoration:underline\">github.com/smyhu/meerevive-n9</a>"
        acceptButtonText: tr("close")
        onLinkActivated: Qt.openUrlExternally(link)
    }

    Menu {
        id: mainMenu
        MenuLayout {
            MenuItem {
                text: page.selCount > 0 ? tr("selectNone") : tr("selectNeeded")
                onClicked: page.selCount > 0 ? page.selectNone() : page.selectNeeded()
            }
            MenuItem { text: tr("tlsFinish"); visible: page.leftovers; onClicked: page.runCommand("tls-finish", tr("tlsFinish")) }
            MenuItem { text: tr("backup"); onClicked: backupDialog.open() }
            MenuItem { text: tr("restore"); onClicked: page.runCommand("restore", tr("restore")) }
            MenuItem { text: tr("check"); onClicked: page.runCommand("check", tr("check")) }
            MenuItem { text: tr("log"); onClicked: page.runCommand("log", tr("log")) }
            MenuItem { text: tr("reboot"); onClicked: rebootDialog.open() }
            MenuItem { text: tr("about"); onClicked: aboutDialog.open() }
        }
    }

    tools: ToolBarLayout {
        ToolIcon {
            platformIconId: "toolbar-refresh"
            enabled: !page.loading
            onClicked: page.refresh()
        }
        ToolButton {
            text: page.selCount > 0 ? S.a(uiLang, "installN", page.selCount) : tr("install")
            enabled: page.selCount > 0 && !page.loading
            onClicked: page.installSelected()
        }
        ToolIcon {
            platformIconId: "toolbar-view-menu"
            onClicked: (mainMenu.status == DialogStatus.Closed) ? mainMenu.open() : mainMenu.close()
        }
    }
}
