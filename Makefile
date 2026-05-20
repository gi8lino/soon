APP_NAME := Soon
EXECUTABLE := Soon
BUNDLE_ID := io.github.gi8lino.soon
BUILD_CONFIG ?= release

.PHONY: build run stop clean bundle

build:
	swift build

bundle:
	swift build -c $(BUILD_CONFIG)
	rm -rf dist/$(APP_NAME).app
	mkdir -p dist/$(APP_NAME).app/Contents/MacOS
	mkdir -p dist/$(APP_NAME).app/Contents/Resources
	cp .build/$(BUILD_CONFIG)/$(EXECUTABLE) dist/$(APP_NAME).app/Contents/MacOS/$(EXECUTABLE)
	cp Sources/Soon/App/Info.plist dist/$(APP_NAME).app/Contents/Info.plist

run: bundle
	open dist/$(APP_NAME).app

stop:
	pkill -x $(EXECUTABLE) || true

clean:
	rm -rf .build dist
