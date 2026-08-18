# Build / audit notes

## Legacy Better3DMenus evidence used

The supplied legacy binary contains the SpringBoard filter and the historical Share App identifier:

- `com.apple.springboard.application-shortcut-item.share`

The v0.1 filter recognizes that identifier and a conservative SpringBoard-owned variant pattern. It also has an exact-title fallback for a small set of English/Chinese Share App labels.

## Safety choices

- No direct ivar writes.
- No fixed subview indexes.
- No assert/abort paths.
- No global long-press timing hook.
- No menu ordering or geometry changes.
- No widget manipulation.
- No D1 / jailbreak runtime modifications.

## v0.1.2 filter fix

- Added the required top-level `Better3DMenus16RH.plist` MobileLoader/Substrate filter.
- Filter is restricted to `com.apple.springboard`.
- Kept the layout copy identical for packaging compatibility.
- Workflow now validates the filter and preference plists before compiling.
- Retains patched Theos iOS 16.5 SDK and `TARGET = iphone:clang:16.5:16.0`.
