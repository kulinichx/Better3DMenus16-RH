# 3DTouchGlass v0.3.0

iOS 16 / RootHide / Dopamine context-menu customization with Clear and Liquid Glass effects.

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
- Adaptive Text Color
- Glass Effect toggle
- Clear / Liquid Glass segmented styles
- Independent Clear / Liquid Glass strength values
- Single active Strength slider with 5% detents and haptic feedback

## Safety
Faster Haptic Touch / Pressure Activation is not included in v0.3.0. There are no global
`minimumPressDuration`, `UILongPressGestureRecognizer`, `SBIconView`, or
`SBHIconView` gesture hooks.

## Build
Push the complete repository to GitHub and run the included workflow, or use:

    make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
