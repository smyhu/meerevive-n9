#!/bin/sh
# MeeRevive: runs as 'user'. Removes Opera Mobile from the user's default
# application list so links open in the system browser. apply | revert
F=/home/user/.local/share/applications/defaults.list
B=$F.meerevive-bak
case "$1" in
    apply)
        [ -f "$F" ] || exit 0
        [ -f "$B" ] || cp "$F" "$B"
        grep -v operamobile "$B" > "$F.new" && mv "$F.new" "$F" ;;
    revert)
        [ -f "$B" ] || exit 0
        if ls /usr/share/applications/ 2>/dev/null | grep -q operamobile; then
            mv "$B" "$F"
        else
            # Opera is no longer installed: its lines would point to a missing app
            rm -f "$B"
            echo "Opera Mobile is not installed - nothing to restore"
        fi ;;
esac
