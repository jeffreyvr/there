# There

A small macOS menu bar app for working with a client in another time zone.

- See your time and your client's time at a glance.
- Type a time the client said, like `15:00`, `3pm`, or `15u30`, and get it in your time. Swap the direction to convert your time for them.
- See if a time works for both of you, based on your working hours.
- See the hours you share on any day.

## Install

1. Download `There-<version>.zip` from the [latest release](https://github.com/jeffreyvr/there/releases/latest).
2. Unzip it and move `There.app` to your Applications folder.
3. Open it. A globe appears in the menu bar.

The app is signed and notarized. It needs macOS 15 or later and runs on Apple silicon and Intel Macs.

If you use a menu bar manager such as Hidden Bar, it can hide new items. Hold Command and drag the globe to a visible place.

## Build from source

You need Xcode 26 or later.

```sh
make test   # run the tests
make app    # build dist/There.app
make open   # build and launch
```

## Release

The release script builds a universal app, signs it with your Developer ID, notarizes it, and uploads it to a GitHub release.

1. Raise `CFBundleShortVersionString` in `Support/Info.plist` and commit.
2. Run:

```sh
NOTARY_PROFILE=<your notarytool profile> make release
```

To use a specific certificate, set `SIGNING_IDENTITY`. The default is `Developer ID Application`.
