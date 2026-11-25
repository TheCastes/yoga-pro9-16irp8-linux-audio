#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="$ROOT/cache/driver"
DRIVER_URL="https://download.lenovo.com/consumer/mobiles/l0sp020fbjrekje0.exe"
DRIVER_SHA256="5c21f778657790fd5654f536badd0148af9f04982fe5ab840ebb01b99d211075"
XML_NAME="DEV_0287_SUBSYS_17AA387E_PCI_SUBSYS_383517AA.xml"
XML_SHA256="0aeedb9dc4343a548e0f2ff31e2564c33e4a8af890be1336fdf34226269a55fa"
XML="$CACHE/$XML_NAME"

die() { echo "fetch-tuning: $*" >&2; exit 1; }
note() { echo "==> $*"; }

[[ $EUID -ne 0 ]] || die "run as your user, not root"
for t in curl sha256sum innoextract; do command -v $t >/dev/null || die "$t not found"; done

if [[ -f $XML ]] && echo "$XML_SHA256  $XML" | sha256sum -c --status; then
    note "Tuning already present: $XML"
    exit 0
fi

model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
codec=$(grep -h '^Subsystem Id' /proc/asound/card*/codec#* 2>/dev/null | head -n1 | awk '{print $3}')
[[ $model == 83BY ]] || die "this is machine type '$model', not 83BY (Yoga Pro 9 16IRP8)"
[[ $codec == 0x17aa387e ]] || die "codec subsystem is '$codec', not 0x17aa387e: this tuning is not for your speakers"

mkdir -p "$CACHE"
exe="$CACHE/lenovo-audio-driver.exe"
if ! { [[ -f $exe ]] && echo "$DRIVER_SHA256  $exe" | sha256sum -c --status; }; then
    note "Downloading the Lenovo audio driver (about 205 MB) from download.lenovo.com"
    curl -fL --retry 3 -o "$exe.part" "$DRIVER_URL" || die "download failed"
    mv "$exe.part" "$exe"
fi
if ! echo "$DRIVER_SHA256  $exe" | sha256sum -c --status; then
    rm -f "$exe"
    die "the driver's SHA256 does not match the pinned one: Lenovo may have published a new version.
Nothing was extracted. To resolve the current package from Lenovo's catalog instead, run
  python3 $ROOT/cache/converter/tools/fetch_driver/get_lenovo_dax_xml.py
and pass the XML it prints to dolby/install.sh with --xml."
fi
note "Driver SHA256 verified"

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
innoextract -q -s -d "$tmp" -I "code\$GetExtractPath\$/Dolby/ext_lenovo_AIO_rtk/$XML_NAME" "$exe"
found=$(find "$tmp" -name "$XML_NAME" -print -quit)
[[ -n $found ]] || die "$XML_NAME not found in the driver"
echo "$XML_SHA256  $found" | sha256sum -c --status || die "the extracted tuning does not match the pinned SHA256"
install -m644 "$found" "$XML"
note "Tuning extracted and verified: $XML"
