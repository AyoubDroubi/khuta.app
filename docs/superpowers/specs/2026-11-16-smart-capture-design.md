# Smart capture (الإدخال الذكي): design

Status: draft for approval. Date: 2026-11-16.

## Intent and why

The owner wants an assistant inside Khuta that they can talk to the way they talk to a person: "tomorrow I have a meeting at 10, I need to buy a gift, and remind me to call my mother at 5". The assistant reads the sentence, works out what it contains, and turns it into things that already exist in the app (to-dos with a day and time, reminders, notes). The person confirms with one tap.

It is a text-understanding feature only. It does not answer questions, fetch information or give advice, and it only looks at what the person typed (plus names already in the app, such as projects and tags).

Why: entering a to-do today means filling a form (title, date, time, priority, project). Speaking a sentence is faster and fits an Arabic-first, dialect-first app.

## Goals

- One sentence in (typed, or dictated with the keyboard microphone), a list of proposed items out, saved with one tap.
- Understands Levantine Arabic dialect, Modern Standard Arabic and simple English, including mixed sentences.
- Works offline, on the device. No account, no server.
- Fast and exact on the common case: one item with a day, a time and an importance word.
- Optional extra: a small language model, downloaded by the user, makes it understand looser phrasing and split long sentences better.

## Non-goals

- A chatbot, a question answerer, a summarizer or a coach.
- Any network call. The app keeps no Internet permission.
- Automatic saving without confirmation.
- Habits, goals, journeys and focus sessions in the first version (see "Left for later").
- Voice recording inside the app. Dictation comes from the keyboard's microphone.
- Languages other than Arabic and English in the first version.

## Anti-goals (a failure even if it technically works)

- Breaking the privacy promise: adding the Internet permission, sending text anywhere, or logging what the person typed.
- Saving a wrong guess silently. A bad parse must be visible and fixable before anything is stored.
- Making the app heavy for people who never use the feature (large APK, startup cost, background work).
- Inventing details. If the sentence has no day or time, the item has none.

## Constraints

- Local-first, no Internet permission (`docs/ARCHITECTURE.md`). The optional model cannot be downloaded inside the app. The person fetches the file from the project's GitHub Releases in the browser and imports it with the file picker (`file_picker` is already a dependency).
- Storage stays behind `LocalStore`; stored shapes change additively only.
- Items are saved through the existing controllers, so notifications, widgets and backup keep working unchanged.
- The interface is complete right-to-left Arabic with Western digits (0-9), and the same strings exist in all 16 languages (`TRANSLATING.md`, the translation check in the tests).
- The app targets Android 9+ phones, including low-end ones.

## Approaches considered

1. **Rules only** (on-device parser). Tiny, instant, exact on day, time, importance and keywords, easy to test. Cannot split a sentence into several items by itself, and fails on phrasing nobody wrote a rule for.
2. **Language model only.** Handles loose phrasing, but the smallest models that understand dialect are 400 MB to 1.1 GB, are slow on phones, and in the spike they got weekdays wrong (Sunday became Monday) and invented times.
3. **Hybrid.** Rules are built in and always on. The model, if installed, splits the sentence into items and writes titles; rules still decide day, time, importance and item type wherever they can.

**Chosen: 3 (hybrid), shipped in two steps: rules first, model second.** The owner picked it. Rules alone cover the single-item sentences, which are the common case, with nothing to download. The model is added behind the same interface so the preview screen does not change.

## What the spike showed

A throwaway test (24 dialect sentences with hand-written answers; 18 with one item, 6 with several) ran on a 4-core desktop, not a phone. It is a signal, not a guarantee. The sentences and the rules were written by the same person, so the rules' own score is optimistic.

| Model (Q4_K_M) | Size | Result |
| --- | --- | --- |
| Gemma 3 270M | 253 MB | Unusable: copies the example. |
| Qwen2.5 0.5B | 491 MB | Weak at splitting a sentence into items. |
| Qwen3 0.6B | 397 MB | Light; good on time, weaker on day and splitting. |
| Gemma 3 1B | 806 MB | Middling. |
| Qwen2.5 1.5B | 1.1 GB | Best: type 90%, title 90%, time 94%, day 87% (with rules). |

- Asking the model for weekday names directly was unreliable. Asking it to copy the day and time words and converting them with rules worked far better.
- Rules alone scored 100% on the 18 single-item sentences (optimistic, see above).
- About 3.5 s per sentence on desktop with a long instruction; a phone will be slower. The instruction prefix must be short and its processing cached.
- The model never handled a clause like "tomorrow morning: sport, then review the lesson" perfectly (the day was not shared between the two items).

## The design

### Flow

1. A "Quick capture" entry point (a field with a microphone hint, reachable from the Tasks screen and a home shortcut) takes free text.
2. A parser turns the text into a list of **proposed items**.
3. A preview sheet shows each item with its type, title, day and time. Each can be edited, unchecked or removed. One button saves all checked items.
4. Items are written through the existing controllers; nothing is written before the button is pressed.

```
قلت: "الخميس عندي اجتماع الساعة 5 العصر، وبدي أشتري هدية، وذكرني أتصل بأمي"

☑ مهمة   اجتماع          الخميس · 5:00 م
☑ مهمة   شراء هدية        بدون تاريخ
☑ مهمة   اتصل بأمي        اليوم · ⚠ يحتاج وقتاً

[ تعديل ]                       [ حفظ الكل ✓ ]
```

### Proposed item

`ProposedItem { type: task | note, title, day (a date or none), minutes (or none), priority, project and tags (existing ones only, or none), askedToRemind (bool) }`.

Mapping to what exists, with no new storage:

- **task** becomes a `Todo` (`text`, `date` as the app's `dd-MM-yyyy` day key, `minutes`, `priority`, `project`, `tags`).
- **There is no separate reminder type.** The app already schedules a local notification for every not-done to-do that has a date and a time that is still in the future (`ReminderSchedule.todoFireAt`); one without a time, or with a time already passed, schedules nothing. So "remind me" is a to-do with a time. When the sentence says ذكرني or نبهني (`askedToRemind`) and no time was found, the preview marks the item "needs a time" and does not let it be saved until a time is picked or the item is unmarked (it then becomes a plain to-do).
- **note** becomes a new `JournalEntry` through `JournalController.create` for the chosen day (default today). Notes are always added as new entries, never merged into or replacing an existing one. A note carries no priority.

### Parser interface

One interface, `parse(text, now, knownProjects, knownTags) -> List<ProposedItem>`. Implementations:

- **RuleParser** (always on): normalizes Arabic (alef and ya forms, diacritics), finds day words (today, tomorrow, the day after tomorrow, weekday names, English equivalents), times ("الساعة 5 العصر" is 17:00; periods: الصبح, الظهر, العصر, المسا, بالليل; am/pm; spoken numbers), importance words (مهم, ضروري, عاجل; "مش مهم" is low), type words (ذكرني and نبهني set `askedToRemind`; ملاحظة and سجل make a note), and matches known project and tag names. It splits a sentence on clear separators (و before a verb, "وبعدين", "وبعدها", commas) only when each part stands alone.
- **ModelParser** (optional, used only when a model file is installed): asks the model for a list of items, each with a type, a short title, and the exact day, time and importance words copied from the sentence. Rules then convert those words; a word that is not literally in the sentence is discarded. Output is constrained to a fixed JSON shape.
- **Combiner:** the rules parser runs first. If the sentence is a single item the rules result is final. Otherwise, and only when a model is installed, the model's split is used, with every day, time and priority value coming from rules. If no model is installed, the rule splitter's best effort is shown and the person can edit it.

Day resolution always runs in rules code, in the device's time zone, relative to "now". Weekday names are absolute, so the app's week-start setting and the Hijri display setting do not change what a day word means; they only affect how dates are shown. A weekday name means its next occurrence (today only for "today", "اليوم" or "الليلة"). A time that has already passed: with a bare time and no day ("الساعة 5") it rolls to tomorrow; with an explicit "today" it stays today and the preview flags it "time passed" (no notification would fire).

### The optional model

- Format: a quantized GGUF file, run by an on-device inference library (to be chosen by the builder, see below). Nothing is bundled.
- Delivery: manual, from GitHub Releases. Settings has "Smart assistant" with: what it is, which file to download (a button that opens the Releases link in the browser, which needs no permission), an import button, the file size, and a remove button that deletes it.
- Tiers (the owner decides what to publish): a lighter model around 400 MB, and a stronger one around 1.1 GB (Qwen2.5 1.5B was best in the spike). The settings screen shows the file size and warns that it needs more memory.
- The file is validated on import (extension, size, header magic, a SHA-256 shown from the release notes) and stored in the app folder. It is device-only: never included in backups.
- If loading or inference fails, or takes too long, the app falls back to the rules result and says so, it never blocks capture.

### Privacy

No text leaves the device, nothing about it is logged, and the typed sentence is not kept after the sheet closes. The Android manifest keeps no Internet permission; a test asserts that.

### Testing

- Unit tests for the rules with a corpus of dialect sentences in Arabic and English (the spike's 24 are the seed; extend them, and keep them separate from sentences used to write the rules).
- Boundary cases: time zones and daylight saving, midnight ("بكرة الساعة 12 بالليل"), a weekday equal to today, the Hijri setting not affecting the day.
- Tests for the combiner with a fake model parser (valid output, garbage output, a hallucinated day word, a timeout).
- The translation check covers every new string; accessibility checks cover the new sheet.
- A manifest test for the missing Internet permission.
- An opt-in test (not in CI) that runs a real model file against the corpus and reports scores.

## Delivery order

1. RuleParser, preview sheet, saving through existing controllers, tests. Ships on its own.
2. Settings screen for the optional model, import and validation, the inference library, the ModelParser and Combiner, fallback behavior, the opt-in quality test.
3. Publish model files on GitHub Releases with checksums and short instructions.

## Decisions made while reviewing (the owner can change these)

- Rules-only step 1 must split the headline example (three items joined by "و" plus a verb marker, such as وبدي, ولازم, وذكرني, وبعدين). Anything it cannot split is shown as one item the person can edit; that is acceptable, a wrong split is not.
- Quick capture appears in Tasks only in the first version.
- Project and tag names are matched only against existing ones; the parser never creates new ones, and the preview lets the person pick or clear them.
- Model runtime: arm64 only is acceptable; the inference library loads only when the feature is first used. Working target: under about 10 seconds for one sentence on a mid-range phone; slower than that falls back to rules with a visible message. Step 2 begins with a short on-phone measurement before committing to a library and tier.

## Left to the builder

- Which on-device inference library to use (it must work on Android 9+ arm64, add little to the APK, and need no Internet). The spike used llama.cpp on a desktop only; nothing has been tried on a phone.
- Exact entry point placement and wording, within the app's three styles (Classic, Minimal, Express).
- The set of rule keywords beyond those listed, and the sentence-splitting heuristics.
- Prompt wording and prompt caching, to keep model latency acceptable on a phone.
- Memory and speed limits for the model, and whether to unload it after use.

## Left for later

- Habits, goals, journeys and focus sessions as targets.
- Letting the model share one day or time across several items in one clause.
- More languages, and in-app voice.
- A "Khuta Plus" build that downloads the model in-app (would need the Internet permission, so it must stay a separate build if it ever happens).

## Open questions for the owner

- Which model tiers to publish first, and where the files are hosted (GitHub Releases is assumed).
