# claralight_ui

**ClaraLight** — a quiet, layered dark design language for Flutter,
matching the ClaraLight Figma source (the Facetory demo app).

Translucent white-alpha control fills stacked over deep layered surfaces,
smooth superellipse corners everywhere, sparing accent color, springy
press physics. Pure Dart — it works identically on every platform with
zero native code.

## Quick start

```dart
import 'package:claralight_ui/claralight_ui.dart';

CLTheme(
  data: CLThemeData(), // dark ClaraLight scheme by default
  child: MaterialApp(...),
)
```

Widgets also work without an ancestor `CLTheme` by falling back to the
default dark theme.

## Bundled fonts

Three free-for-commercial-use families ship with the package (see
`fonts/FONTS.md` for licenses) and are pre-wired into `CLTypography`:

- **MiSans** (Regular/Medium/Demibold/Semibold) — all UI text
- **Sarasa Mono SC** (Regular/SemiBold) — `typography.mono` /
  `monoStrong` for values and units (`368KB/1024KB`, `78x91px`)
- **ChillDINGothic** (Bold) — `typography.display` for large headings

## Design rules

- **Corners are smooth.** Every rounded corner is a rounded
  superellipse (`clSmoothShape` / `clSmoothDecoration` /
  `ClipRSuperellipse`), never a plain circular arc.
- **Fills are layers.** Controls use translucent white overlays
  (`colors.control` = 10% white, `controlHighlight` = 15%) so the same
  component reads correctly on any surface.
- **Springy physics.** Presses scale with overshoot, drags deform like
  jelly (`CLPressable`), menus morph out of their buttons.

## Components

- **Theme** — `CLTheme`, `CLThemeData`, `CLColorScheme`, `CLTypography`,
  `CLRadii`, `CLSpacing`
- **Surfaces** — `CLSurface` (layered fills), `CLPressable` (springy press
  scale, jelly drag, pointer highlight)
- **Buttons** — `CLButton`, `CLIconButton`
- **Controls** — `CLToggle`, `CLSegmentedControl`, `CLSlider`,
  `CLChipTabs`
- **Inputs** — `CLTextField` (`mono:` for numeric fields),
  `CLSearchField`, `CLSelect`, `CLStepper`, `CLColorPicker`
  (+`CLColorPicker.show`)
- **Containers** — `CLPanel`, `CLSectionHeader`, `CLSheet`, `CLDialog`,
  `CLToolbar`, `CLSideBar`
- **Lists** — `CLListSection`, `CLListTile` (selection, tree indent,
  disclosure, `outlined:` add-rows)
- **Menus** — `CLMenu` (morphs out of its anchor with the jelly spring;
  pointer-following glow)
- **Indicators** — `CLProgressBar`, `CLProgressRing`, `CLColorSwatchGroup`,
  `CLBanner`, `CLBadge`, `CLDivider` (solid/dashed), `CLTooltip`

Floating layers (menus, popovers, dialogs, sheets, tooltips) are
frosted: a backdrop blur under a translucent `colors.frost` wash.

See `claralight_ui_gallery` for a live showcase of every component.
