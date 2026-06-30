TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e
FINALPACKAGE = 0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = TrollTouch
TrollTouch_FILES = TrollTouch.m
TrollTouch_FRAMEWORKS = UIKit Foundation
TrollTouch_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Iinclude
TrollTouch_INSTALL_PATH = /usr/lib

include $(THEOS_MAKE_PATH)/library.mk

after-TrollTouch-stage::
	@echo "=== Build complete ==="
	@mkdir -p packages
	@cp $(THEOS_OBJ_DIR)/TrollTouch.dylib packages/TrollTouch.dylib
