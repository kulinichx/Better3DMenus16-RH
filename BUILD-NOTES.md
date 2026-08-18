# Better3DMenus16-RH v0.2.2 — Root Glass Host

- Fixes the reason 0.2.0/0.2.1 visually looked stock on the tested device.
- Glass is now hosted directly in `_UIContextMenuView`, the same class whose text hook is visibly active on-device.
- Stock background/material descendants are suppressed recursively by role/name while action content stays above the replacement glass.
- The existing GlassFolders-derived CABackdrop/CAFilter recipe remains the material engine.
- No long-press timing hook is added.
