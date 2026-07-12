## Unreleased

* Added `CLControlSize.controlHeight` as the shared 28/36/44px control
  height contract. `CLButton`, `CLIconButton`, `CLTextField`, and `CLSelect`
  now use it; `CLButton.large` is 44px tall instead of 48px.
* `CLToolbar` gained a standard `size` and passes it to `CLButton` and
  `CLIconButton` descendants that do not specify their own size. A custom
  `height` continues to override only the toolbar capsule height.

## 0.2.0

Aligned with the ClaraLight Figma design source (Facetory demo).

* `CLButton` and `CLIconButton` now share semantic `primary` (blue) and
  `danger` (red) variants.
* `CLIconButton` gained `CLIconButtonVariant.ghost`: transparent at rest,
  with the standard control highlight on hover.
* Fixed bundled fonts not loading: package fonts must be referenced as
  `packages/claralight_ui/<family>`; without the prefix every style fell
  back to system fonts (wrong weights, no monospace).
* Frosted floating layers: `CLSurface.frosted` backdrop-blurs behind
  menus, select popovers, dialogs, sheets and tooltips (`colors.frost`).
* Reworked the `CLPressable` press glow: painted as a true circle in
  pixel space that tracks the pointer exactly, much wider and dimmer so
  it reads as diffused light instead of a spotlight.
* New `CLColorPicker` (+`CLColorPicker.show`): SV area, hue bar, hex
  field and preset swatches.
* New `CLTooltip` (hover / long-press frosted label) and `CLChipTabs`
  (the "时间日期 / 运动健康 / 工具数据" filter chips).
* Reworked `CLMenu` as an animated shell around an internal `CLList`.
  Callers now provide arbitrary `children` instead of `CLMenuAction` /
  `CLMenuGroup`, and can use `CLMenuController` for explicit open/close
  behavior. Content is measured before the existing unfurling morph, so
  custom rows stay at their final size and are never squashed.
* Fonts slimmed from 86MB to 26MB: MiSans ships as a single variable
  font (`CLTypography.miSansWght` maps `FontWeight` onto its
  non-standard wght axis; use `style.withCLWeight(...)` to change
  weights) and Sarasa Mono SC is subset to Latin-1 (CJK falls back to
  MiSans). Flutter cannot load woff2 assets, so VF + subsetting is the
  size lever.
* Dialog dismissal melts smoothly (full-range fade + accelerating
  shrink) instead of hanging and blinking off.
* Concentric corners in dialogs: `CLColorPicker` inner elements default
  to the medium radius (`cornerRadius:` to tune) and `CLTextField`
  gained `borderRadius:`.
* `CLPressable` gained `pressedTint`: a flat wash under the pointer glow
  so ghost/toolbar buttons show a clear pressed boundary.
* `CLToolbar` default padding is now 4, matching the vertical inset of a
  medium control so content sits optically centered.

* Bundled fonts: MiSans (4 weights), Sarasa Mono SC (2 weights),
  ChillDINGothic Bold; `CLTypography` gained `mono`, `monoStrong` and a
  DIN `display` style.
* Every corner is now a smooth rounded superellipse (`clSmoothShape`,
  `clSmoothDecoration`, `ClipRSuperellipse`).
* Retuned `CLColorScheme` to the Figma variables: #191919 background,
  translucent white-alpha control fills, `textHint`, `outlineStrong`,
  `accentBackground`, `dangerBackground`, `scrim`; accent is now #0090FF.
* `CLToggle` matches the design geometry: 48x24 outlined track, 28x20
  thumb that solidifies as it turns on.
* New `CLDialog` (+`CLDialog.show`): radius-36 modal with equally-divided
  action row and spring pop-in.
* New `CLMenu`: the morph-out-of-the-button popup (jelly spring +
  pointer-following glow) re-skinned flat.
* `CLListTile` gained `outlined:` ("新增样式" add rows) and design row
  metrics; `CLDivider` gained `dashed:`; `CLBadge` gained `unit:` and
  monospace values; `CLTextField` gained `mono:`.
* Disabled buttons drop their variant color instead of dimming it.

## 0.1.0

The Claralight reform: a flat layered design language.

* New theme system: `CLTheme` / `CLThemeData` with `CLColorScheme` (dark +
  light), `CLTypography`, `CLRadii`, `CLSpacing`.
* New foundation widgets: `CLSurface` (layered opaque fills) and
  `CLPressable` (springy press + jelly drag on any surface).
* Reworked to the flat Claralight base: `CLButton` (primary / secondary /
  ghost / danger, three sizes, content-hugging), `CLIconButton` (circle /
  rounded, selected state), `CLToggle` (draggable spring thumb),
  `CLSideBar`.
* New components: `CLSegmentedControl`, `CLSlider`, `CLTextField`,
  `CLSearchField`, `CLSelect`, `CLStepper`, `CLPanel`, `CLSectionHeader`,
  `CLSheet` (+ `CLSheet.show`), `CLToolbar`, `CLListSection`, `CLListTile`,
  `CLColorSwatchGroup`, `CLProgressBar`, `CLProgressRing`, `CLBanner`,
  `CLBadge`, `CLDivider`.
* Removed all liquid glass (native and simulated) along with `Glass`,
  `InteractiveGlass`, `CLLiquidMenu` and the `liquid_glass_renderer`
  dependency: the flat rendition is the design.

## 0.0.1

* Initial liquid-glass component set: `Glass`, `InteractiveGlass`,
  `CLButton`, `CLIconButton`, `CLToggle`, `CLSideBar`, `CLLiquidMenu`.
