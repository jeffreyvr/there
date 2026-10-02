.PHONY: test app open

test:
	swift test

app:
	zsh ./scripts/bundle-app.sh

open: app
	-killall There
	open dist/There.app
