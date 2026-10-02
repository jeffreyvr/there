.PHONY: test app open release

test:
	swift test

app:
	zsh ./scripts/bundle-app.sh

open: app
	-killall There
	open dist/There.app

release:
	zsh ./scripts/release.sh
