# Helper makefile for Soon packaging and local development.

APP_NAME := Soon
APP_EXEC := Soon
APP_PRODUCT := Soon

DIST_DIR := dist
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
APP_CONTENTS := $(APP_BUNDLE)/Contents
APP_MACOS := $(APP_CONTENTS)/MacOS
APP_RESOURCES := $(APP_CONTENTS)/Resources
APP_BIN := $(APP_MACOS)/$(APP_EXEC)
PLIST_TEMPLATE := packaging/Info.plist
PLIST := $(APP_CONTENTS)/Info.plist

APP_ICON_SVG := packaging/Soon.svg
APP_ICON_FILE := $(APP_NAME)
APP_ICON_ICNS := $(APP_RESOURCES)/$(APP_ICON_FILE).icns

PACKAGE_NAME := $(APP_NAME)-$(VERSION).zip
PACKAGE_ZIP := $(DIST_DIR)/$(PACKAGE_NAME)
PACKAGE_STAGE := $(DIST_DIR)/package
PACKAGE_ROOT := $(APP_NAME)-$(VERSION)

BUILD_INFO := Sources/Soon/Runtime/BuildInfo.swift

BUNDLE_ID ?= io.github.gi8lino.soon
VERSION ?= dev
ARCH ?= universal

VERSION_PREFIX ?= v
LATEST_TAG := $(shell git tag --list '$(VERSION_PREFIX)*' --sort=-v:refname | head -n 1)
CURRENT_VERSION := $(if $(LATEST_TAG),$(patsubst $(VERSION_PREFIX)%,%,$(LATEST_TAG)),0.0.0)

NEXT_PATCH := $(shell python3 -c 'm,n,p=map(int,"$(CURRENT_VERSION)".split(".")); print(f"{m}.{n}.{p+1}")')
NEXT_MINOR := $(shell python3 -c 'm,n,p=map(int,"$(CURRENT_VERSION)".split(".")); print(f"{m}.{n+1}.0")')
NEXT_MAJOR := $(shell python3 -c 'm,n,p=map(int,"$(CURRENT_VERSION)".split(".")); print(f"{m+1}.0.0")')

SWIFT_BUILD_RELEASE := swift build -c release
SWIFT_BUILD_DEBUG := swift build -c debug
SWIFT_TEST := swift test --scratch-path .build

ifeq ($(ARCH),universal)
ARCHES := arm64 x86_64
else ifeq ($(ARCH),arm64)
ARCHES := arm64
else ifeq ($(ARCH),x86_64)
ARCHES := x86_64
else
$(error Unsupported ARCH '$(ARCH)'. Use arm64, x86_64, or universal)
endif

.DEFAULT_GOAL := help

.PHONY: help all prepare-version build app bundle package release fmt test clean clean-dist run dev stop icons restart-brew \
        build-app verify verify-release stamp-plist sign \
        print-arch print-version print-latest-tag print-package-sha256 \
        tag-patch tag-minor tag-major push-tags

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Build

all: build ## Build the default artifacts.

prepare-version: ## Update BuildInfo.swift with the selected VERSION.
	@mkdir -p "$(dir $(BUILD_INFO))"
	@python3 -c 'from pathlib import Path; import re; path = Path("$(BUILD_INFO)"); text = path.read_text(); \
updated = re.sub(r"public static let appVersion = \".*?\"", "public static let appVersion = \"$(VERSION)\"", text, count=1); \
path.write_text(updated)'

build: bundle ## Build the app bundle for the selected ARCH.

app: prepare-version ## Build only the app executable for the selected ARCH.
	@$(MAKE) --no-print-directory build-app ARCH=$(ARCH) VERSION=$(VERSION)

test: ## Build and run Swift package tests.
	@$(SWIFT_TEST)

fmt: ## Format all Swift source files in the repository.
	@swift format format --in-place --recursive --parallel .

bundle: prepare-version clean-dist ## Build Soon.app into dist/.
	@mkdir -p "$(APP_MACOS)" "$(APP_RESOURCES)" "$(DIST_DIR)"
	@$(MAKE) --no-print-directory build-app ARCH=$(ARCH) VERSION=$(VERSION)
	@$(MAKE) --no-print-directory icons
	@cp "$(PLIST_TEMPLATE)" "$(PLIST)"
	@$(MAKE) --no-print-directory stamp-plist VERSION=$(VERSION) BUNDLE_ID=$(BUNDLE_ID)
	@chmod +x "$(APP_BIN)"
	@$(MAKE) --no-print-directory sign
	@$(MAKE) --no-print-directory verify

package: bundle ## Create the release ZIP consumed by the Homebrew formula.
	@rm -rf "$(PACKAGE_STAGE)" "$(PACKAGE_ZIP)"
	@mkdir -p "$(PACKAGE_STAGE)/$(PACKAGE_ROOT)"
	@cp -R "$(APP_BUNDLE)" "$(PACKAGE_STAGE)/$(PACKAGE_ROOT)/$(APP_NAME).app"
	@cd "$(PACKAGE_STAGE)" && zip -qry "../$(PACKAGE_NAME)" "$(PACKAGE_ROOT)"
	@rm -rf "$(PACKAGE_STAGE)"
	@echo "Created $(PACKAGE_ZIP)"

release: package ## Build and verify the zipped release artifact.
	@$(MAKE) --no-print-directory verify-release VERSION=$(VERSION) ARCH=$(ARCH)
	@echo "Release artifact ready: $(PACKAGE_ZIP)"

build-app: ## Internal target: build the app executable for ARCH.
ifeq ($(ARCH),universal)
	@$(SWIFT_BUILD_RELEASE) --arch arm64 --product $(APP_PRODUCT)
	@$(SWIFT_BUILD_RELEASE) --arch x86_64 --product $(APP_PRODUCT)
	@lipo -create \
		".build/arm64-apple-macosx/release/$(APP_PRODUCT)" \
		".build/x86_64-apple-macosx/release/$(APP_PRODUCT)" \
		-output "$(APP_BIN)"
else
	@$(SWIFT_BUILD_RELEASE) --arch $(ARCH) --product $(APP_PRODUCT)
	@cp ".build/$(ARCH)-apple-macosx/release/$(APP_PRODUCT)" "$(APP_BIN)"
endif

icons: ## Generate the app .icns file from packaging/Soon.svg when present.
	@mkdir -p "$(APP_RESOURCES)"
	@if [ ! -f "$(APP_ICON_SVG)" ]; then \
		echo "No $(APP_ICON_SVG); skipping icon generation."; \
		exit 0; \
	fi
	@set -e; \
	svg="$(APP_ICON_SVG)"; \
	icns="$(APP_ICON_ICNS)"; \
	base="$$(basename "$$icns" .icns)"; \
	tmp_dir="$(DIST_DIR)/.$$base.iconset"; \
	render_dir="$(DIST_DIR)/.$$base.render"; \
	rm -rf "$$tmp_dir" "$$render_dir"; \
	mkdir -p "$$tmp_dir" "$$render_dir"; \
	qlmanage -t -s 1024 -o "$$render_dir" "$$svg" >/dev/null 2>&1; \
	rendered_png="$$render_dir/$$(basename "$$svg").png"; \
	test -f "$$rendered_png"; \
	cp "$$rendered_png" "$$tmp_dir/icon_512x512@2x.png"; \
	sips -z 16 16 "$$rendered_png" --out "$$tmp_dir/icon_16x16.png" >/dev/null; \
	sips -z 32 32 "$$rendered_png" --out "$$tmp_dir/icon_16x16@2x.png" >/dev/null; \
	sips -z 32 32 "$$rendered_png" --out "$$tmp_dir/icon_32x32.png" >/dev/null; \
	sips -z 64 64 "$$rendered_png" --out "$$tmp_dir/icon_32x32@2x.png" >/dev/null; \
	sips -z 128 128 "$$rendered_png" --out "$$tmp_dir/icon_128x128.png" >/dev/null; \
	sips -z 256 256 "$$rendered_png" --out "$$tmp_dir/icon_128x128@2x.png" >/dev/null; \
	sips -z 256 256 "$$rendered_png" --out "$$tmp_dir/icon_256x256.png" >/dev/null; \
	sips -z 512 512 "$$rendered_png" --out "$$tmp_dir/icon_256x256@2x.png" >/dev/null; \
	sips -z 512 512 "$$rendered_png" --out "$$tmp_dir/icon_512x512.png" >/dev/null; \
	iconutil -c icns "$$tmp_dir" -o "$$icns"; \
	rm -rf "$$tmp_dir" "$$render_dir"

stamp-plist: ## Internal target: stamp version and bundle ID into Info.plist.
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier $(BUNDLE_ID)' "$(PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString $(VERSION)' "$(PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion $(VERSION)' "$(PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable $(APP_EXEC)' "$(PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleName $(APP_NAME)' "$(PLIST)" >/dev/null 2>&1 || true
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName $(APP_NAME)' "$(PLIST)" >/dev/null 2>&1 || true
	@if [ -f "$(APP_ICON_ICNS)" ]; then \
		/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string $(APP_ICON_FILE)' "$(PLIST)" >/dev/null 2>&1 || \
		/usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile $(APP_ICON_FILE)' "$(PLIST)"; \
	fi

sign: ## Ad-hoc sign the bundle for local launching.
	@codesign --force --deep --sign - "$(APP_BUNDLE)" >/dev/null 2>&1 || true

verify: ## Show the built binary architectures and packaged artifacts.
	@echo "Built $(ARCH) artifact:"
	@file "$(APP_BIN)"
	@test -f "$(PLIST)"
	@echo "Info.plist:"
	@plutil -p "$(PLIST)"
	@echo "Packaged app root:"
	@ls -1 "$(APP_BUNDLE)"
	@echo "Packaged Contents:"
	@ls -1 "$(APP_CONTENTS)"
	@echo "Packaged Resources:"
	@ls -1 "$(APP_RESOURCES)" 2>/dev/null || true

verify-release: ## Validate the release package and print release fingerprints.
	@$(MAKE) --no-print-directory verify
	@test -f "$(PACKAGE_ZIP)"
	@echo "Release package:"
	@ls -lh "$(PACKAGE_ZIP)"
	@echo "Build fingerprints:"
	@shasum -a 256 "$(APP_BIN)"
	@shasum -a 256 "$(PLIST)"
	@shasum -a 256 "$(PACKAGE_ZIP)"
	@codesign -dv --verbose=4 "$(APP_BUNDLE)" 2>&1 || true

run: bundle ## Build, stop old instances, and open Soon.
	@$(MAKE) --no-print-directory stop
	@open "$(APP_BUNDLE)"

dev: prepare-version ## Fast debug run without bundling.
	@$(MAKE) --no-print-directory stop
	@$(SWIFT_BUILD_DEBUG) --product $(APP_PRODUCT)
	@swift run -c debug $(APP_PRODUCT)

stop: ## Stop Homebrew and local Soon app instances.
	@if command -v brew >/dev/null 2>&1; then \
		brew services stop soon >/dev/null 2>&1 || true; \
	fi
	@pkill -x "$(APP_EXEC)" >/dev/null 2>&1 || true
	@pkill -f "$(abspath $(APP_BIN))" >/dev/null 2>&1 || true

restart-brew: ## Restart Soon Homebrew services.
	brew services restart gi8lino/tap/soon

##@ Cleanup

clean-dist: ## Remove dist/.
	@rm -rf "$(DIST_DIR)"

clean: ## Remove dist/, .build, and reset BuildInfo.swift to its placeholder version.
	@rm -rf "$(DIST_DIR)" ".build"
	@python3 -c 'from pathlib import Path; import re; path = Path("$(BUILD_INFO)"); text = path.read_text(); \
updated = re.sub(r"public static let appVersion = \".*?\"", "public static let appVersion = \"dev\"", text, count=1); \
path.write_text(updated)'

##@ Info

print-arch: ## Print the selected ARCH.
	@echo "$(ARCH)"

print-version: ## Print the current version derived from the latest tag.
	@echo "$(CURRENT_VERSION)"

print-latest-tag: ## Print the latest matching git tag.
	@echo "$(LATEST_TAG)"

print-package-sha256: package ## Print the SHA-256 of the packaged zip.
	@shasum -a 256 "$(PACKAGE_ZIP)"

##@ Tagging

tag-patch: ## Create the next patch tag locally.
	@git tag -a "$(VERSION_PREFIX)$(NEXT_PATCH)" -m "Release $(VERSION_PREFIX)$(NEXT_PATCH)"
	@echo "Created tag $(VERSION_PREFIX)$(NEXT_PATCH)"

tag-minor: ## Create the next minor tag locally.
	@git tag -a "$(VERSION_PREFIX)$(NEXT_MINOR)" -m "Release $(VERSION_PREFIX)$(NEXT_MINOR)"
	@echo "Created tag $(VERSION_PREFIX)$(NEXT_MINOR)"

tag-major: ## Create the next major tag locally.
	@git tag -a "$(VERSION_PREFIX)$(NEXT_MAJOR)" -m "Release $(VERSION_PREFIX)$(NEXT_MAJOR)"
	@echo "Created tag $(VERSION_PREFIX)$(NEXT_MAJOR)"

push-tags: ## Push commits and tags to origin.
	@git push --follow-tags
