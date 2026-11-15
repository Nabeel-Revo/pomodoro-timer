APP = Pomodoro.app
# Notifications with action buttons need a real signing identity; ad-hoc ("-") still runs fine without them.
SIGN ?= $(shell security find-identity -v -p codesigning | grep -o '"Apple Development[^"]*"' | head -1)
SIGN := $(if $(SIGN),$(SIGN),-)

run:
	swift run

test:
	swift test

app:
	swift build -c release
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/Pomodoro $(APP)/Contents/MacOS/
	cp Info.plist $(APP)/Contents/
	codesign --force --sign $(SIGN) $(APP)

install: app
	rm -rf /Applications/$(APP)
	cp -R $(APP) /Applications/

clean:
	rm -rf .build $(APP)

.PHONY: run test app install clean
