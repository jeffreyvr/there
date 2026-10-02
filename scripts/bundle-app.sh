#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

# Releases ship one binary for Apple silicon and Intel. Local builds stay native and fast.
if [[ -n "${UNIVERSAL:-}" ]]; then
    swift build -c release --arch arm64 --arch x86_64
    binary=".build/apple/Products/Release/There"
else
    swift build -c release
    binary=".build/release/There"
fi

app="dist/There.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

cp "$binary" "$app/Contents/MacOS/There"
cp Support/Info.plist "$app/Contents/Info.plist"
chmod +x "$app/Contents/MacOS/There"

# Compiles the Icon Composer file into Assets.car for macOS 26, plus There.icns for older systems.
xcrun actool Support/There.icon \
    --compile "$app/Contents/Resources" \
    --platform macosx \
    --minimum-deployment-target 15.0 \
    --app-icon There \
    --output-partial-info-plist "$(mktemp)" \
    >/dev/null

codesign --force --sign - "$app" >/dev/null

echo "Built $app"
