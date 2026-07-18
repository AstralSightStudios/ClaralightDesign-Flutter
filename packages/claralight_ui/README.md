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

## Responsive overflow toolbars

`CLOverflowToolbar` keeps fixed-width tools on a `CLToolbar` until the
available width is exhausted, then moves the lowest-priority overflowable
items into a `CLMenu`:

```dart
CLOverflowToolbar<int>(
  items: [
    CLOverflowToolbarItem<int>(
      id: 0,
      extent: 36,
      retention: CLToolbarItemRetention.pinned,
      toolbarBuilder: (_) => CLIconButton(
        icon: Icons.image_outlined,
        onPressed: () {},
      ),
    ),
    CLOverflowToolbarItem<int>(
      id: 1,
      extent: 36,
      retention: CLToolbarItemRetention.overflowable,
      overflowPriority: 0,
      toolbarBuilder: (_) => CLIconButton(
        icon: Icons.auto_awesome_outlined,
        onPressed: () {},
      ),
      overflowBuilder: (context, closeMenu) => CLListTile(
        label: 'Effects',
        onTap: closeMenu,
      ),
    ),
  ],
  overflowTriggerBuilder: (context, hiddenIds, toggle) => CLIconButton(
    icon: Icons.more_horiz,
    selected: hiddenIds.isNotEmpty,
    onPressed: toggle,
  ),
)
```

Each item declares its main-axis `extent` explicitly. That lets visibility be
decided before calling a toolbar builder, avoiding a one-frame overflow and
avoiding hidden focus, hit-test, and semantics nodes. Item IDs remain in their
original logical order in the menu; pinned items are never moved. If even the
pinned items and More trigger cannot fit, the toolbar uses an explicit
horizontal scroll fallback. The More trigger is keyboard focusable and opens
with Enter or Space. Set `overflowEnabled: false` to disable pointer, keyboard,
focus, and trigger semantics together; the trigger builder then receives a
null callback. A custom `toolbarBuilder` must use the same `spacing` and
`horizontalPadding` passed to `CLOverflowToolbar`; those values form the
component's deterministic width-allocation contract.

## Progressive scrolling

Precache the shader shared by `CLScrollable` and `CLList` before the first
frame:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CLScrollable.precache();
  runApp(const App());
}
```

`CLScrollable` supports one or two axes, content padding, per-edge blur and
mask extents, rounded clipping, and independent scrollbar policies:

```dart
SizedBox(
  width: 320,
  height: 240,
  child: CLScrollable(
    direction: CLScrollDirection.both,
    horizontalScrollbar: CLScrollbarVisibility.auto,
    verticalScrollbar: CLScrollbarVisibility.auto,
    padding: const EdgeInsets.all(16),
    borderRadius: BorderRadius.circular(12),
    child: const SizedBox(width: 640, height: 480),
  ),
)
```

Use `CLList`, `CLList.builder`, or `CLList.separated` when the content should
retain `ListView`'s lazy sliver construction:

```dart
SizedBox(
  height: 320,
  child: CLList.builder(
    itemCount: 1000,
    itemExtent: 44,
    padding: const EdgeInsets.symmetric(vertical: 8),
    scrollbarVisibility: CLScrollbarVisibility.auto,
    borderRadius: BorderRadius.circular(12),
    itemBuilder: (context, index) => Text('Item $index'),
  ),
)
```

Every enabled axis must receive bounded constraints unless a `CLList` uses
`shrinkWrap`. If both `CLScrollable` controllers are provided, use a distinct
`ScrollController` for each axis. A zero side in `blurExtent` disables both
blur and masking on that physical edge; a zero side in `blurSigma` disables
blur only. For Flutter web, prefer the Skwasm renderer for this shader-backed
effect.

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
- **Scrolling** — `CLScrollable`, `CLList`, `CLScrollDirection`,
  `CLScrollbarVisibility`
- **Buttons** — `CLButton`, `CLIconButton` (`primary`, `secondary`, `ghost`,
  and red `danger` variants)
- **Controls** — `CLToggle`, `CLSegmentedControl`, `CLSlider`,
  `CLChipTabs`
- **Inputs** — `CLTextField` (`mono:` and external `error:` states),
  `CLSearchField`, `CLSelect`, `CLStepper`, `CLColorPicker`
- **Containers** — `CLPanel`, `CLSectionHeader`, `CLSheet`, `CLDialog`,
  `CLToolbar`, `CLOverflowToolbar`, `CLSideBar`
- **Lists** — `CLTreeView`, `CLListSection`, `CLListTile` (progressive
  scrolling, selection, tree guides, disclosure, tint, `outlined:` add-rows)
- **Menus** — `CLMenu` (morphs out of its anchor with the jelly spring and
  hosts caller-built rows in an internal `CLList`)
- **Indicators** — `CLProgressBar`, `CLProgressRing`, `CLColorSwatchGroup`,
  `CLBanner`, `CLBadge`, `CLDivider` (solid/dashed), `CLTooltip`

Floating layers (menus, popovers, dialogs, sheets, tooltips) are
frosted: a backdrop blur under a translucent `colors.frost` wash.

See `claralight_ui_gallery` for a live showcase of every component.
