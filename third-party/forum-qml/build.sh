#!/bin/bash
# cross-build forum-qml for N9 against SDK sysroot
set -e
SP=/tmp/claude-0/-home-user/caecf1ed-5a0b-54be-8a1f-01ebf140f044/scratchpad
S=$SP/b/sysroot; SRC=$SP/tmo/src; OUT=$SP/b/obj; mkdir -p $OUT
# n9-g++ wrapper expects sysroot at ../sysroot relative to its bin dir
mkdir -p $SP/b/bin; cp /mnt/project-files/n9-tls/bin/n9-g++ $SP/b/bin/; chmod +x $SP/b/bin/n9-g++
CXX=$SP/b/bin/n9-g++
MOC="qemu-arm-static -L $S $S/usr/bin/native-moc"
Q=$S/usr/include/qt4
INC="-I$S/usr/share/qt4/mkspecs/linux-g++-maemo -I$Q -I$Q/QtCore -I$Q/QtGui -I$Q/QtNetwork -I$Q/QtDeclarative -I$Q/QtWebKit -I$Q/QtXml -I$SRC/src -I$SRC/qmlapplicationviewer -I$S/usr/include/accounts-qt -I$S/usr/include/AccountSetup -I$S/usr/include/signon-qt -I$S/usr/include/signon-qt/SignOn -I$S/usr/include/gq -I$S/usr/include/applauncherd -I$S/usr/include/AccountSetup/.. -I$S/usr/include/glib-2.0 -I$S/usr/lib/glib-2.0/include -I$S/usr/include/gconf/2"
DEF="-DQT_NO_DEBUG -DQT_WEBKIT_LIB -DQT_DECLARATIVE_LIB -DQT_NETWORK_LIB -DQT_GUI_LIB -DQT_CORE_LIB -DQT_SHARED -DHARMATTAN_BOOSTER -DMEEGO_EDITION_HARMATTAN -D_REENTRANT -DMEEGO_VERSION_MAJOR=1 -DMEEGO_VERSION_MINOR=2 -DMEEGO_VERSION_PATCH=0"
FLAGS="-O2 -fPIC -fvisibility=hidden -fvisibility-inlines-hidden"
cd $SRC
OBJS=""
for h in src/*.h qmlapplicationviewer/*.h; do
  if grep -q Q_OBJECT $h; then b=$(basename $h .h); $MOC $DEF $INC $h -o $OUT/moc_$b.cpp; fi
done
for c in src/*.cpp qmlapplicationviewer/*.cpp $OUT/moc_*.cpp; do
  o=$OUT/$(basename $c .cpp).o
  $CXX -c $FLAGS $DEF $INC $c -o $o
  OBJS="$OBJS $o"
done
$CXX -pie -rdynamic -o $OUT/forum-qml $OBJS -Wl,--allow-shlib-undefined \
  -lmdeclarativecache -lQtWebKit -lQtDeclarative -lQtNetwork -lQtGui -lQtCore -laccounts-qt -lAccountSetup -lsignon-qt -lgq-gconf -lgconf-2 -lglib-2.0 -lpthread
arm-linux-gnueabihf-strip $OUT/forum-qml
file $OUT/forum-qml
