#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Bash 3.2 (the macOS default) treats empty arrays as unbound with set -u.
if [[ "${1:-}" == "--universal" ]]; then
    swift build -c release --arch arm64 --arch x86_64
    bin_dir=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
else
    swift build -c release
    bin_dir=$(swift build -c release --show-bin-path)
fi
app="$PWD/dist/LidTone.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/LidTone" "$app/Contents/MacOS/LidTone"
cp packaging/Info.plist "$app/Contents/Info.plist"
# SoundResources resolves this bundle from Contents/Resources inside the app.
for bundle in "$bin_dir"/*.bundle; do
    [[ -d "$bundle" ]] && ditto "$bundle" "$app/Contents/Resources/$(basename "$bundle")"
done
swift scripts/make-icon.swift "$app/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign "${CODE_SIGN_IDENTITY:--}" "$app"
"$app/Contents/MacOS/LidTone" --check
codesign --verify --deep --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" dist/LidTone-macOS.zip
printf '\nBuilt %s\n' "$app"
