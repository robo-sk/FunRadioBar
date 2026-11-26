#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app=dist/FunRadioBar.app
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
prefix="https://github.com/robo-sk/FunRadioBar/releases/download/v$version"
out=${1:?Pass a new output directory}
mkdir "$out"
archive="$out/FunRadioBar.zip"
tools=.build/artifacts/sparkle/Sparkle/bin
codesign --verify --deep --strict --all-architectures "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
key=(--account robo-sk.FunRadioBar)
if [[ -n ${SPARKLE_KEY_FILE:-} ]]; then key=(--ed-key-file "$SPARKLE_KEY_FILE"); fi
"$tools/generate_appcast" "${key[@]}" --maximum-deltas 0 --download-url-prefix "$prefix/" "$out"
signature=$(python3 - "$out" "$prefix" "$version" <<'PY'
import pathlib, sys, xml.etree.ElementTree as ET
out, prefix, version = sys.argv[1:]
items = ET.parse(pathlib.Path(out) / "appcast.xml").findall("./channel/item")
assert len(items) == 1, "Expected one release"
ns = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
item = items[0]
assert item.findtext(ns + "version") == version, "Incorrect build number"
assert item.findtext(ns + "shortVersionString") == version, "Incorrect release version"
file = pathlib.Path(out) / "FunRadioBar.zip"
asset = item.find("enclosure")
assert asset.get("url") == prefix + "/" + file.name, "Incorrect download URL"
assert int(asset.get("length")) == file.stat().st_size, "Incorrect archive length"
print(asset.attrib[ns + "edSignature"])
PY
)
"$tools/sign_update" "${key[@]}" --verify "$out/appcast.xml"
"$tools/sign_update" "${key[@]}" --verify "$archive" "$signature"
