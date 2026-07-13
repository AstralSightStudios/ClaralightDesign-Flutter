# Bundled fonts

All bundled fonts are free for commercial use and redistribution.
Flutter font assets must be TTF/OTF (woff2 is web-only), so size is
managed with a variable font and subsetting instead.

| Family | Files | Role | Source / License |
| --- | --- | --- | --- |
| MiSans | MiSansVF.ttf (variable, wght 150–700) | UI text (Chinese + Latin) | [hyperos.mi.com/font](https://hyperos.mi.com/font) — MiSans 字体知识产权许可协议 (free commercial use & redistribution) |
| Sarasa Mono SC | SarasaMonoSC-{Regular,SemiBold}.ttf (**subset to Latin-1 + common punctuation**; CJK falls back to MiSans) | Monospace values & units (尺寸, 内存占用, 时间码) | [be5invis/Sarasa-Gothic](https://github.com/be5invis/Sarasa-Gothic) v1.0.40 — SIL OFL 1.1 |
| ChillDINGothic | ChillDINGothic_Bold.otf | Display headings (DIN-flavored gothic) | [Warren2060/ChillDIN-ChillDINGothic](https://github.com/Warren2060/ChillDIN-ChillDINGothic) v1.300 — SIL OFL 1.1 |
| Clara Serif Pro | ClaraSerifPro.ttf (single Medium weight) | Optional serif; not in the default ramp — reference via `CLTypography.serifFamily` | bundled with Claralight |

## MiSans VF weight axis (non-standard!)

The named instances do not sit at CSS-standard positions. `CLTypography`
maps `FontWeight` onto the axis:

| FontWeight | axis `wght` | MiSans instance |
| --- | --- | --- |
| w400 | 330 | Regular |
| w500 | 380 | Medium |
| w600 | 450 | Demibold |
| w700 | 520 | Semibold |

Changing weight on a ClaraLight text style must go through
`style.withCLWeight(FontWeight.w600)` (or set `fontVariations` yourself) —
a bare `copyWith(fontWeight:)` does not move a variable font's axis.
