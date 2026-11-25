#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONVERTER="$ROOT/cache/converter"
CONVERTER_URL="https://github.com/antoinecellerier/speaker-tuning-to-easyeffects"
CONVERTER_TAG="v2026.10.1"
CONVERTER_COMMIT="2838efda3e5bcac4002ec91c78a43a66f8ada878"
XML="$ROOT/cache/driver/DEV_0287_SUBSYS_17AA387E_PCI_SUBSYS_383517AA.xml"
PRESET="Dolby-Dynamic-Balanced"
UNIT=easyeffects.service
TUNING=()
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

die() { echo "dolby: $*" >&2; exit 1; }
note() { echo "==> $*"; }

usage() {
    echo "Usage: dolby/install.sh [--xml FILE] [--preset NAME] [--without-regulator] [--dry-run] [--uninstall] [-- converter options]"
    exit "${1:-0}"
}

[[ $EUID -ne 0 ]] || die "run as your user, not root"

uninstall=0
dry=()
extra=()
while (($#)); do
    case $1 in
        --xml) XML=${2:?--xml needs a file}; shift ;;
        --preset) PRESET=${2:?--preset needs a name}; shift ;;
        --dry-run) dry=(--dry-run) ;;
        --without-regulator) TUNING=(--disable regulator) ;;
        --uninstall) uninstall=1 ;;
        -h|--help) usage ;;
        --) shift; extra=("$@"); break ;;
        *) usage 1 ;;
    esac
    shift
done

for t in git python3 easyeffects; do command -v $t >/dev/null || die "$t not found"; done
python3 -c 'import numpy, scipy' 2>/dev/null || die "python numpy and scipy are required"
lsp=0
IFS=: read -ra lv2dirs <<< "${LV2_PATH:-$HOME/.lv2:/usr/local/lib/lv2:/usr/lib/lv2}"
for d in "${lv2dirs[@]}"; do compgen -G "$d/lsp-plugins*.lv2" >/dev/null && lsp=1; done
((lsp)) || die "LSP plugins not found: install lsp-plugins-lv2, without it EasyEffects silently skips the equalizer and limiter"

if [[ ! -d $CONVERTER/.git ]]; then
    note "Fetching the converter $CONVERTER_TAG"
    git clone -q --depth 1 --branch "$CONVERTER_TAG" "$CONVERTER_URL" "$CONVERTER" 2>/dev/null || die "could not fetch the converter"
fi
[[ $(git -C "$CONVERTER" rev-parse HEAD) == "$CONVERTER_COMMIT" ]] || die "converter is not at the pinned commit $CONVERTER_COMMIT (remove $CONVERTER and retry)"
[[ -z $(git -C "$CONVERTER" status --porcelain) ]] || die "converter checkout has local changes (remove $CONVERTER and retry)"

if ((uninstall)); then
    if [[ -f $UNIT_DIR/$UNIT ]]; then
        systemctl --user disable --now "$UNIT" 2>/dev/null || true
        rm -f "$UNIT_DIR/$UNIT"
        systemctl --user daemon-reload
        note "Removed the EasyEffects background service"
    fi
    exec python3 "$CONVERTER/dolby_to_easyeffects.py" --uninstall "${extra[@]}"
fi

[[ -f $XML ]] || "$ROOT/dolby/fetch-tuning.sh"
python3 "$CONVERTER/dolby_to_easyeffects.py" "$XML" --all-profiles --autoload "$PRESET" "${TUNING[@]}" "${dry[@]}" "${extra[@]}"
((${#dry[@]})) && exit 0
mkdir -p "$UNIT_DIR"
install -m644 "$ROOT/dolby/$UNIT" "$UNIT_DIR/$UNIT"
systemctl --user daemon-reload
systemctl --user enable "$UNIT"
if pgrep -u "$UID" -x easyeffects >/dev/null && ! systemctl --user is-active --quiet "$UNIT"; then
    note "EasyEffects is already running outside the service: it will be managed by the service from the next login"
else
    systemctl --user restart "$UNIT"
fi
note "Done. Start at a moderate volume: the presets add up to +6 dB of loudness."
