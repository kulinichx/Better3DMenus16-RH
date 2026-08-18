# Better3DMenus16-RH v0.1.9

Native iOS 16 / RootHide / Dopamine rewrite of the useful Better3DMenus features.

## Target
- iPhone 14 Pro / A16 / iOS 16.6
- RootHide / Dopamine
- arm64 + arm64e
- patched iOS 16.5 SDK

## Current features
- Hide Separators
- Reduce Blur
- Hide Share App
- Hide Remove App
- Hide Section Gap
- Dynamic Icon Glass (experimental)
- Adaptive Text Color (experimental)

## Safety
Faster Haptic Touch is not implemented in this version. There are no global
`minimumPressDuration`, `UILongPressGestureRecognizer`, `SBIconView`, or
`SBHIconView` gesture hooks.

## Build
Push the complete repository to GitHub and run the included workflow, or use:

    make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
