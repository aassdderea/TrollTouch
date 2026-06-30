TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TrollTouch
TrollTouch_FILES = main.m AppDelegate.m ViewController.m TTHIDController.m
TrollTouch_FRAMEWORKS = UIKit Foundation AVFoundation
TrollTouch_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-error -Wno-unused-variable
TrollTouch_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

ipa: TrollTouch
	ldid -P -Sentitlements.plist $(THEOS_OBJ_DIR)/TrollTouch.app/TrollTouch 2>/dev/null || true
	@mkdir -p packages/Payload
	@cp -r $(THEOS_OBJ_DIR)/TrollTouch.app packages/Payload/
	@cd packages && zip -r TrollTouch.ipa Payload/
	@echo ">>> packages/TrollTouch.ipa ready"

all:: ipa
