# Bundled fonts

All bundled fonts are free for commercial use and redistribution.

| Family | Files | Role | Source / License |
| --- | --- | --- | --- |
| MiSans | MiSans-{Regular,Medium,Demibold,Semibold}.ttf | UI text (Chinese + Latin) | [hyperos.mi.com/font](https://hyperos.mi.com/font) — MiSans 字体知识产权许可协议 (free commercial use & redistribution) |
| Sarasa Mono SC | SarasaMonoSC-{Regular,SemiBold}.ttf | Monospace values & units (尺寸, 内存占用, 时间码) | [be5invis/Sarasa-Gothic](https://github.com/be5invis/Sarasa-Gothic) v1.0.40 — SIL OFL 1.1 |
| ChillDINGothic | ChillDINGothic_Bold.otf | Display headings (DIN-flavored gothic) | [Warren2060/ChillDIN-ChillDINGothic](https://github.com/Warren2060/ChillDIN-ChillDINGothic) v1.300 — SIL OFL 1.1 |

Weight mapping in `pubspec.yaml`: MiSans Demibold → w600,
MiSans Semibold → w700 (Flutter has no w650 step).
