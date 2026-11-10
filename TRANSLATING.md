<div align="center">

# Translating Khuta

Translations live in the `.arb` files under `mobile/lib/l10n/`. A hosted
translation platform for this project has not been set up yet; until then,
translations are contributed as edits to those files.

</div>

---

## Language status

Every language has all of the app's strings. English and Arabic are the source
languages. The other fourteen — German, Spanish, Persian, French, Hebrew, Hindi,
Indonesian, Korean, Dutch, Polish, Portuguese, Russian, Ukrainian and Chinese —
are **not yet reviewed by a native speaker**. If you speak one of them, reading
through the file and fixing awkward wording is the most useful contribution.

`tools/l10n/l10n_tool.py check` verifies that no key is missing or blank and that
placeholders match the English source; the same rule runs in the test suite.

## Getting started

1. Pick your language file in `mobile/lib/l10n/` (`app_<language>.arb`). To
   add one that isn't listed, copy `app_en.arb` and translate it.
2. Translate the values, never the keys.
3. Open a pull request. Your work reaches the app in the next release.

> [!TIP]
> **You don't have to finish.** Anything left untranslated simply shows in
>English, so nothing ever breaks. Ten strings today, more whenever you feel
>like it.

> [!IMPORTANT]
> **Adding a new language? Pick the plain language** — "German", "Portuguese",
> "Ukrainian" — not a country-specific variant like "Portuguese (Brazil)".
>The plain form covers everyone who speaks it and keeps the app tidy. Only
>reach for a variant when the split is real and unavoidable — Chinese, for
>example, genuinely divides into Simplified and Traditional.

## Style

- **Address the user informally and directly** — "du" rather than "Sie", "tú"
  rather than "usted".
- **Khuta never nags.** It's calm and encouraging, never guilt-tripping. Keep
  that tone even where a literal translation would sound stern.
- **Use gender-neutral language** wherever your language allows it.
- **Shorter wins.** Most of these phrases sit on buttons, chips and tabs on a
  phone screen. If yours runs much longer than the English, find a tighter
  wording — otherwise it gets cut off.
- **"Khuta" stays "Khuta"** (written “خُطى” in Arabic). The app name isn't translated. The names in the legal notice stay as they are.
- **Leave `{placeholders}` alone.** Anything in curly braces is replaced with a
  real value when the app runs. Move it where your language needs it, but never
  translate or rename it — check that every one is still present in your translation.

## Questions

Not sure how a string is used, or where it appears in the app? Ask in an
[issue](https://github.com/AyoubDroubi/khuta.app/issues) — a screenshot of the screen
you're unsure about is the fastest way to get an answer.

---

<div align="center">

Translations ship under the project's [GNU GPLv3](LICENSE).<br/>
Thank you for making Khuta speak your language.

</div>
