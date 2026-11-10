import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:khuta/core/calendar/hijri_schedule.dart';
import 'package:khuta/core/utils/app_dirs.dart';
import 'package:khuta/features/habits/data/category.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/focus/data/focus_session.dart';
import 'package:khuta/features/daily_plan/data/daily_plan.dart';
import 'package:khuta/features/habits/data/habit_note.dart';
import 'package:khuta/features/journal/data/journal_entry.dart';
import 'package:khuta/features/journeys/data/journey.dart';
import 'package:khuta/features/goals/data/goal.dart';
import 'package:khuta/features/todos/data/todo.dart';
import 'package:khuta/features/todos/data/todo_tag.dart';

class LocalStore {
  const LocalStore._();

  static const _habitsBox = 'habits';
  static const _settingsBox = 'settings';
  static const _categoriesBox = 'categories';
  static const _notesBox = 'notes';
  static const _focusBox = 'focus';
  static const _todosBox = 'todos';
  static const _todoTagsBox = 'todo_tags';
  static const _journeysBox = 'journeys';
  static const _goalsBox = 'goals';
  static const _journalEntriesBox = 'journal_entries';
  static const _dailyPlansBox = 'daily_plans';
  static const _syncBox = 'sync_state';

  static const _localOnlySettings = <String>{
    'profilePhoto',
    'bgImage',
    'focusImage',
    'focusImages',
    'focusTracks',
    'focusTrack',
    'autoBackup',
    'autoBackupFolder',
    'autoBackupAt',
    'readableCopy',
    'folderSeenAt',
    'focusActive',
    'habitRemindersArmedOn',
    'todoRemindersArmedOn',
    'appLock',
    'appLockMode',
    'appLockDelay',
    'appLockPin',
    'appLockPinSalt',
    'appLockPinLength',
    'appLockRecovery',
    'appLockMisses',
    'appLockStrikes',
    'appLockBlockedUntil',
  };

  static late Box _habits;
  static late Box _settings;
  static late Box _categories;
  static late Box _notes;
  static late Box _focus;
  static late Box _todos;
  static late Box _todoTags;
  static late Box _journeys;
  static late Box _goals;
  static late Box _journalEntries;
  static late Box _dailyPlans;
  static late Box _sync;

  static int _writing = 0;
  static bool _initialized = false;


  static bool get isWriting => _writing > 0;

  static bool get hasDomainContent =>
      _habits.isNotEmpty ||
      _categories.isNotEmpty ||
      _notes.isNotEmpty ||
      _focus.isNotEmpty ||
      _todos.isNotEmpty ||
      _todoTags.isNotEmpty ||
      _journeys.isNotEmpty ||
      _goals.isNotEmpty ||
      _journalEntries.isNotEmpty ||
      _dailyPlans.isNotEmpty;

  static bool get _syncAvailable => _initialized && _sync.isOpen;
  static bool get _settingsAvailable => _initialized && _settings.isOpen;

  static Map<String, dynamic> get profile {
    if (!_syncAvailable) return <String, dynamic>{};
    final value = _sync.get('accountProfile');
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  static Future<void> writeProfile({
    required String displayName,
    required String avatarPath,
  }) async {
    if (!_syncAvailable) return;

    final current = profile;
    final payload = <String, dynamic>{
      'displayName': displayName.trim(),
      'avatarPath': avatarPath.trim(),
      'timeZone': (current['timeZone'] ?? 'UTC').toString(),
      'preferredLocale': (current['preferredLocale'] ?? 'en').toString(),
    };

    await _sync.put('accountProfile', payload);
  }

  static Future<T> guardWrites<T>(Future<T> Function() action) async {
    _writing++;
    try {
      return await action();
    } finally {
      _writing--;
    }
  }

  static Future<void> init() async {
    if (isMobile) {
      await Hive.initFlutter();
    } else {
      Hive.init((await appDataDir()).path);
    }
    _habits = await Hive.openBox(_habitsBox);
    _settings = await Hive.openBox(_settingsBox);
    _categories = await Hive.openBox(_categoriesBox);
    _notes = await Hive.openBox(_notesBox);
    _focus = await Hive.openBox(_focusBox);
    _todos = await Hive.openBox(_todosBox);
    _todoTags = await Hive.openBox(_todoTagsBox);
    _journeys = await Hive.openBox(_journeysBox);
    _goals = await Hive.openBox(_goalsBox);
    _journalEntries = await Hive.openBox(_journalEntriesBox);
    _dailyPlans = await Hive.openBox(_dailyPlansBox);
    _sync = await Hive.openBox(_syncBox);
    await _dropLegacyAccountState();
    _initialized = true;
  }

  // the account/sync layer is gone. Its bookkeeping (pending
  // operations, resource versions, owner id, media id cache, bootstrap marker)
  // is obsolete and is removed on start. The user's content boxes, the
  // `settings` box and the local `profile` entry are never touched here.
  static const _legacyKeyPrefixes = ['op:', 'ver:', 'media:', 'fp:', 'rev:'];
  static const _legacyKeys = {'accountOwnerId', 'normalizedBootstrapAt', 'cursor'};

  @visibleForTesting
  static Future<void> dropLegacyAccountStateForTesting() => _dropLegacyAccountState();

  static Future<void> _dropLegacyAccountState() async {
    final stale = _sync.keys.whereType<String>().where(
          (k) =>
              _legacyKeys.contains(k) ||
              _legacyKeyPrefixes.any((p) => k.startsWith(p)),
        );
    await _sync.deleteAll(stale.toList(growable: false));
  }

  static List<DailyPlan> readDailyPlans() {
    final result = <DailyPlan>[];
    for (final raw in _dailyPlans.values) {
      try {
        result.add(DailyPlan.fromMap(Map<String, dynamic>.from(raw as Map)));
      } catch (e) {
        debugPrint('Skipped an unreadable daily plan: $e');
      }
    }
    return result;
  }

  static DailyPlan? readDailyPlan(String date) {
    final raw = _dailyPlans.get(date);
    if (raw is! Map) return null;
    try {
      return DailyPlan.fromMap(Map<String, dynamic>.from(raw));
    } catch (e) {
      debugPrint('Skipped an unreadable daily plan for $date: $e');
      return null;
    }
  }

  static Future<void> writeDailyPlan(DailyPlan plan) async {
    await _dailyPlans.put(plan.date, plan.toMap());
  }

  static Future<void> removeDailyPlan(String date) async {
    await _dailyPlans.delete(date);
  }

  static List<Todo> readTodos() {
    final result = <Todo>[];
    for (final raw in _todos.values) {
      try {
        result.add(Todo.fromMap(Map<String, dynamic>.from(raw as Map)));
      } catch (e) {
        debugPrint('Skipped an unreadable to-do: $e');
      }
    }
    return result;
  }

  static Future<void> writeTodo(Todo todo) async {
    await _todos.put(todo.id, todo.toMap());
  }

  static Future<void> removeTodo(String id) async {
    await _todos.delete(id);
  }

  static Future<void> removeTodos(Iterable<String> ids) async {
    for (final id in ids) {
      await removeTodo(id);
    }
  }

  static List<TodoTag> readTodoTags() {
    final result = <TodoTag>[];
    for (final raw in _todoTags.values) {
      try {
        result.add(TodoTag.fromJson(raw as String));
      } catch (e) {
        debugPrint('Skipped an unreadable tag: $e');
      }
    }
    return result;
  }

  static Future<void> writeTodoTag(TodoTag tag) async {
    await _todoTags.put(tag.id, tag.toJson());
  }

  static Future<void> removeTodoTag(String id) async {
    await _todoTags.delete(id);
  }

  static List<Journey> readJourneys() {
    final result = <Journey>[];
    for (final raw in _journeys.values) {
      try {
        result.add(Journey.fromMap(Map<String, dynamic>.from(raw as Map)));
      } catch (e) {
        debugPrint('Skipped an unreadable journey: $e');
      }
    }
    return result;
  }

  static Future<void> writeJourney(Journey journey) async {
    await _journeys.put(journey.id, journey.toMap());
  }

  static Future<void> removeJourney(String id) async {
    await _journeys.delete(id);
  }

  static List<Goal> readGoals() {
    final result = <Goal>[];
    for (final raw in _goals.values) {
      try {
        result.add(Goal.fromMap(Map<String, dynamic>.from(raw as Map)));
      } catch (e) {
        debugPrint('Skipped an unreadable goal: $e');
      }
    }
    return result;
  }

  static Future<void> writeGoal(Goal goal) async {
    await _goals.put(goal.id, goal.toMap());
  }

  static Future<void> removeGoal(String id) async {
    await _goals.delete(id);
  }

  static List<JournalEntry> readJournalEntries() {
    final result = <JournalEntry>[];
    for (final raw in _journalEntries.values) {
      try {
        result.add(
          JournalEntry.fromMap(Map<String, dynamic>.from(raw as Map)),
        );
      } catch (e) {
        debugPrint('Skipped an unreadable journal entry: $e');
      }
    }
    return result;
  }

  static Future<void> writeJournalEntry(JournalEntry entry) async {
    await _journalEntries.put(entry.id, entry.toMap());
  }

  static Future<void> removeJournalEntry(String id) async {
    await _journalEntries.delete(id);
  }

  static List<FocusSession> readFocusSessions() {
    final result = <FocusSession>[];
    for (final raw in _focus.values) {
      result.add(FocusSession.fromMap(Map<String, dynamic>.from(raw as Map)));
    }
    return result;
  }

  static Future<void> writeFocusSession(FocusSession session) async {
    await _focus.put(session.id, session.toMap());
  }

  static Future<void> removeFocusSession(String id) async {
    await _focus.delete(id);
  }

  static Future<void> removeFocusSessions(Iterable<String> ids) async {
    for (final id in ids) {
      await removeFocusSession(id);
    }
  }

  static Future<void> removeFocusFor(String habitId) async {
    final ids = readFocusSessions()
        .where((s) => s.habitId == habitId)
        .map((s) => s.id)
        .toList();
    for (final id in ids) {
      await removeFocusSession(id);
    }
  }

  static List<HabitNote> readNotes() {
    final result = <HabitNote>[];
    for (final raw in _notes.values) {
      result.add(HabitNote.fromMap(Map<String, dynamic>.from(raw as Map)));
    }
    return result;
  }

  static Future<void> writeNote(HabitNote note) async {
    await _notes.put(note.id, note.toMap());
  }

  static Future<void> removeNote(String id) async {
    await _notes.delete(id);
  }

  static Future<void> removeNotesFor(String habitId) async {
    final ids = readNotes()
        .where((n) => n.habitId == habitId)
        .map((n) => n.id)
        .toList();
    for (final id in ids) {
      await removeNote(id);
    }
  }

  static Map<String, Habit> readHabits() {
    // Hijri schedules depend on the user's adjustment; background isolates
    // (widgets, notification actions) read habits without SettingsController.
    HijriSchedule.adjust = setting('hijriAdjust', 0);
    final result = <String, Habit>{};
    for (final raw in _habits.values) {
      try {
        final habit = Habit.fromJson(raw as String);
        result[habit.id] = habit;
      } catch (e) {
        debugPrint('Skipped an unreadable habit: $e');
      }
    }
    return result;
  }

  static Future<void> writeHabit(Habit habit) async {
    await _habits.put(habit.id, habit.toJson());
  }

  static Future<void> removeHabit(String id) async {
    await _habits.delete(id);

    for (final journey in readJourneys()) {
      if (!journey.habitIds.contains(id)) continue;
      await writeJourney(
        journey.copyWith(
          habitIds: journey.habitIds
              .where((habitId) => habitId != id)
              .toList(growable: false),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  static Future<void> reloadHabits() async {
    if (_writing > 0) return;
    if (_habits.isOpen) await _habits.close();
    _habits = await Hive.openBox(_habitsBox);
  }

  static List<Category> readCategories() {
    final result = <Category>[];
    for (final raw in _categories.values) {
      try {
        result.add(Category.fromJson(raw as String));
      } catch (e) {
        debugPrint('Skipped an unreadable category: $e');
      }
    }
    return result;
  }

  static Future<void> writeCategory(Category category) async {
    await _categories.put(category.id, category.toJson());
  }

  static Future<void> removeCategory(String id) async {
    await _categories.delete(id);
  }

  static bool get hasCategories => _categories.isNotEmpty;

  static T setting<T>(String key, T fallback) {
    if (!_settingsAvailable) return fallback;
    final value = _settings.get(key, defaultValue: fallback);
    return value is T ? value : fallback;
  }

  static Map<String, dynamic> settingMap(String key) {
    if (!_settingsAvailable) return <String, dynamic>{};
    final value = _settings.get(key);
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  static Future<void> writeSetting(String key, Object value) async {
    if (!_settingsAvailable) return;
    await _settings.put(key, value);
    if (_localOnlySettings.contains(key)) return;
  }

  /// Settings that travel with a backup: everything except the device-only
  /// ones (app lock, auto-backup folder, running focus session…). The profile
  /// and wallpaper photos are included on purpose so they come back too.
  static const _backedUpDeviceSettings = {
    'profilePhoto',
    'bgImage',
    'focusImage',
    'focusImages',
  };

  static Map<String, dynamic> backupSettings() {
    if (!_settingsAvailable) return <String, dynamic>{};
    final out = <String, dynamic>{};
    for (final key in _settings.keys.whereType<String>()) {
      if (_localOnlySettings.contains(key) &&
          !_backedUpDeviceSettings.contains(key)) {
        continue;
      }
      final value = _settings.get(key);
      try {
        jsonEncode(value);
        out[key] = value;
      } catch (_) {}
    }
    return out;
  }

  static Future<void> restoreSettings(Map<String, dynamic> values) async {
    if (!_settingsAvailable) return;
    for (final entry in values.entries) {
      if (_localOnlySettings.contains(entry.key) &&
          !_backedUpDeviceSettings.contains(entry.key)) {
        continue;
      }
      final value = entry.value;
      if (value != null) await _settings.put(entry.key, value);
    }
  }

  static Future<void> restoreProfile(Map<String, dynamic> values) async {
    if (!_syncAvailable || values.isEmpty) return;
    await _sync.put('accountProfile', values);
  }

  static Future<void> removeSetting(String key) async {
    if (!_settingsAvailable) return;
    await _settings.delete(key);
    if (_localOnlySettings.contains(key)) return;
  }

  static Future<void> clearProgress() async {
    for (final habit in readHabits().values) {
      await writeHabit(habit.copyWith(completions: const {}));
    }
    for (final note in readNotes()) {
      await removeNote(note.id);
    }
    for (final session in readFocusSessions()) {
      await removeFocusSession(session.id);
    }
  }

  static Future<void> wipeContent() async {
    for (final plan in readDailyPlans()) {
      await removeDailyPlan(plan.date);
    }
    for (final entry in readJournalEntries()) {
      await removeJournalEntry(entry.id);
    }
    for (final goal in _goalsDeepestFirst(readGoals())) {
      await removeGoal(goal.id);
    }
    for (final journey in readJourneys()) {
      await removeJourney(journey.id);
    }
    for (final note in readNotes()) {
      await removeNote(note.id);
    }
    for (final session in readFocusSessions()) {
      await removeFocusSession(session.id);
    }
    for (final todo in readTodos()) {
      await removeTodo(todo.id);
    }
    for (final tag in readTodoTags()) {
      await removeTodoTag(tag.id);
    }
    for (final habit in readHabits().values) {
      await removeHabit(habit.id);
    }
    for (final category in readCategories()) {
      await removeCategory(category.id);
    }
  }

  static List<Goal> _goalsDeepestFirst(List<Goal> goals) {
    int depth(Goal goal) {
      var value = 0;
      var current = goal.parentGoalId;
      final byId = {for (final item in goals) item.id: item};
      final visited = <String>{};
      while (current != null && visited.add(current)) {
        final parent = byId[current];
        if (parent == null) break;
        value++;
        current = parent.parentGoalId;
      }
      return value;
    }

    return [...goals]..sort((a, b) => depth(b).compareTo(depth(a)));
  }

  static Future<void> wipeEverything() async {
    await wipeContent();

    final settingKeys = _settings.keys.whereType<String>().toList(growable: false);
    for (final key in settingKeys) {
      if (_localOnlySettings.contains(key)) {
        await _settings.delete(key);
      } else {
        await removeSetting(key);
      }
    }
  }
}
