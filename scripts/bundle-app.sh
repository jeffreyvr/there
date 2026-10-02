#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release

app="dist/There.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"

cp .build/release/There "$app/Contents/MacOS/There"
cp Support/Info.plist "$app/Contents/Info.plist"
chmod +x "$app/Contents/MacOS/There"

codesign --force --sign - "$app" >/dev/null

echo "Built $app"
