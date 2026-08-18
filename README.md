# Better3DMenus16-RH v0.1.2

A conservative iOS 16 / RootHide rewrite inspired by the useful parts of the legacy Better3DMenus tweak.

## v0.1.2 scope

- Hide Separators
- Reduce Blur
- Hide Share App
- Faster Haptic Touch

Explicitly not included:

- Reverse items order
- Flip icons to the left
- Square menu
- Bigger SpringBoard icon
- Split widgets
- Disable animations (reserved for a later experiment)

## Target

Primary test target: iPhone 14 Pro / iPhone15,2 / A16 / iOS 16.6 / RootHide Dopamine.

## Design notes

- Injects only into SpringBoard.
- Uses modern UIKit menu objects for Share App filtering.
- Separator and blur changes are view-only and restore their captured state when disabled.
- Faster Haptic Touch is scoped to SpringBoard icon-view long-press recognizers instead of globally changing all long presses.
- Private classes are hooked only by name; if a class is absent on a particular iOS 16 build, that hook simply has no effect rather than relying on ivars or fixed subview indexes.

## Build

Use RootHide Theos:

```sh
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
```

Or push this project to GitHub and run the included **Build Better3DMenus16-RH** workflow.

## Test order

Start with all four features enabled, then verify:

1. Long-press Home Screen icons repeatedly.
2. Open folders and long-press icons inside folders.
3. Confirm Share App is removed while other quick actions remain.
4. Confirm separators are hidden.
5. Confirm context-menu blur is reduced without losing readability.
6. Run normal Sileo / install-app / respring scenarios separately so tweak failures are not confused with D1 stability results.

If a feature is ineffective on a specific iOS 16 build, disable it and report the device/iOS version; do not repeatedly force a SpringBoard crash while D1 is under soak testing.
