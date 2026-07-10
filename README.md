# ClaraLight Design — Flutter

Monorepo for the **ClaraLight** design language on Flutter.
(Facetory is the demo app built with it; its Figma file is the design
source of truth.)

| Package | What it is |
| --- | --- |
| [`packages/claralight_ui`](packages/claralight_ui) | The component library. Pure Dart, flat layered dark design, bundled fonts. |
| [`packages/claralight_ui_gallery`](packages/claralight_ui_gallery) | Live showcase app for every component. |

## Design principles

1. **Flat and layered.** Translucent white-alpha control fills over deep
   surfaces (#191919 → panel → control), sparing accent color. Works
   identically on every platform and OS version with zero native code.
2. **Smooth corners.** Every rounded corner is a rounded superellipse
   (squircle), never a plain circular arc.
3. **Springy physics.** Presses scale with overshoot, drags deform like
   jelly (`CLPressable`), menus morph out of their buttons (`CLMenu`).

## Gallery

```sh
cd packages/claralight_ui_gallery
flutter run -d macos
# hands-free capture helpers:
#   --dart-define=GALLERY_SCROLL=1050     initial scroll offset
#   --dart-define=AUTO_OPEN=dialog|sheet|menu   auto-open a popup demo
```
