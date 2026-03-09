.PHONY: build test clean run release app dmg airflow-up airflow-down

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
	mkdir -p dmg-staging
	cp -R $(APP_BUNDLE) dmg-staging/
	ln -sf /Applications dmg-staging/Applications
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder dmg-staging \
		-ov -format UDZO \
		"$(DMG_NAME)"
	rm -rf dmg-staging
	@echo "$(DMG_NAME) created."

airflow-up:
	docker-compose up -d

airflow-down:
	docker-compose down -v
