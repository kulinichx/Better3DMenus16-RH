ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:16.0
THEOS_PACKAGE_SCHEME = roothide
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Better3DMenus16RH
Better3DMenus16RH_FILES = Tweak.xm
Better3DMenus16RH_CFLAGS = -fobjc-arc -Wall -Wextra
Better3DMenus16RH_FRAMEWORKS = UIKit QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += better3dmenus16rhprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
