.PHONY: dmg test clean hooks

# Build a Release app and package dist/JWTee.dmg.
dmg:
	bash tools/make_dmg.sh

# Enable the tracked git hooks (pre-push runs `make dmg`).
hooks:
	git config core.hooksPath .githooks
	@echo "git hooks enabled (core.hooksPath = .githooks)"

# Run the test suite via SwiftPM.
test:
	swift test

# Remove build output and the packaged dmg.
clean:
	rm -rf .build-xcode dist
