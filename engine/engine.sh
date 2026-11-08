#!/bin/sh
# MeeRevive engine - installs and removes patches and apps on Nokia N9 (Harmattan PR1.3).
# Designed and written by Claude (Anthropic) together with smyhu for Nokia N9.
# License: MIT. Runs under busybox ash as root.
#
# Usage (as root):
#   sh engine.sh list                 show all components and their state
#   sh engine.sh check                verify payload checksums and phone prerequisites
#   sh engine.sh install <id>...      install components (or: install all)
#   sh engine.sh remove <id>...       remove components
#   sh engine.sh tls-finish           after reboot: remove leftovers of the old WunderWungiel patch
#   sh engine.sh backup               save data for moving to another phone (MyDocs/MeeRevive)
#   sh engine.sh restore              restore that data on the new phone
#   sh engine.sh reboot               restart the phone
#   sh engine.sh log                  show the last 60 log lines

ENGINE_VERSION=0.3.1
BASE=$(cd "$(dirname "$0")" && pwd)
PAY=$BASE/payload
LIST=$BASE/components.list
STATE=/var/lib/meerevive-n9
LOG=/var/log/meerevive-n9.log
OUT=$STATE/last-output.txt
MIGRATE=/home/user/MyDocs/MeeRevive

QTNET=/usr/lib/libQtNetwork.so.4.7.4
QTNET_OWN=ce41893f751f121cb2d567cb148eb94a       # our patch (github.com/smyhu/n9-tls)
QTNET_WW=7b22e8779a30606a5833c7741a0284f0        # old WunderWungiel patch
QTNET_ORIGINAL=7123b565acfcdc987eade607c308ee69  # Nokia PR1.3
SSL_OWN=/usr/lib/libssl.so.1.0.2
# the three Nokia packages our patch replaces (same versions, rebuilt against OpenSSL 1.0.2u)
TLS_BASE="libqt4-network=4.7.4~git20120327-0maemo1+0m8 libcurl3=7.21.0-1maemo4+0m6 aegis-certman-common-ca=1.0.8+0m8"
FONTDIR=/usr/share/fonts/truetype/symbola
MEECAST=/opt/com.meecast.omweather
MEECAST_QML=$MEECAST/share/omweather/qml
USERDEFAULTS=/home/user/.local/share/applications/defaults.list
OURS='smyhu|n9@localhost'   # maintainers of our own packages

# ---------- helpers ----------
say() { echo "$*"; echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> $LOG 2>/dev/null; }
fail() { say "ERROR: $*"; return 1; }

# run a command, keep its output in the log and in $OUT
# In the app (MEEREVIVE_APP=1) the full output also goes to stdout, live, as
# lines starting with "> "; the app shows them in its "full" log view.
run() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') \$ $*" >> $LOG
    if [ -n "$MEEREVIVE_APP" ]; then
        echo "> \$ $*"
        { "$@" 2>&1; echo $? > $OUT.rc; } | tee $OUT | while IFS= read -r l || [ -n "$l" ]; do echo "> $l"; done
        rc=$(cat $OUT.rc 2>/dev/null); rm -f $OUT.rc
        [ -n "$rc" ] || rc=1
    else
        "$@" > $OUT 2>&1
        rc=$?
    fi
    cat $OUT >> $LOG
    return $rc
}

# aegis-dpkg; waits while the package database is locked (updater right after boot)
adpkg() {
    n=0
    while :; do
        run aegis-dpkg "$@" && return 0
        rc=$?
        grep -q -i -E 'lock|zablokowan' $OUT || return $rc
        n=$((n+1))
        [ $n -gt 8 ] && { say "package database still locked after 2 minutes"; return $rc; }
        say "package database is busy (updater?) - waiting 15 s ($n/8)"
        sleep ${MR_WAIT:-15}
    done
}

pkgver() {   # installed version of a package, empty if not installed
    s=$(dpkg-query -W -f='${Status}|${Version}' "$1" 2>/dev/null)
    case "$s" in
        "install ok installed|"*) echo "${s#*|}" ;;
        *) echo "" ;;
    esac
}

pkgmaint() { dpkg-query -W -f='${Maintainer}' "$1" 2>/dev/null; }

# installed packages that depend on $1
rdeps() {
    dpkg-query -W -f='${Package}|${Status}|${Depends}\n' 2>/dev/null |
        grep '|install ok installed|' |
        awk -F'|' -v p="$1" '{ n=split($3,d,","); for(i=1;i<=n;i++){ x=d[i]; sub(/^ +/,"",x); sub(/[ (].*/,"",x); if(x==p){print $1; break} } }'
}

md5of() { [ -f "$1" ] && md5sum "$1" | cut -d' ' -f1; }

field() { echo "$1" | cut -d'|' -f"$2"; }

comp_line() { grep "^$1|" $LIST | head -1; }

need_root() {
    [ "$(id -u)" = "0" ] || { echo "Run as root (devel-su)."; exit 1; }
    mkdir -p $STATE/backup
}

free_kb() { df -k "$1" | tail -1 | awk '{print $(NF-2)}'; }

as_user() { run devel-su user -c "$1"; }

# ---------- status ----------
tls_state() {   # own | ww | original | other
    case "$(md5of $QTNET)" in
        $QTNET_OWN) echo own ;;
        $QTNET_WW) echo ww ;;
        $QTNET_ORIGINAL) echo original ;;
        *) echo other ;;
    esac
}

status_of() {   # prints: installed | outdated | store | missing | partial | n/a
    line=$(comp_line "$1")
    kind=$(field "$line" 2); pkg=$(field "$line" 3); ver=$(field "$line" 4); flags=$(field "$line" 10)
    case "$kind" in
        deb)
            cur=$(pkgver "$pkg")
            if [ -z "$cur" ]; then echo missing
            elif [ "$cur" = "$ver" ]; then echo installed
            elif [ "$flags" = replace ] && ! pkgmaint "$pkg" | grep -q -E "$OURS"; then echo store
            elif dpkg --compare-versions "$cur" gt "$ver"; then echo installed
            else echo outdated; fi ;;
        tls)
            case "$(tls_state)" in
                own) if [ -f $SSL_OWN ] && [ -n "$(pkgver openssl-n9)" ]; then echo installed; else echo partial; fi ;;
                ww) echo outdated ;;
                original) if [ -n "$(pkgver openssl-n9)" ]; then echo partial; else echo missing; fi ;;
                *) echo partial ;;
            esac ;;
        font)
            if ls $FONTDIR/*.ttf >/dev/null 2>&1; then echo installed; else echo missing; fi ;;
        meecast)
            if [ ! -d $MEECAST ]; then echo n/a
            elif [ ! -f $MEECAST/lib/openmeteocom ]; then echo missing
            elif [ "$(md5of $MEECAST/lib/openmeteocom)" = "$(md5of $PAY/meecast/openmeteocom)" ]; then echo installed
            else echo outdated; fi ;;
        tool)
            if [ ! -f "$pkg" ]; then echo missing
            elif [ "$(md5of $pkg)" = "$(md5of $PAY/tools/$(field "$line" 5))" ]; then echo installed
            else echo outdated; fi ;;
        aptfix)
            if cat /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null | grep -q -E '^[^#]*(thecust|harmattan-dev\.nokia\.com)'
            then echo missing; else echo installed; fi ;;
        browser)
            if [ -f $USERDEFAULTS ] && grep -q operamobile $USERDEFAULTS; then echo missing; else echo installed; fi ;;
        *) echo "?" ;;
    esac
}

script_ver() { sed -n 's/^# SCRIPT_VERSION=\([0-9.]*\).*/\1/p' "$1" 2>/dev/null | head -1; }

cmd_list() {
    grep -v '^#' $LIST | grep '|' | while IFS= read -r line; do
        id=$(field "$line" 1); kind=$(field "$line" 2); pkg=$(field "$line" 3)
        ver=$(field "$line" 4); req=$(field "$line" 6); title=$(field "$line" 7)
        cur=""; [ "$kind" = deb ] && cur=$(pkgver "$pkg")
        if [ "$kind" = tool ]; then   # scripts carry "# SCRIPT_VERSION=n"
            ver=$(script_ver "$PAY/tools/$(field "$line" 5)")
            [ -f "$pkg" ] && { cur=$(script_ver "$pkg"); [ -n "$cur" ] || cur=old; }
        fi
        echo "$id|$(status_of $id)|$cur|$ver|$req|$title"
    done
}

# ---------- checks ----------
cmd_check() {
    ok=0
    say "MeeRevive engine $ENGINE_VERSION ($(cat $BASE/VARIANT 2>/dev/null) build) - check"
    if (cd $BASE && md5sum -c md5sums.txt > $OUT 2>&1); then
        say "payload checksums: OK ($(wc -l < $BASE/md5sums.txt) files)"
    else
        grep -v ': OK$' $OUT; fail "payload checksums do not match - copy the folder again"; ok=1
    fi
    if [ -x /usr/bin/aegis-dpkg ]; then say "aegis-dpkg: present"
    else fail "aegis-dpkg missing (Aegis-install hack from QTweak needed)"; ok=1; fi
    say "free space: / $(free_kb /) kB, /opt $(free_kb /opt/.) kB"
    case "$(tls_state)" in
        own) say "TLS: our patch (n9-tls)" ;;
        ww) say "TLS: old WunderWungiel patch - 'install tls' replaces it with ours" ;;
        original) say "TLS: original Nokia libraries" ;;
        *) say "TLS: unknown QtNetwork $(md5of $QTNET)" ;;
    esac
    [ "$(tls_state)" != ww ] && [ -n "$(pkgver openssl-local)$(pkgver wunderw-perl-opt)" ] &&
        say "TLS: leftovers of the old patch (openssl-local, perl) - run: sh engine.sh tls-finish"
    return $ok
}

tls_base_ok() {
    bad=""
    for pv in $TLS_BASE; do
        p=${pv%%=*}; v=${pv#*=}
        [ "$(pkgver $p)" = "$v" ] || bad="$bad $p($(pkgver $p))"
    done
    [ -z "$bad" ] && return 0
    fail "system packages differ from PR1.3:$bad"
    return 1
}

deps_ok() {   # $1 = space separated package names
    miss=""
    for d in $1; do [ -n "$(pkgver $d)" ] || miss="$miss $d"; done
    [ -z "$miss" ] && return 0
    fail "missing system packages:$miss (install them first: apt-get install$miss)"
    return 1
}

# deb file in the payload for a package name (debs/ or extras/), empty if none
payload_deb() {
    for f in $PAY/debs/${1}_*.deb $PAY/extras/${1}_*.deb; do [ -f "$f" ] && { echo "$f"; return; }; done
}

# ---------- deb components ----------
install_deb() {
    line=$(comp_line "$1")
    pkg=$(field "$line" 3); ver=$(field "$line" 4); file=$(field "$line" 5)
    deps=$(field "$line" 8); preremove=$(field "$line" 9); flags=$(field "$line" 10)
    cur=$(pkgver "$pkg")
    st=$(status_of $1)
    [ "$cur" = "$ver" ] && { say "$1: already installed ($ver)"; return 0; }
    if [ "$st" = installed ]; then say "$1: newer version installed ($cur), skipped"; return 0; fi
    deps_ok "$deps" || return 1
    say "$1: installing $pkg $ver (was: ${cur:-none})"
    if [ "$st" = store ] || ! adpkg -i $PAY/debs/$file; then
        if [ "$st" = store ] || grep -qi "trusted" $OUT; then
            # package came from the Ovi Store / OpenRepos: remove it first (user data stays).
            # Packages that depend on it must go too; put back afterwards those we carry.
            back=""
            for p in $pkg $preremove; do
                [ -n "$(pkgver $p)" ] || continue
                for r in $(rdeps $p); do
                    [ "$r" = "$pkg" ] && continue
                    say "$1: removing $r (depends on $p)"
                    adpkg -r $r && back="$back $r"
                done
                say "$1: removing store version of $p"
                adpkg -r $p || { cat $OUT; fail "$1: cannot remove $p"; return 1; }
            done
            adpkg -i $PAY/debs/$file || { cat $OUT; fail "$1: install failed"; return 1; }
            for r in $back; do
                f=$(payload_deb $r)
                if [ -n "$f" ]; then adpkg -i $f && say "$1: $r installed again" || say "$1: WARNING - $r could not be installed again"
                else say "$1: WARNING - $r was removed; install it again from the store"; fi
            done
        else
            cat $OUT; fail "$1: install failed"; return 1
        fi
    fi
    [ "$(pkgver $pkg)" = "$ver" ] || { fail "$1: package state wrong after install"; return 1; }
    say "$1: OK"
}

remove_deb() {
    pkg=$(field "$(comp_line $1)" 3)
    [ -z "$(pkgver $pkg)" ] && { say "$1: not installed"; return 0; }
    say "$1: removing $pkg"
    adpkg -r $pkg || { cat $OUT; fail "$1: remove failed"; return 1; }
    say "$1: removed"
}

# ---------- TLS 1.2 patch (github.com/smyhu/n9-tls) ----------
ww_rollback() {   # old WunderWungiel patch -> original Nokia libraries (verified on #3, 07.11.2026)
    say "tls: removing the old WunderWungiel patch - restoring 13 original Nokia packages"
    adpkg -i $PAY/tls/original/*.deb || { cat $OUT; fail "tls: restore of Nokia packages failed"; return 1; }
    if [ "$(cat $STATE/tls-had-agtools 2>/dev/null)" != yes ] && [ -n "$(pkgver libaccounts-glib-tools)" ]; then
        adpkg -r libaccounts-glib-tools
    fi
    [ "$(tls_state)" = original ] || { fail "tls: QtNetwork not original after restore"; return 1; }
    touch $STATE/tls-ww-leftovers
    say "tls: old patch removed"
}

install_tls() {
    st=$(status_of tls)
    [ "$st" = installed ] && { say "tls: already installed"; return 0; }
    [ -x /usr/bin/aegis-dpkg ] || { fail "tls: aegis-dpkg missing"; return 1; }
    [ "$(free_kb /)" -ge 10000 ] || { fail "tls: less than 10 MB free on /"; return 1; }
    if [ "$(tls_state)" = ww ]; then
        ww_rollback || return 1
    fi
    case "$(tls_state)" in
        original|own) ;;
        *) fail "tls: QtNetwork is neither original nor patched ($(md5of $QTNET)) - not touching it"; return 1 ;;
    esac
    tls_base_ok || return 1
    say "tls: installing OpenSSL 1.0.2u and 3 rebuilt Nokia libraries (QtNetwork, curl, certificates)"
    adpkg -i $PAY/tls/own/*.deb || { cat $OUT; fail "tls: install failed - run: sh engine.sh remove tls"; return 1; }
    if [ "$(tls_state)" != own ] || [ ! -f $SSL_OWN ]; then
        fail "tls: CHECKPOINT FAILED (QtNetwork $(md5of $QTNET)) - run: sh engine.sh remove tls"; return 1
    fi
    say "tls: checkpoint OK (QtNetwork patched, $SSL_OWN present)"
    touch $STATE/reboot-needed
    [ -f $STATE/tls-ww-leftovers ] && say "tls: after the reboot run: sh engine.sh tls-finish (removes the old patch's perl and openssl)"
    say "tls: OK - REBOOT the phone when the installation is finished"
}

remove_tls() {
    deps=$(grep -v '^#' $LIST | awk -F'|' '$6 ~ /tls/ {print $1"|"$3}' | while IFS='|' read -r i p; do [ -n "$(pkgver $p)" ] && echo -n "$i "; done)
    [ -n "$deps" ] && say "tls: WARNING - these apps need HTTPS and may stop working: $deps"
    case "$(tls_state)" in
        ww) ww_rollback || return 1 ;;
        own|other)
            say "tls: restoring the 3 original Nokia packages"
            files=""
            for pv in $TLS_BASE; do files="$files $(ls $PAY/tls/original/${pv%%=*}_*.deb)"; done
            adpkg -i $files || { cat $OUT; fail "tls: restore failed"; return 1; }
            [ "$(tls_state)" = original ] || { fail "tls: QtNetwork not original after restore"; return 1; } ;;
    esac
    if [ -n "$(pkgver openssl-n9)" ]; then
        adpkg -r openssl-n9 || { cat $OUT; fail "tls: removing openssl-n9 failed"; return 1; }
    fi
    say "tls: removed - REBOOT the phone"
    [ -f $STATE/tls-ww-leftovers ] && say "tls: after the reboot run: sh engine.sh tls-finish"
    return 0
}

cmd_tls_finish() {
    [ "$(tls_state)" = ww ] && { fail "tls-finish: the old WunderWungiel patch is still active - run install tls or remove tls first"; return 1; }
    say "tls: removing leftovers of the old patch (openssl-local, perl)"
    [ -n "$(pkgver openssl-local)" ] && adpkg -r openssl-local
    rm -rf /usr/local/ssl
    [ -n "$(pkgver wunderw-perl-opt)" ] && adpkg -r wunderw-perl-opt
    /sbin/ldconfig
    rm -f $STATE/tls-ww-leftovers $STATE/tls-had-agtools $STATE/tls-rollback-pending
    say "tls: cleanup finished"
}

# ---------- emoji font ----------
install_font() {
    [ "$(status_of emoji-font)" = installed ] && { say "emoji-font: already installed"; return 0; }
    mkdir -p $FONTDIR && cp $PAY/fonts/Symbola_hint.ttf $FONTDIR/ && chmod 644 $FONTDIR/Symbola_hint.ttf || { fail "emoji-font: copy failed"; return 1; }
    run fc-cache -f
    say "emoji-font: OK"
}
remove_font() { rm -rf $FONTDIR; run fc-cache -f; say "emoji-font: removed"; }

# ---------- apt sources ----------
install_aptfix() {
    for f in $(grep -l -E '^[^#]*(thecust|harmattan-dev\.nokia\.com)' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null); do
        mkdir -p $STATE/backup/apt
        [ -f $STATE/backup/apt/$(basename $f) ] || cp $f $STATE/backup/apt/
        sed -i -e '/^[^#]*thecust/s/^/# /' -e '/^[^#]*harmattan-dev\.nokia\.com/s/^/# /' $f
        say "apt-sources: disabled dead mirrors in $f"
    done
    say "apt-sources: OK"
}
remove_aptfix() {
    for b in $STATE/backup/apt/*; do
        [ -f "$b" ] || continue
        n=$(basename $b)
        if [ "$n" = sources.list ]; then cp $b /etc/apt/sources.list; else cp $b /etc/apt/sources.list.d/$n; fi
        say "apt-sources: restored $n"
    done
    rm -rf $STATE/backup/apt
}

# ---------- default browser (user file, written as user) ----------
user_browser() {
    cp $BASE/lib/user-browser.sh $STATE/user-browser.sh && chmod 755 $STATE/user-browser.sh
    as_user "/bin/sh $STATE/user-browser.sh $1" || { cat $OUT; fail "default-browser: failed"; return 1; }
    say "default-browser: $1 OK"
}
install_browser() {
    [ "$(status_of default-browser)" = installed ] && { say "default-browser: nothing to change"; return 0; }
    user_browser apply
}
remove_browser() { user_browser revert; }

# ---------- MeeCast Open-Meteo ----------
install_meecast() {
    [ -d $MEECAST ] || { fail "meecast-openmeteo: MeeCast is not installed"; return 1; }
    [ "$(status_of meecast-openmeteo)" = installed ] && [ "$(md5of $MEECAST_QML/OnlineSearchPage.qml)" = "$(md5of $PAY/meecast/qml/OnlineSearchPage.qml)" ] &&
        { say "meecast-openmeteo: already installed"; return 0; }
    cp $PAY/meecast/openmeteocom $MEECAST/lib/ && chmod 755 $MEECAST/lib/openmeteocom &&
    cp $PAY/meecast/open-meteo.com.xml $MEECAST/share/sources/ &&
    cp $PAY/meecast/open-meteo.com.db $MEECAST/share/db/ &&
    cp $PAY/meecast/open-meteo.com.png $MEECAST/share/images/ || { fail "meecast-openmeteo: copy failed"; return 1; }
    # QML screens only when the phone has the same MeeCast screens we patched (1.1.33)
    mkdir -p $STATE/backup/meecast
    qml_ok=yes
    for q in SearchField.qml StationsPage.qml CountryPage.qml; do
        cur=$(md5of $MEECAST_QML/$q)
        [ "$cur" = "$(md5of $PAY/meecast/qml/$q.original)" ] || [ "$cur" = "$(md5of $PAY/meecast/qml/$q)" ] || qml_ok=no
    done
    if [ $qml_ok = yes ]; then
        for q in SearchField.qml StationsPage.qml CountryPage.qml; do
            # keep a fresh copy of MeeCast's own screen (it changes when MeeCast is updated)
            [ "$(md5of $MEECAST_QML/$q)" = "$(md5of $PAY/meecast/qml/$q)" ] || cp $MEECAST_QML/$q $STATE/backup/meecast/
            cp $PAY/meecast/qml/$q $MEECAST_QML/
        done
        cp $PAY/meecast/qml/OnlineSearchPage.qml $MEECAST_QML/
        say "meecast-openmeteo: source + search screens OK (restart MeeCast)"
    else
        say "meecast-openmeteo: source OK; search screens skipped (different MeeCast version)"
    fi
}
remove_meecast() {
    rm -f $MEECAST/lib/openmeteocom $MEECAST/share/sources/open-meteo.com.xml $MEECAST/share/db/open-meteo.com.db $MEECAST/share/images/open-meteo.com.png $MEECAST_QML/OnlineSearchPage.qml
    for b in $STATE/backup/meecast/*.qml; do [ -f "$b" ] && cp $b $MEECAST_QML/; done
    rm -rf $STATE/backup/meecast
    say "meecast-openmeteo: removed"
}

# ---------- command line tools (e.g. kanaly.sh) ----------
install_tool() {
    line=$(comp_line "$1"); dst=$(field "$line" 3); file=$(field "$line" 5); deps=$(field "$line" 8)
    [ "$(status_of $1)" = installed ] && { say "$1: already installed"; return 0; }
    mkdir -p "$(dirname $dst)" && cp $PAY/tools/$file $dst && chmod 755 $dst || { fail "$1: copy failed"; return 1; }
    for d in $deps; do [ -n "$(pkgver $d)" ] || say "$1: note - some commands need '$d' (apt-get install $d)"; done
    say "$1: OK ($dst)"
}
remove_tool() { rm -f "$(field "$(comp_line $1)" 3)"; say "$1: removed"; }

# ---------- moving to another phone ----------
KANALY=/usr/local/bin/kanaly.sh
cmd_backup() {
    say "=== backup to $MIGRATE"
    as_user "mkdir -p $MIGRATE" || { cat $OUT; fail "cannot create $MIGRATE"; return 1; }
    if [ -f $KANALY ] && [ -x /usr/bin/tracker-sparql ]; then
        run sh $KANALY backup $MIGRATE/feeds.txt && say "feeds: $(tail -1 $OUT)" || { cat $OUT; fail "feeds: backup failed"; }
    else
        say "feeds: skipped (install 'kanaly' and tracker-utils)"
    fi
    say "AuthMee: make its own encrypted backup in the app (MyDocs/AuthMee) and copy it yourself"
    say "=== backup done - copy the MeeRevive folder from MyDocs to the new phone"
}
cmd_restore() {
    say "=== restore from $MIGRATE"
    if [ -f $MIGRATE/feeds.txt ]; then
        if [ -f $KANALY ]; then run sh $KANALY restore $MIGRATE/feeds.txt && say "feeds: $(grep -c '^+' $OUT) subscribed" || { cat $OUT; fail "feeds: restore failed"; }
        else say "feeds: install 'kanaly' first (sh engine.sh install kanaly)"; fi
    else
        say "feeds: no backup file"
    fi
    say "=== restore done"
}

# ---------- reboot ----------
ask_reboot() {   # $1 = reason
    say "*** Reboot needed: $1 ***"
    if [ -t 0 ]; then
        printf "Reboot now? Y for Yes, N for No: "
        read -r a
        case "$a" in
            y|Y|t|T) do_reboot ;;
            *) say "not rebooting now - later run: sh engine.sh reboot" ;;
        esac
    elif [ -z "$MEEREVIVE_APP" ]; then   # the app asks in its own dialog
        say "run: sh engine.sh reboot"
    fi
}

do_reboot() {
    say "rebooting"; sync
    reboot || dsmetool -b
}

# ---------- dispatch ----------
requires_ok() {
    req=$(field "$(comp_line $1)" 6)
    for r in $req; do
        [ "$(status_of $r)" = installed ] || { fail "$1: needs '$r' installed first"; return 1; }
    done
    return 0
}

do_one() {   # $1 = install|remove, $2 = id
    line=$(comp_line "$2")
    [ -n "$line" ] || { fail "unknown component: $2"; return 1; }
    kind=$(field "$line" 2)
    if [ "$1" = install ]; then
        requires_ok $2 || return 1
        case $kind in
            deb) install_deb $2 ;; tls) install_tls ;; font) install_font ;; tool) install_tool $2 ;;
            aptfix) install_aptfix ;; browser) install_browser ;; meecast) install_meecast ;;
        esac
    else
        case $kind in
            deb) remove_deb $2 ;; tls) remove_tls ;; font) remove_font ;; tool) remove_tool $2 ;;
            aptfix) remove_aptfix ;; browser) remove_browser ;; meecast) remove_meecast ;;
        esac
    fi
}

cmd_do() {
    act=$1; shift
    [ $# -gt 0 ] || { echo "Give component ids (see: sh engine.sh list)"; exit 1; }
    if [ "$1" = all ]; then
        set -- $(grep -v '^#' $LIST | grep '|' | cut -d'|' -f1)
        [ $act = remove ] && { echo "remove all is not supported - name the components"; exit 1; }
    fi
    say "=== engine $ENGINE_VERSION $act: $*"
    errors=0
    for id in "$@"; do
        if [ $act = install ] && [ "$(status_of $id)" = n/a ]; then say "$id: skipped (not applicable on this phone)"; continue; fi
        do_one $act $id || errors=$((errors+1))
    done
    say "=== done, errors: $errors"
    if [ -f $STATE/reboot-needed ] && [ $act = install ]; then
        rm -f $STATE/reboot-needed
        if [ $errors = 0 ]; then ask_reboot "TLS patch was installed"
        else say "*** Reboot needed after the TLS patch - fix the errors first, then: sh engine.sh reboot ***"; fi
    fi
    [ $errors = 0 ]
}

case "$1" in
    list) cmd_list ;;
    check) need_root; cmd_check ;;
    install|remove) need_root; cmd_do "$@" ;;
    tls-finish) need_root; cmd_tls_finish ;;
    backup) need_root; cmd_backup ;;
    restore) need_root; cmd_restore ;;
    reboot) need_root; do_reboot ;;
    log) tail -60 $LOG ;;
    version) echo $ENGINE_VERSION ;;
    *) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
