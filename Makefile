ARCHS = arm64
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Runner

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlwataniGraceDev
AlwataniGraceDev_FILES = Tweak.xm
AlwataniGraceDev_CFLAGS = -fobjc-arc
AlwataniGraceDev_FRAMEWORKS = UIKit Foundation Security

include $(THEOS_MAKE_PATH)/tweak.mk
