.PHONY: build test clean run screenshot release app dmg airflow-up airflow-down

VERSION ?= 0.0.0-dev
APP_NAME = AirflowBar
APP_BUNDLE = $(APP_NAME).app
DMG_NAME = $(APP_NAME)-$(VERSION).dmg

build:
	swift build

test:
	swift test

clean:
	swift package clean
	rm -rf $(APP_BUNDLE) $(APP_NAME)-*.dmg

run:
	swift run $(APP_NAME)

screenshot:
	swift run $(APP_NAME) --screenshot

release:
	swift build -c release

app: release
	@echo "Creating $(APP_BUNDLE)..."
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	cp .build/release/$(APP_NAME) "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	sed 's/__VERSION__/$(VERSION)/g' Sources/AirflowBar/Info.plist > "$(APP_BUNDLE)/Contents/Info.plist"
	@if [ -f Sources/AirflowBar/Resources/AppIcon.icns ]; then \
		cp Sources/AirflowBar/Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"; \
	fi
	@echo "$(APP_BUNDLE) created."

dmg: app
	@echo "Creating $(DMG_NAME)..."
	@rm -f "$(DMG_NAME)"
	create-dmg \
		--volname "$(APP_NAME)" \
		--volicon "Sources/AirflowBar/Resources/AppIcon.icns" \
		--background "dmg-resources/dmg-background.png" \
		--window-pos 200 120 \
		--window-size 660 400 \
		--icon-size 80 \
		--icon "$(APP_BUNDLE)" 176 180 \
		--app-drop-link 484 180 \
		--hide-extension "$(APP_BUNDLE)" \
		--no-internet-enable \
		"$(DMG_NAME)" \
		"$(APP_BUNDLE)"
	@# Stamp custom icon onto the .dmg file in Finder
	@if [ -f Sources/AirflowBar/Resources/AppIcon.icns ] && command -v fileicon > /dev/null 2>&1; then \
		TMP_ICON=$$(mktemp /tmp/dmgicon.XXXXXX.png); \
		sips -s format png --resampleHeightWidth 512 512 Sources/AirflowBar/Resources/AppIcon.icns --out "$$TMP_ICON" > /dev/null 2>&1; \
		fileicon set "$(DMG_NAME)" "$$TMP_ICON"; \
		rm -f "$$TMP_ICON"; \
		echo "Custom icon stamped on $(DMG_NAME)."; \
	fi
	@echo "$(DMG_NAME) created."

airflow-up:
	docker-compose up -d

airflow-down:
	docker-compose down -v
