#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UNIT=tas2781-bass.service
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
CONTROL="iface=CARD,name=Speaker Force Firmware Load"

die() { echo "bass: $*" >&2; exit 1; }
note() { echo "==> $*"; }

[[ $EUID -ne 0 ]] || die "run as your user, not root"
command -v amixer >/dev/null || die "amixer not found (install alsa-utils)"

if [[ ${1:-} == --uninstall ]]; then
    systemctl --user disable --now "$UNIT" 2>/dev/null || true
    rm -f "$DEST/$UNIT"
    systemctl --user daemon-reload
    amixer -q -c sofhdadsp cset "$CONTROL" off 2>/dev/null || true
    note "Removed. The bass speakers stay off until the control is enabled again."
    exit 0
fi
[[ -z ${1:-} ]] || die "usage: $0 [--uninstall]"

model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
[[ $model == 83BY ]] || echo "bass: warning: tested only on machine type 83BY, this is '$model'" >&2
amixer -c sofhdadsp cget "$CONTROL" >/dev/null 2>&1 || die "control '$CONTROL' not found: is the TAS2781 amplifier driver loaded?"

mkdir -p "$DEST"
install -m644 "$HERE/$UNIT" "$DEST/$UNIT"
systemctl --user daemon-reload
systemctl --user enable "$UNIT"
systemctl --user restart "$UNIT"
note "$(amixer -c sofhdadsp cget "$CONTROL" | tail -n1 | sed 's/^ *: *//')"
note "Installed. Play something with bass to check."
