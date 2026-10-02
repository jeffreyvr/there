#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your notarytool keychain profile name.}"
identity="${SIGNING_IDENTITY:-Developer ID Application}"
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Support/Info.plist)
tag="v$version"
app="dist/There.app"
zip="dist/There-$version.zip"

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    echo "Commit your changes first. The release must match a commit." >&2
    exit 1
fi

git fetch --quiet origin
if [[ -z "$(git branch -r --contains HEAD)" ]]; then
    echo "Push this commit to GitHub first. The release tag points at it." >&2
    exit 1
fi

if gh release view "$tag" >/dev/null 2>&1; then
    echo "Release $tag exists. Raise CFBundleShortVersionString in Support/Info.plist." >&2
    exit 1
fi

UNIVERSAL=1 zsh ./scripts/bundle-app.sh

# Notarization requires the hardened runtime and a secure timestamp.
codesign --force --options runtime --timestamp --sign "$identity" "$app"
codesign --verify --strict --verbose=2 "$app"

ditto -c -k --keepParent "$app" "$zip"
xcrun notarytool submit "$zip" --keychain-profile "$NOTARY_PROFILE" --wait

# Stapling lets Gatekeeper accept the app offline. The zip must be rebuilt to include the ticket.
xcrun stapler staple "$app"
rm "$zip"
ditto -c -k --keepParent "$app" "$zip"
spctl --assess --type execute --verbose=2 "$app"

gh release create "$tag" "$zip" \
    --target "$(git rev-parse HEAD)" \
    --title "There $version" \
    --generate-notes

echo "Released $tag"
