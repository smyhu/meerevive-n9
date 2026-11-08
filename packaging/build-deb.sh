#!/bin/sh
# Builds meerevive-n9_<version>_armel.deb: app + root helper + engine + payload.
# Usage: sh packaging/build-deb.sh <public|private> [output-dir]
# Needs: dpkg-deb, ar, python3 (PIL), sha1sum, md5sum, gcc-arm-linux-gnueabihf.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
VARIANT=${1:?public or private}
OUT=${2:-$ROOT/dist/$VARIANT}
VERSION=$(sed -n 's/^APP_VERSION = .\(.*\).$/\1/p' "$ROOT/app/main.py")
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
D=$T/data/opt/meerevive-n9
sh "$ROOT/tools/build.sh" "$D" "$VARIANT" >/dev/null
mkdir -p "$D/bin" "$D/app/qml" "$T/data/usr/share/applications" "$T/data/usr/share/icons/hicolor/80x80/apps" "$T/ctl"
sh "$ROOT/helper/build.sh" "$D/bin/meerevive-root" >/dev/null
# one version number for the whole package: the engine carries the app's version
sed -i "s/^ENGINE_VERSION=.*/ENGINE_VERSION=$VERSION/" "$D/engine.sh"
(cd "$D" && find . -type f ! -name md5sums.txt ! -path './bin/*' ! -path './app/*' | sort | xargs md5sum > md5sums.txt)
cp "$ROOT/app/main.py" "$D/app/"; cp "$ROOT/app/qml/"* "$D/app/qml/"
cp "$ROOT/packaging/meerevive-n9.desktop" "$T/data/usr/share/applications/"
cp "$ROOT/art/meerevive-n9.png" "$T/data/usr/share/icons/hicolor/80x80/apps/"
chmod -R u+rwX,go+rX,go-w "$T/data"
chmod 755 "$D/bin/meerevive-root" "$D/app/main.py" "$D/engine.sh"
SIZE=$(du -sk "$T/data" | cut -f1)
python3 - "$ROOT/packaging/control" "$T/ctl/control" "$VERSION" "$SIZE" "$VARIANT" "$ROOT/art/meerevive-n9.png" <<'P'
import sys, base64, io
from PIL import Image
src, dst, version, size, variant, icon = sys.argv[1:]
buf = io.BytesIO(); Image.open(icon).resize((64, 64), Image.LANCZOS).save(buf, "PNG")
b = base64.b64encode(buf.getvalue()).decode("ascii")
lines = "\n".join(" " + b[i:i + 76] for i in range(0, len(b), 76))
t = open(src).read().replace("@VERSION@", version).replace("@SIZE@", size).replace("@VARIANT@", variant).replace("@ICON@", lines)
open(dst, "w").write(t)
P
(cd "$T/data" && find . -type f | sed 's#^\./##' | sort | xargs md5sum) > "$T/ctl/md5sums"
# digsigsums: without it aegis-dpkg ignores the <for path> request in _aegis
entry() { printf 'S 15 com.nokia.maemo H 40 %s R %d %s\n' "$1" "${#2}" "$2"; }
(cd "$T/data" && find . -type f | sed 's#^\./##' | sort | while read -r f; do
    entry "$(sha1sum "$f" | cut -d' ' -f1)" "$f"; done) > "$T/ctl/digsigsums"
cp "$ROOT/packaging/_aegis" "$T/_aegis"
chmod 644 "$T/ctl/"*
(cd "$T/ctl" && tar czf ../control.tar.gz --owner=0 --group=0 --numeric-owner --format=gnu ./control ./md5sums ./digsigsums)
(cd "$T/data" && tar czf ../data.tar.gz --owner=0 --group=0 --numeric-owner --format=gnu .)
echo 2.0 > "$T/debian-binary"
DEB="$OUT/meerevive-n9_${VERSION}-${VARIANT}_armel.deb"
rm -f "$DEB"
(cd "$T" && ar rc "$DEB" debian-binary control.tar.gz data.tar.gz _aegis)
ls -l "$DEB"; md5sum "$DEB"
