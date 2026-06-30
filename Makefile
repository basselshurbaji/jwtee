.PHONY: dmg test clean

# Build a Release app and package dist/JWTee.dmg.
dmg:
	bash tools/make_dmg.sh

# Run the test suite via SwiftPM.
test:
	swift test

# Remove build output and the packaged dmg.
clean:
	rm -rf .build-xcode dist
