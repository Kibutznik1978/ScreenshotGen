APP_NAME = ScreenshotGen
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

.PHONY: app run clean xcodegen

app:
	swift build -c release --product ScreenshotGenUI
	mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	cp "$$(swift build -c release --product ScreenshotGenUI --show-bin-path)/ScreenshotGenUI" $(MACOS_DIR)/$(APP_NAME)
	/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $(APP_NAME)" $(CONTENTS_DIR)/Info.plist 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.screenshotgen.app" $(CONTENTS_DIR)/Info.plist 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Add :CFBundleName string $(APP_NAME)" $(CONTENTS_DIR)/Info.plist 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" $(CONTENTS_DIR)/Info.plist 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0.0" $(CONTENTS_DIR)/Info.plist 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" $(CONTENTS_DIR)/Info.plist 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 14.0" $(CONTENTS_DIR)/Info.plist 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable bool true" $(CONTENTS_DIR)/Info.plist 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" $(CONTENTS_DIR)/Info.plist 2>/dev/null || true
	mkdir -p $(BUILD_DIR)/AppIcon.iconset
	cp Sources/ScreenshotGenUI/Assets.xcassets/AppIcon.appiconset/icon_16x16.png $(BUILD_DIR)/AppIcon.iconset/icon_16x16.png
	cp Sources/ScreenshotGenUI/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png $(BUILD_DIR)/AppIcon.iconset/icon_16x16@2x.png
	cp Sources/ScreenshotGenUI/Assets.xcassets/AppIcon.appiconset/icon_32x32.png $(BUILD_DIR)/AppIcon.iconset/icon_32x32.png
	cp Sources/ScreenshotGenUI/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png $(BUILD_DIR)/AppIcon.iconset/icon_32x32@2x.png
	cp Sources/ScreenshotGenUI/Assets.xcassets/AppIcon.appiconset/icon_128x128.png $(BUILD_DIR)/AppIcon.iconset/icon_128x128.png
	cp Sources/ScreenshotGenUI/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png $(BUILD_DIR)/AppIcon.iconset/icon_128x128@2x.png
	cp Sources/ScreenshotGenUI/Assets.xcassets/AppIcon.appiconset/icon_256x256.png $(BUILD_DIR)/AppIcon.iconset/icon_256x256.png
	cp Sources/ScreenshotGenUI/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png $(BUILD_DIR)/AppIcon.iconset/icon_256x256@2x.png
	cp Sources/ScreenshotGenUI/Assets.xcassets/AppIcon.appiconset/icon_512x512.png $(BUILD_DIR)/AppIcon.iconset/icon_512x512.png
	cp Sources/ScreenshotGenUI/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png $(BUILD_DIR)/AppIcon.iconset/icon_512x512@2x.png
	iconutil -c icns $(BUILD_DIR)/AppIcon.iconset -o $(RESOURCES_DIR)/AppIcon.icns
	rm -rf $(BUILD_DIR)/AppIcon.iconset
	@echo "Built $(APP_BUNDLE)"

run: app
	@pkill -f "$(APP_NAME).app" 2>/dev/null || true
	@open $(APP_BUNDLE)

xcodegen:
	xcodegen generate

clean:
	rm -rf $(BUILD_DIR)
	swift package clean
