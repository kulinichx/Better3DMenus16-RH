ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = Better3DMenus16RHPrefs
Better3DMenus16RHPrefs_FILES = B3MRootListController.m
Better3DMenus16RHPrefs_FRAMEWORKS = UIKit
Better3DMenus16RHPrefs_PRIVATE_FRAMEWORKS = Preferences
Better3DMenus16RHPrefs_CFLAGS = -fobjc-arc -Wall -Wextra
Better3DMenus16RHPrefs_INSTALL_PATH = /Library/PreferenceBundles
Better3DMenus16RHPrefs_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk
