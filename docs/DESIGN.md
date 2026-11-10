# Khuta Design Notes (خُطى)

This contract applies to **Classic, Minimal and Express**, in light and dark. Each style keeps its own layout and shape language; this document only fixes what they share. 

## Source of truth

- `mobile/lib/app/theme/khuta_palette.dart` — accent and neutral warming.
- `mobile/lib/app/theme/app_theme.dart` — the three style themes; every neutral goes through the palette.
- `mobile/lib/app/theme/app_fonts.dart` — Arabic font fallback.
- `mobile/lib/core/i18n/digits.dart` — Western digits.
- `mobile/lib/core/calendar/calendar_display.dart` — Hijri/Gregorian day labels.

## Palette — “فخّار هادئ”

| Role | Light | Dark | Notes |
| --- | --- | --- | --- |
| Accent (default) | `#94492F` | `#D7957A` | White text on the light accent 6.46:1; light accent on background 5.45:1; dark accent on dark background 7.54:1. |
| Neutrals | each style's existing grey, moved to hue 28°, saturation 0.28 | hue 28°, saturation 0.10 | Same lightness as before, so each style's hierarchy and contrast are kept. |
| Pure white / black | unchanged | unchanged | The “plain” backgrounds keep their meaning. |
| Semantic | success / warning / danger / info tokens | same | Never replaced by the accent. |
| Entity colours | habit/category colours chosen by the user | same | The identity accent is the first option and the default for new habits. |

Rules:
- Users may pick another accent; the identity accent is the default, not a lock.
- Habit colours drawn as **text or icon ink** go through `context.habitInk(color)` (`lib/app/theme/habit_ink.dart`): on dark surfaces a colour below 3:1 (icons) or 4.5:1 (text) is lightened, and the identity accent maps to its dark variant. Fills and tints keep the stored colour.
- Text and essential UI must meet WCAG AA (4.5:1 for normal text). Check new colour pairs before use.
- Do not hard-code new grey values in feature code; use theme colours so the palette applies.

## Typography

- Latin text keeps each style's family: Figtree (Classic, Minimal), Google Sans Flex (Express), Playfair Display for editorial accents.
- Arabic glyphs always come from **IBM Plex Sans Arabic** (OFL). Every `TextStyle` that sets its own `fontFamily` must also set `fontFamilyFallback: arabicFontFallback`, because such a style replaces the inherited one.

## Accessibility rules

- Every tappable element has a semantic label; icon buttons use `tooltip:` (back and close use `MaterialLocalizations`, which is localized).
- Secondary text (`AppTokens.muted`) is ≥ 4.5:1 on every surface in all three styles, light and dark; `test/a11y_tokens_test.dart` enforces it.
- Tap targets are at least 24 dp (WCAG 2.2 AA) and 48 dp wherever the layout allows; a small icon gets a 48 dp touch area without changing how it looks.
- Narrow columns (week strips, heatmap headers, weekday pickers) use `WeekdayLabels.compact*`, never the plain short names.

## Language, direction and numbers

- Arabic is a first-class language; layouts use directional values (`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start/end`) wherever left and right differ.
- Kept physical on purpose: device safe-area padding, chart time axes (left to right), gradient directions, decorative rotations.
- Arrow and chevron icons use self-mirroring variants (`LucideIcons.*Dir`).
- Digits are Western (0–9) in every locale, including Arabic.
- Arabic copy: simplified Modern Standard Arabic; a streak is “خطوات متتالية”.

## Calendar labels

- Day-level labels follow the user's calendar mode: Gregorian, Hijri, Gregorian + Hijri, or Hijri + Gregorian; Hijri uses Umm al-Qura with a −2…+2 day adjustment.
- Month headers, grids and heatmaps stay Gregorian.
- Habits can be scheduled by Hijri months: the habit editor offers Gregorian or Hijri; Hijri habits are due every day of the chosen months, use the same Umm al-Qura adjustment, and show their schedule as “كل يوم في رمضان” / “Every day in Ramadan”.

## Per style

| Style | Keeps | Identity applied |
| --- | --- | --- |
| Classic | grouped rows, card radius, floating bottom navigation  | warm surfaces, terracotta accent, Arabic font, RTL |
| Minimal | white cards on soft paper, sparse headers | warm paper tones, terracotta accent, Arabic font, RTL |
| Express | expressive shapes, motion, bold type | warm surface containers, terracotta accent, Arabic font, RTL |


## Island art

The gamification island is an Arab oasis drawn by `tools/island_art/` (original project work). Rules: sprite identifiers, file names, pixel sizes and anchors are a contract (pinned by `mobile/test/island_pins_test.dart`); colours come from `tools/island_art/palette.py` (terracotta accent `#94492F`, sand, palm green, mud brick, plaster, turquoise water); visible piece and group names describe the oasis (date palm, minaret, windcatcher…). A file may be replaced by hand-made art under the same name; update `mobile/test/fixtures/island_new_art_sha256.txt` and `docs/ASSETS.md` when that happens.
