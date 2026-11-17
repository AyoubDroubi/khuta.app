# Smart Capture (rules, step 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A quick-capture sheet in Tasks where the person types one sentence (Arabic dialect, MSA or simple English), sees proposed items, and saves them with one tap, using only on-device rules.

**Architecture:** A pure-Dart `RuleParser` (normalize, split into clauses, find day/time/importance/type words, build titles) behind an async `CaptureParser` interface so a model parser can be added later. A `CaptureDraft` holds the editable preview; `saveProposedItems` writes through the existing `TodosController` and `JournalController`. The sheet is a thin view over the draft.

**Tech Stack:** Flutter/Dart (SDK ^3.9.2), `provider`, existing `LocalStore`/controllers, `flutter_test`. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-16-smart-capture-design.md`. This plan implements its Delivery step 1 only. Steps 2 and 3 (optional model, settings, releases) get their own plan after the on-phone measurement the spec requires.

**Environment note:** the Flutter SDK is not installed in the planning environment, so none of the code below has been compiled or run. Run everything from `mobile/` with `flutter test <file>`; run `flutter analyze` before each commit.

## Global Constraints

- The Android manifest must not declare `android.permission.INTERNET` (`test/local_first_gate_test.dart` already asserts this; it must stay green).
- No network calls, and the typed sentence is never logged or kept after the sheet closes.
- Nothing is written before the person presses save.
- Storage stays behind `LocalStore`; stored shapes change additively only. This feature adds no new storage.
- Items are saved through `TodosController.create` and `JournalController.create`.
- Complete right-to-left Arabic interface, Western digits (0-9); every new string exists in all 16 `lib/l10n/app_*.arb` files (`test/l10n_complete_test.dart`).
- Android 9+, including low-end phones; the parser is synchronous-cheap pure Dart.
- There is no separate reminder type. A reminder is a to-do with a time. "ذكرني"/"نبهني" set `askedToRemind`; a to-do that asked to be reminded and has no time cannot be saved.
- Day resolution is rules code in the device time zone. Weekday names are absolute (week-start and Hijri settings never change their meaning) and mean the next occurrence; today only for "today", "اليوم", "الليلة".
- A bare time with no day that has already passed rolls to tomorrow. With an explicit "today" it stays today and the item is flagged `timePassed`.
- Notes are always new `JournalEntry` records (kind `moment`), never merged into or replacing one, and carry no priority.
- Projects and labels are `TodoTag` records (`lib/features/todos/data/todo_tag.dart`, `kind` project or label); `Todo.project` and `Todo.tags` store tag **ids**, not names. The parser matches the typed text against existing tag **names** and returns **ids**; it never creates any.
- Quick capture appears in the Tasks screen only.
- Parser limits (this plan's calls, from the spec's "no hang" intent): input is cut to 2000 characters; at most 20 items are returned.

## Review Focus

Each line below has its test in the task named in brackets.

1. Empty, whitespace-only, punctuation-only or emoji-only input gives no items and a "nothing found" message, never an exception. [Task 5, Task 8]
2. A 10,000-character input returns within a bounded time with at most 20 items. [Task 5]
3. The logical-day cutoff hour (`AppClock.cutoffHour`) and daylight-saving days: "today"/"tomorrow" follow the logical day, and a time on a DST-change date still stores plain minutes-from-midnight. [Task 2]
4. Arabic-Indic and Persian digits ("الساعة ٥ العصر"), diacritics, tatweel and alef/ya/ta-marbuta spelling variants all parse like their plain forms. [Task 1, Task 2]
5. Double-tapping save, or one item failing to write, never duplicates items or loses the failed one. [Task 6]

## File Structure

All under `mobile/lib/features/capture/` (tests under `mobile/test/`):

- `data/proposed_item.dart`: `ProposedKind`, `ProposedItem`.
- `data/capture_parser.dart`: `CaptureParser` interface.
- `data/capture_normalize.dart`: `stripMarks`, `foldLetters`.
- `data/capture_when.dart`: day/time finding and resolving.
- `data/capture_words.dart`: priority, remind/note words, known project/tag matching, title building.
- `data/capture_split.dart`: clause splitting.
- `data/rule_parser.dart`: `RuleParser`.
- `state/capture_draft.dart`: editable preview state.
- `state/capture_saver.dart`: `saveProposedItems`.
- `widgets/quick_capture_sheet.dart`: the sheet.
- Modify `lib/features/todos/pages/todos_page.dart` (entry point), `lib/l10n/app_*.arb` (16 files), `docs/ARCHITECTURE.md`.

---

### Task 1: Model, interface, normalization, held-out corpus

**Files:**
- Create: `data/proposed_item.dart`, `data/capture_parser.dart`, `data/capture_normalize.dart`
- Create: `mobile/test/fixtures/capture_spike_cases.json` (move from `docs/superpowers/plans/2026-11-16-smart-capture-spike-cases.json`, then change each `"type":"reminder"` into `"type":"task","remind":true` and add `"remind":false` elsewhere; `kw` stays a word that must appear in the title)
- Create: `mobile/test/fixtures/capture_heldout.json`
- Test: `mobile/test/capture_normalize_test.dart`

**Interfaces:**
- Produces:
  - `enum ProposedKind { task, note }`
  - `class ProposedItem { const ProposedItem({required ProposedKind kind, required String title, DateTime? day, int? minutes, TodoPriority priority = TodoPriority.none, String project = '', List<String> tags = const [], bool askedToRemind = false, bool timePassed = false}); bool get needsTime` (true when `kind == task && askedToRemind && minutes == null`); `ProposedItem copyWith({...all fields, bool clearDay = false, bool clearMinutes = false})`.
  - `abstract interface class CaptureParser { Future<List<ProposedItem>> parse(String text, {required DateTime now, required DateTime today, List<TodoTag> projects = const [], List<TodoTag> labels = const []}); }` where `now` is `AppClock.wallNow()` and `today` is `AppClock.today()`.
  - `String stripMarks(String s)`: removes U+064B-U+065F, U+0670 and tatweel U+0640 (changes length; applied to the original text once, first).
  - `String foldLetters(String s)`: lower-cases, maps أ إ آ ٱ to ا, ى to ي, ة to ه, Arabic-Indic and Persian digits to 0-9; **always the same length as its input**, so indices found in the folded text cut the unfolded text.

- [ ] **Step 1: Write the held-out corpus before any rule code.** At least 20 new sentences (not paraphrases of the spike ones), same shape as the spike file (`t`, `g: [{type, remind, kw, day, time, prio}]`, `day` in `today|tomorrow|day_after_tomorrow|mon..sun|""`, `time` as `HH:MM` or `""`). Cover: at least 6 multi-item sentences; Arabic-Indic digits; diacritics; "الساعة 12 بالليل"; a weekday that equals today; a bare time (no day); a time with an English "pm"; a note sentence; an importance word. Rule: do not change an expected value after seeing a failure unless the expectation itself was wrong, and say so in the commit message.
- [ ] **Step 2: Move the spike file into `test/fixtures/` and convert it as described above.**
- [ ] **Step 3: Write the failing test** `capture_normalize_test.dart`:
  - `stripMarks('مُحَمَّد')` equals `'محمد'`; `stripMarks('كتــاب')` equals `'كتاب'`.
  - `foldLetters('الأحد إلى آخر ٥ ۵ ة ى')` equals `'الاحد الي اخر 5 5 ه ي'`.
  - A loop over 50 mixed strings asserts `foldLetters(s).length == s.length`.
  - `ProposedItem(kind: ProposedKind.task, title: 'x', askedToRemind: true).needsTime` is true; with `minutes: 600` it is false; for `ProposedKind.note` it is always false.
- [ ] **Step 4: Run** `flutter test test/capture_normalize_test.dart`. Expected: FAIL (files missing).
- [ ] **Step 5: Implement the files above.**
- [ ] **Step 6: Run the test.** Expected: PASS.
- [ ] **Step 7: Commit** (`feat(capture): proposed item model and Arabic normalization`; commit the held-out corpus in this same commit).

---

### Task 2: Day and time rules

**Files:**
- Create: `data/capture_when.dart`
- Test: `mobile/test/capture_when_test.dart`

**Interfaces:**
- Consumes: `foldLetters` output (callers pass folded text).
- Produces:
  - `enum DayWord { today, tomorrow, dayAfterTomorrow, sunday, monday, tuesday, wednesday, thursday, friday, saturday }`
  - `class WhenMatch { final DayWord? day; final int? minutes; final bool midnightNight; final List<(int, int)> spans; }` where `spans` are `[start, end)` ranges in the folded text to cut from the title.
  - `WhenMatch findWhen(String folded)`
  - `class ResolvedWhen { final DateTime? day; final int? minutes; final bool timePassed; }`
  - `ResolvedWhen resolveWhen(WhenMatch m, {required DateTime today, required DateTime now})`

- [ ] **Step 1: Write the failing tests** (`capture_when_test.dart`), calling `findWhen(foldLetters(x))` then `resolveWhen` with `today = DateTime(2026, 11, 16)` (a Monday) and `now = DateTime(2026, 11, 16, 9, 0)` unless stated:
  - Day words: بكرة and بكره and tomorrow → tomorrow (17 Nov); بعد بكرة → day after tomorrow (18 Nov) and **not** tomorrow; اليوم, الليلة, today → 16 Nov; الخميس → 19 Nov; الاثنين (same weekday as today) → 23 Nov; الأحد → 22 Nov; "يوم الخميس" same as الخميس.
  - Times: "الساعة 10 الصبح" → 600; "الساعة 5 العصر" → 1020; "الساعة 8 بالليل" → 1200; "الساعة 7 المسا" → 1140; "الساعة 12 الظهر" → 720; "الساعة 3 العصر" → 900; "الساعة 6 الصبح" → 360; "at 2 pm" → 840; "2 pm" → 840; "الساعة 9:30 الصبح" → 570; "الساعة ٥ العصر" → 1020; "الساعة تسعة الصبح" → 540; "الساعة ثمانية بالليل" → 1200; bare "الساعة 5" → 300 (the preview shows it; no period guessed); "الساعة 25" and "الساعة 10:75" → no time.
  - Midnight: "بكرة الساعة 12 بالليل" → minutes 0 on **18 Nov** (the night belonging to the named day); bare "الساعة 12 بالليل" with `today` 16 Nov → 17 Nov, minutes 0.
  - Passed-time rule: bare "الساعة 5 العصر" at `now` 18:00 → day 17 Nov, `timePassed` false; "اليوم الساعة 5 العصر" at 18:00 → day 16 Nov, `timePassed` true; at 09:00 → 16 Nov, `timePassed` false; weekday + time never sets `timePassed`.
  - Spans: for "بكرة الساعة 10 الصبح" the spans cover both phrases.
  - Review Focus 3: with `AppClock.cutoffHour = 3`, `today = DateTime(2026,11,15)` (logical) and `now = DateTime(2026,11,16,1,0)`: "اليوم" → 15 Nov, "بكرة" → 16 Nov, bare "الساعة 5 العصر" → 16 Nov. On a DST-change date (use 2026-03-29 for Europe/Berlin-like zones; assert only on the returned `minutes`) a time of "الساعة 2:30 الصبح" still returns 150.
- [ ] **Step 2: Run** `flutter test test/capture_when_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** Day match order: dayAfterTomorrow before tomorrow before today before weekdays. Period table: الصبح/صباحا/الفجر and `am` = morning (12 becomes 0); الظهر/الضهر = hours 1-5 get +12, 12 stays; العصر/المسا/مساء/بالليل/الليل and `pm` = hours below 12 get +12; "12 بالليل"/"12 الليل" sets `midnightNight`, minutes 0. Spoken hour words واحدة through اثنتا عشرة (with the common dialect spellings) map to 1-12. Weekday resolution: `today + ((weekday - today.weekday + 7) % 7 == 0 ? 7 : that)`. Candidate time for the passed check is `today.add(Duration(minutes: m))` compared with `now`.
- [ ] **Step 4: Run the tests.** Expected: PASS.
- [ ] **Step 5: Commit** (`feat(capture): day and time rules`).

---

### Task 3: Priority, type words, known names, titles

**Files:**
- Create: `data/capture_words.dart`
- Test: `mobile/test/capture_words_test.dart`

**Interfaces:**
- Consumes: `foldLetters`, `WhenMatch.spans` from Task 2.
- Produces:
  - `TodoPriority findPriority(String folded)`: low wins over high.
  - `bool asksToRemind(String folded)`; `bool isNote(String folded)`
  - `({String project, List<String> tags}) matchKnown(String folded, {required List<TodoTag> projects, required List<TodoTag> labels})`: the **id** of the first project whose name occurs, the ids of all labels whose names occur; names are compared after `foldLetters`; returns `''`/empty when none.
  - `String buildTitle(String clause, List<(int, int)> cutSpans)`: `clause` is the stripped (unfolded) clause; removes the spans, importance words, type words (ذكرني, نبهني, سجل, ملاحظة and its colon, "remind me to"), and leading fillers (بدي, لازم, عندي, "I need to"); collapses spaces; trims edge punctuation; returns `''` if nothing is left.

- [ ] **Step 1: Write the failing tests:**
  - `findPriority`: "اجتماع مهم" → high; "ضروري جدا" → high; "عاجل" → high; "urgent" → high; "مش مهم" → low; "لو فضيت بدي أرتب" → low; "اجتماع" → none; "مش مهم بس ضروري" → low.
  - `asksToRemind`: "ذكرني أتصل" and "نبهني" and "remind me" → true; "اتصل" → false. `isNote`: "ملاحظة: فكرة" and "سجل ملاحظة" and "note:" → true.
  - With `projects: [TodoTag(id: 'p1', name: 'مشروع البيت', kind: TodoTagKind.project, ...)]` and `labels: [TodoTag(id: 'l1', name: 'عاجل', ...)]`, `matchKnown('شغل مشروع البيت', ...)` → project `'p1'`, no tags; text naming neither returns `''` and empty; an unknown name never produces an id.
  - `buildTitle`: "ذكرني أتصل بأمي" with no spans → "أتصل بأمي"; "بكرة عندي اجتماع الساعة 10 الصبح" with the spans from `findWhen` → contains "اجتماع" and not "بكرة"; "ضروري جدا أخلص تقرير المشروع اليوم" → contains "تقرير" and not "ضروري"; "ملاحظة: فكرة تطبيق للتوصيل" → "فكرة تطبيق للتوصيل"; a clause that is only "بكرة" → `''`.
- [ ] **Step 2: Run** `flutter test test/capture_words_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** Keyword tables are stored already folded (build them with `foldLetters` once). Matching uses word boundaries so "مهم" inside "مهمة" (task) is not an importance word.
- [ ] **Step 4: Run the tests.** Expected: PASS.
- [ ] **Step 5: Commit** (`feat(capture): priority, type words and title building`).

---

### Task 4: Clause splitter

**Files:**
- Create: `data/capture_split.dart`
- Test: `mobile/test/capture_split_test.dart`

**Interfaces:**
- Produces: `List<String> splitClauses(String text)` (text already stripped of marks; returns unfolded clauses in order; at most 20).

- [ ] **Step 1: Write the failing tests:**
  - Splits on `،` `,` `;` `؛` and newlines: "اشتري خبز، اتصل بأمي" → 2 clauses.
  - Splits before a conjunction + marker: "وبدي", "ولازم", "وذكرني", "ونبهني", "وبعدين", "وبعدها", "ثم", "and remind me": the headline "الخميس عندي اجتماع الساعة 5 العصر، وبدي أشتري هدية، وذكرني أتصل بأمي" → 3 clauses, and the leading connective is dropped from each part.
  - Does **not** split a lone "و": "بدي أدفع القسط وأجدد الإقامة وأشتري خبز" is allowed to stay one clause or split into three, but never into a clause shorter than 2 words; "ملح وفلفل" stays one clause.
  - "Tomorrow at 2 pm call the bank and remind me to send the report" → 2 clauses.
  - Empty, spaces-only and "،،،" → empty list; 10,000 characters → at most 20 clauses.
- [ ] **Step 2: Run** `flutter test test/capture_split_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** with a single regex pass, then merge any part with fewer than 2 words into its neighbour. A wrong split is worse than no split: when in doubt, do not split.
- [ ] **Step 4: Run the tests.** Expected: PASS.
- [ ] **Step 5: Commit** (`feat(capture): clause splitter`).

---

### Task 5: RuleParser and corpus tests

**Files:**
- Create: `data/rule_parser.dart`
- Test: `mobile/test/rule_parser_test.dart`

**Interfaces:**
- Consumes: Tasks 1-4.
- Produces: `class RuleParser implements CaptureParser` (const constructor, no state).

- [ ] **Step 1: Write the failing tests** in `rule_parser_test.dart`, using `useEmptyStore()` only if the parser touches nothing else (it should not), with `today = DateTime(2026,11,16)`, `now = DateTime(2026,11,16,9,0)`:
  - Headline: the three-item sentence from the spec yields exactly three items: a task whose title contains "اجتماع", day 19 Nov, minutes 1020; a task containing "هدية" with no day; a task containing "أتصل", `askedToRemind` true, minutes null, `needsTime` true, day null.
  - Corpus: for each case in `capture_spike_cases.json` and `capture_heldout.json`, count equals the expected count and every item's kind (note vs task), `remind`, day, minutes and priority match, and the title contains `kw` (compare folded). Cases that still fail after the rules are finished go in a `knownMisses` list in the test file with a one-line reason each; the headline sentence and every single-item sentence must **not** be in it.
  - Note: "سجل ملاحظة: فكرة تطبيق للتوصيل للقرى" → one `ProposedKind.note` with priority none.
  - Known names: with a project tag named "البيت" (id `p1`), "بكرة أنظف البيت" sets `project: 'p1'`; a project that does not exist never appears.
  - Review Focus 1: `''`, `'   '`, `'،،،'`, `'!!!'`, `'😀😀'` → empty list, no exception. Review Focus 2: `'اشتري خبز، ' * 1500` returns at most 20 items and finishes inside 2 seconds (`Stopwatch`). Review Focus 4: the same sentence with diacritics, Arabic-Indic digits and ة/ه variants yields identical day, minutes and priority as its plain form.
- [ ] **Step 2: Run** `flutter test test/rule_parser_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement `RuleParser.parse`:** cut input to 2000 characters; `stripMarks`; `splitClauses`; per clause: `foldLetters`, `findWhen`, `resolveWhen`, `findPriority`, `asksToRemind`, `isNote`, `matchKnown`, `buildTitle`; drop items with an empty title; kind `note` clears priority; stop at 20 items.
- [ ] **Step 4: Run the tests.** Expected: PASS (only the allowed `knownMisses` skipped).
- [ ] **Step 5: Commit** (`feat(capture): rule parser`).

---

### Task 6: Draft state and saving

**Files:**
- Create: `state/capture_draft.dart`, `state/capture_saver.dart`
- Test: `mobile/test/capture_saver_test.dart`

**Interfaces:**
- Consumes: `ProposedItem`, `TodosController.create(...)` (`text`, `date` as `dd-MM-yyyy` day key or `''`, `minutes`, `priority`, `tags` and `project` as tag ids), `JournalController.create(date, kind: JournalEntryKind.moment, text)`.
- Produces:
  - `class CaptureSaveResult { final List<ProposedItem> saved; final List<ProposedItem> failed; }`
  - `Future<CaptureSaveResult> saveProposedItems(List<ProposedItem> items, {required TodosController todos, required JournalController journal, required DateTime today})`: throws `StateError` **before writing anything** if any item `needsTime`; a note's date is `(day ?? today).dayKey`; a failed write is caught and reported in `failed`, and the remaining items are still attempted.
  - `class CaptureDraft extends ChangeNotifier`: `CaptureDraft(List<ProposedItem> items)`; `List<({ProposedItem item, bool checked})> get rows`; `void toggle(int i)`; `void remove(int i)`; `void retitle(int i, String title)`; `void setDay(int i, DateTime? day)`; `void setMinutes(int i, int? minutes)`; `void clearProject(int i)`; `void unmarkRemind(int i)` (sets `askedToRemind` false); `bool get saveBlocked` (any checked item needs a time, or nothing is checked); `bool get saving`; `Future<CaptureSaveResult?> save({required TodosController todos, required JournalController journal, required DateTime today})` returns `null` if already saving, removes saved rows and keeps failed rows.

- [ ] **Step 1: Write the failing tests** with `useEmptyStore()`:
  - A task with day 19 Nov, minutes 1020, priority high is stored as a `Todo` with `date == '19-11-2026'`, `minutes == 1020`, high priority (read back through a new `TodosController()`).
  - A note creates a `JournalEntry` (kind `moment`) on today's key; saving a second note on the same day leaves two entries and edits no existing one.
  - An item that `needsTime` throws `StateError` and **nothing** is stored, even for the other items in the same call.
  - Review Focus 5: calling `draft.save(...)` twice without awaiting stores each item once and the second call returns `null`; with a journal controller whose `create` throws for one item, that item is in `failed` and stays in `draft.rows`, the others are saved and removed.
  - `saveBlocked` is true when a checked item needs a time, false after `setMinutes` or `unmarkRemind`, and true when no row is checked; unchecked items are never saved.
- [ ] **Step 2: Run** `flutter test test/capture_saver_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** both files; the saver validates first, then writes sequentially.
- [ ] **Step 4: Run the tests.** Expected: PASS.
- [ ] **Step 5: Commit** (`feat(capture): draft state and saving through existing controllers`).

---

### Task 7: Strings in all 16 languages

**Files:**
- Modify: `mobile/lib/l10n/app_en.arb`, `app_ar.arb` and the other 14 `app_*.arb`
- Test: existing `test/l10n_complete_test.dart`

**Interfaces:**
- Produces these keys (English / Arabic), used by Task 8:
  - `capture_title`: "Quick capture" / "إدخال سريع"
  - `capture_hint`: "Write what you need to do, in your own words" / "اكتب ما تريد فعله بكلماتك"
  - `capture_find`: "Find items" / "استخراج"
  - `capture_nothing`: "Nothing found. Try adding what to do and when." / "لم أجد شيئاً. اكتب ما تريد فعله ومتى."
  - `capture_save_count` with `{count}` (use the same plural style the ARB files already use for counts): "Save {count}" / "حفظ {count}"
  - `capture_needs_time`: "Needs a time" / "يحتاج وقتاً"
  - `capture_time_passed`: "Time has passed" / "الوقت مضى"
  - `capture_note`: "Note" / "ملاحظة"
  - `capture_no_date`: "No date" / "بدون تاريخ"
  - `capture_remove_reminder`: "Not a reminder" / "ليس تذكيراً"
  - `capture_save_failed`: "Some items could not be saved" / "تعذّر حفظ بعض العناصر"

- [ ] **Step 1: Run** `flutter test test/l10n_complete_test.dart` after adding the English and Arabic keys only. Expected: FAIL for the other 14 languages.
- [ ] **Step 2: Add all keys to the other 14 files** with real translations (not English copies; they are marked unreviewed in `TRANSLATING.md`), following `tools/l10n/l10n_tool.py missing <lang>` and `merge <lang> <file.json>`.
- [ ] **Step 3: Run** `python3 tools/l10n/l10n_tool.py check` and `flutter gen-l10n`, then `flutter test test/l10n_complete_test.dart`. Expected: PASS.
- [ ] **Step 4: Commit** (`feat(capture): strings in all languages`).

---

### Task 8: Sheet, entry point, docs

**Files:**
- Create: `widgets/quick_capture_sheet.dart`
- Modify: `lib/features/todos/pages/todos_page.dart` (a header action in the app bar `actions` list near line 221, per the spec's "placement is the builder's call within the three styles"), `docs/ARCHITECTURE.md` (a short "Smart capture" section: where it lives, that it is rules-only, that nothing is saved before the button, that no text is kept or logged)
- Test: `mobile/test/quick_capture_sheet_test.dart`, `mobile/test/capture_privacy_test.dart`

**Interfaces:**
- Consumes: `RuleParser`, `CaptureDraft`, the Task 7 strings, `TodosController`, `JournalController`, `TodoTagsController` (`projects` and `labels` getters, both `List<TodoTag>`; `resolve(ids)` gives names for display), `AppClock.wallNow()` and `AppClock.today()`.
- Produces: `Future<void> showQuickCapture(BuildContext context)` (a bottom sheet on phones, a pane/page on wide layouts like `showTodoComposer`). Widget keys: `Key('capture_input')`, `Key('capture_find')`, `Key('capture_save')`, rows `ValueKey('capture_row_$i')`. A semantic label `capture_title` on the entry button.

- [ ] **Step 1: Write the failing tests** (`testWidgets`, `useEmptyStore()`, `pumpScreen(tester, const TodosPage())`):
  - Tapping the entry opens the sheet; entering the headline sentence and tapping find shows three rows; the third row shows the "needs a time" mark and Save is disabled; tapping "not a reminder" on it enables Save labelled with 3; saving stores 3 to-dos (read from `TodosController`) and closes the sheet.
  - Unchecking a row and removing another leaves one saved item.
  - Entering "!!!" and tapping find shows the "nothing found" text and no rows; Save is disabled.
  - Nothing is stored before Save (assert the controller is empty after find).
  - Tapping Save twice quickly stores each item once.
  - The sheet in the Arabic locale is right-to-left and shows Western digits; the day shows as a date and time as 12-hour with a period.
  - `capture_privacy_test.dart`: scan every `.dart` file under `lib/features/capture/` and fail on `print(`, `debugPrint(`, `log(`, `http`, `dart:io` `HttpClient`/`Socket`, or any use of `SharedPreferences`/`LocalStore` write APIs.
- [ ] **Step 2: Run** `flutter test test/quick_capture_sheet_test.dart test/capture_privacy_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement the sheet** as a thin view of `CaptureDraft`: input (cap 2000 characters), find button, editable rows (checkbox, title field, day chip opening `showDatePicker`, time chip opening `showTimePicker`, project/tag chips with a clear action, "needs a time" and "time passed" marks, remove), Save button disabled by `saveBlocked`, `capture_save_failed` snackbar when `failed` is not empty. The typed text and draft live only in the sheet's state and are dropped when it closes.
- [ ] **Step 4: Run these plus** `flutter test test/local_first_gate_test.dart test/l10n_complete_test.dart test/a11y_guidelines_test.dart test/arabic_locale_test.dart`, then `flutter analyze`. Expected: all PASS, no analyzer issues.
- [ ] **Step 5: Run the whole suite** `flutter test`. Expected: PASS.
- [ ] **Step 6: Commit** (`feat(capture): quick capture sheet in Tasks`).

---

## Self-review notes

- Spec coverage: flow, preview, mapping to `Todo`/`JournalEntry`, no reminder type, rules (days, times, passed time, midnight, importance, type words, known names, splitting), headline-example split, Tasks-only entry, privacy and manifest gate, tests (corpus plus held-out, boundaries, privacy), and Delivery step 1 are covered. The optional model, import/validation, settings screen, fallback, Combiner, the opt-in model quality test and the Releases publishing (spec steps 2 and 3) are deliberately outside this plan.
- Corrected during self-review: projects and labels are tag ids, not names (see Global Constraints and Tasks 1, 3, 5, 8).
- Calls made in this plan (change if wrong): bare "الساعة 5" with no period is kept literally as 05:00 (the preview shows it); "12 بالليل" is midnight at the start of the day **after** the named day; input cap 2000 characters and 20 items; the quick-capture button lives in the Tasks app bar.
- Not verified: no Dart was compiled or run while writing this plan; signatures follow the existing controller code read during planning (`TodosController.create`, `JournalController.create`, `AppClock`, `dayKey`).
