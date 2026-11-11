APP = Pomodoro.app

run:
	swift run

test:
	swift test

app:
	swift build -c release
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/Pomodoro $(APP)/Contents/MacOS/
	cp Info.plist $(APP)/Contents/
	codesign --force --sign - $(APP)

install: app
	rm -rf /Applications/$(APP)
	cp -R $(APP) /Applications/

clean:
	rm -rf .build $(APP)

.PHONY: run test app install clean
