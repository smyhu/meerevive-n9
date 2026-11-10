#!/usr/bin/python
# -*- coding: utf-8 -*-
# MeeRevive - installs patches and apps that bring the Nokia N9 back to life.
# Python 2.6 + PySide + QML. The work is done by the MeeRevive engine
# (/opt/meerevive-n9/engine.sh), run as root through the small helper
# /opt/meerevive-n9/bin/meerevive-root (it accepts only engine commands).
# Designed and written by Claude (Anthropic) together with smyhu for Nokia N9. MIT licence.

import os
import sys
import json
import subprocess

from PySide.QtCore import QObject, QUrl, QProcess, QSettings, Signal, Slot
from PySide.QtGui import QApplication
from PySide.QtDeclarative import QDeclarativeView

APP_VERSION = '0.3.12'
BASE = '/opt/meerevive-n9'
APP_DIR = os.path.dirname(os.path.abspath(__file__))
HELPER = os.path.join(BASE, 'bin', 'meerevive-root')
STATE = '/var/lib/meerevive-n9'
BUS_NAME = 'com.github.smyhu.meerevive'
LANGUAGES = ('pl', 'en')


def read_file(path, default=''):
    try:
        f = open(path)
        try:
            return f.read().strip()
        finally:
            f.close()
    except IOError:
        return default


def session_env():
    if not os.environ.get('DBUS_SESSION_BUS_ADDRESS'):
        for line in read_file('/tmp/session_bus_address.user').splitlines():
            line = line.strip()
            if line.startswith('export '):
                line = line[7:]
            if line.startswith('DBUS_SESSION_BUS_ADDRESS='):
                os.environ['DBUS_SESSION_BUS_ADDRESS'] = line.split('=', 1)[1].strip("'\"")


def phone_language():
    """Phone language from gconf; MEEREVIVE_LANG=en overrides it."""
    code = os.environ.get('MEEREVIVE_LANG', '')
    if not code:
        session_env()
        try:
            p = subprocess.Popen(['gconftool-2', '-g', '/meegotouch/i18n/language'],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            code = p.communicate()[0].strip()
        except OSError:
            pass
    code = (code or os.environ.get('LANG', ''))[:2].lower()
    return code if code in LANGUAGES else 'en'


class Engine(QObject):
    """Runs one engine command at a time through the root helper and
    passes its output to QML line by line."""

    # PySide 1.0.7 signal arguments cannot be read in QML: the signals only
    # say "something new", QML then fetches it with takeLines()/takeList().
    line = Signal()
    finished = Signal()
    busyChanged = Signal()
    listReady = Signal()

    def __init__(self):
        QObject.__init__(self)
        self.proc = None
        self.buf = ''
        self.listing = False
        self.listOut = []
        self.lines = []
        self.listJson = u''
        self.code = 0

    def _start(self, args, listing):
        if self.proc is not None:
            return False
        self.listing = listing
        self.listOut = []
        self.buf = ''
        proc = QProcess(self)
        proc.setProcessChannelMode(QProcess.MergedChannels)
        proc.readyReadStandardOutput.connect(self._read)
        proc.finished.connect(self._done)
        proc.error.connect(self._error)
        self.proc = proc
        self.busyChanged.emit()
        print 'meerevive: run', ' '.join(args)
        proc.start(HELPER, args)
        return True

    def _emit_line(self, text):
        text = text.decode('utf-8', 'replace')
        if self.listing:
            self.listOut.append(text)
        else:
            self.lines.append(text)
            self.line.emit()

    def _read(self):
        if self.proc is None:
            return
        self.buf += str(self.proc.readAllStandardOutput())
        while '\n' in self.buf:
            one, self.buf = self.buf.split('\n', 1)
            self._emit_line(one.rstrip('\r'))

    def _finish(self, code):
        self._read()
        if self.buf:
            self._emit_line(self.buf)
            self.buf = ''
        proc, self.proc = self.proc, None
        if proc is not None:
            proc.deleteLater()
        self.busyChanged.emit()
        if self.listing:
            items = []
            for l in self.listOut:
                f = l.split('|')
                if len(f) >= 6:
                    items.append({'id': f[0], 'state': f[1], 'current': f[2], 'version': f[3],
                                  'requires': f[4], 'title': '|'.join(f[5:])})
            self.listJson = unicode(json.dumps({'ok': code == 0 and len(items) > 0, 'items': items,
                                                'error': u'\n'.join(self.listOut[-5:])}))
            self.listReady.emit()
        else:
            self.code = code
            self.finished.emit()

    def _done(self, code, status=None):
        if self.proc is None:
            return
        if self.proc.exitStatus() != QProcess.NormalExit:
            code = -1
        self._finish(code)

    def _error(self, err):
        if self.proc is None:
            return
        if self.proc.state() == QProcess.NotRunning:
            if not self.listing:
                self.lines.append(u'ERROR: cannot start ' + HELPER)
                self.line.emit()
            self._finish(-2)


    @Slot(result=unicode)
    def takeLines(self):
        out, self.lines = self.lines, []
        return u'\n'.join(out)

    @Slot(result=unicode)
    def takeList(self):
        return self.listJson

    @Slot(result=int)
    def exitCode(self):
        return self.code

    @Slot(result=bool)
    def isBusy(self):
        return self.proc is not None

    @Slot(result=bool)
    def refresh(self):
        return self._start(['list'], True)

    @Slot(unicode, result=bool)
    def run(self, command):
        """command: e.g. 'install tls waluty', 'backup', 'reboot'."""
        return self._start([str(a) for a in command.split()], False)

    @Slot(result=bool)
    def fullLog(self):
        return QSettings('meerevive', 'meerevive').value('fullLog', 'false') in ('true', True)

    @Slot(bool)
    def setFullLog(self, on):
        QSettings('meerevive', 'meerevive').setValue('fullLog', 'true' if on else 'false')

    @Slot(result=bool)
    def tlsLeftovers(self):
        return os.path.exists(os.path.join(STATE, 'tls-ww-leftovers'))

    @Slot(result=unicode)
    def variant(self):
        return unicode(read_file(os.path.join(BASE, 'VARIANT'), '?'))

    @Slot(result=unicode)
    def engineVersion(self):
        for l in read_file(os.path.join(BASE, 'engine.sh')).splitlines():
            if l.startswith('ENGINE_VERSION='):
                return unicode(l.split('=', 1)[1])
        return u'?'


class Window(object):
    """Only one copy of the app; a second start brings the first to the front."""

    def __init__(self):
        self.view = None
        self.bus = None
        try:
            import dbus
            import dbus.service
            from dbus.mainloop.glib import DBusGMainLoop
        except ImportError, e:
            print 'meerevive: no D-Bus:', e
            return
        DBusGMainLoop(set_as_default=True)
        session_env()
        bus = dbus.SessionBus()
        if bus.request_name(BUS_NAME, dbus.bus.NAME_FLAG_DO_NOT_QUEUE) != dbus.bus.REQUEST_NAME_REPLY_PRIMARY_OWNER:
            self.bus = bus
            return
        owner = self

        class Service(dbus.service.Object):
            @dbus.service.method(BUS_NAME, in_signature='', out_signature='')
            def top(self):
                owner.top()

        self.service = Service(bus, '/')

    def running_elsewhere(self):
        if not self.bus:
            return False
        try:
            self.bus.get_object(BUS_NAME, '/').top(dbus_interface=BUS_NAME)
        except Exception, e:
            print 'meerevive: cannot reach the running copy:', e
        return True

    def top(self):
        if self.view:
            self.view.showFullScreen()
            self.view.raise_()
            self.view.activateWindow()


def main():
    os.environ.setdefault('DISPLAY', ':0')
    app = QApplication(sys.argv)
    app.setApplicationName('meerevive')
    app.setOrganizationName('meerevive')

    window = Window()
    if window.running_elsewhere():
        return

    view = QDeclarativeView()
    engine = Engine()
    ctx = view.rootContext()
    ctx.setContextProperty('uiLang', phone_language())
    ctx.setContextProperty('appVersion', APP_VERSION)
    ctx.setContextProperty('engine', engine)
    ctx.setContextProperty('iconDir', QUrl.fromLocalFile(os.path.join(BASE, 'icons')).toString())
    view.setResizeMode(QDeclarativeView.SizeRootObjectToView)
    view.setSource(QUrl.fromLocalFile(os.path.join(APP_DIR, 'qml', 'main.qml')))
    view.showFullScreen()
    window.view = view
    sys.exit(app.exec_())


if __name__ == '__main__':
    main()
