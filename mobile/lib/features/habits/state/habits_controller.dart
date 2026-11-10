import 'package:flutter/material.dart';
import 'package:khuta/features/recovery/data/recovery_config.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/core/utils/cover_storage.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/completion_ops.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/data/reminder.dart';
import 'package:khuta/features/habits/data/substep.dart';
import 'package:khuta/features/habits/data/vacation.dart';
import 'package:khuta/services/backup_service.dart';
import 'package:khuta/services/home_widget_service.dart';
import 'package:khuta/services/import_service.dart';
import 'package:khuta/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class HabitsController extends ChangeNotifier {
  HabitsController() {
    _habits = LocalStore.readHabits();
  }

  final _uuid = const Uuid();
  final _notifications = NotificationService();

  late Map<String, Habit> _habits;
  List<Habit>? _active;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    _active = null;
    super.notifyListeners();
  }

  List<Habit> get habits => _active ??=
      _habits.values.where((h) => !h.isArchived).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  List<Habit> get all => List.unmodifiable(_habits.values);

  /// The position after the last active habit. Not `habits.length`: after a
  /// habit is archived the remaining orders have a gap, and the count would
  /// collide with an existing habit.
  int get _nextOrder => habits.isEmpty ? 0 : habits.last.order + 1;

  List<Habit> get archived {
    final list = _habits.values.where((h) => h.isArchived).toList()
      ..sort((a, b) => b.archivedAt!.compareTo(a.archivedAt!));
    return list;
  }

  bool get isEmpty => habits.isEmpty;

  Map<String, Habit> get asMap => {
        for (final entry in _habits.entries)
          if (!entry.value.isArchived) entry.key: entry.value,
      };

  Habit? byId(String id) => _habits[id];

  Future<void> rescheduleReminders() async {
    if (NotificationService.armedToday('habitRemindersArmedOn')) return;
    for (final habit in _habits.values) {
      if (habit.isArchived ||
          (habit.reminders.isEmpty && !habit.recovery.enabled)) {
        continue;
      }
      await _notifications.scheduleFor(habit);
    }
  }

  /// The shared Recovery threshold changed: rebuild every Recovery cycle.
  Future<void> rescheduleRecovery() async {
    for (final habit in _habits.values) {
      if (habit.isArchived || !habit.recovery.enabled) continue;
      await _notifications.scheduleFor(habit);
    }
  }

  /// The Hijri adjustment changed: rebuild Hijri habits so
  /// cached streaks are recomputed, re-schedule their reminders and refresh
  /// the home-screen widgets. Logged days are never moved.
  Future<void> applyHijriAdjust() async {
    final hijri = _habits.values.where((h) => h.isHijriScheduled).toList();
    if (hijri.isEmpty) return;
    for (final habit in hijri) {
      _habits[habit.id] = habit.copyWith();
    }
    notifyListeners();
    HomeWidgetService.syncSoon(() => asMap);
    for (final habit in hijri) {
      final fresh = _habits[habit.id]!;
      if (fresh.isArchived || fresh.reminders.isEmpty) continue;
      await _notifications.scheduleFor(fresh);
    }
  }

  Future<void> reload() async {
    if (LocalStore.isWriting) return;
    await LocalStore.reloadHabits();
    _habits = LocalStore.readHabits();
    notifyListeners();
  }

  Future<void> clearProgress() async {
    final photos = [
      for (final note in LocalStore.readNotes()) ...note.photos,
    ];
    await LocalStore.clearProgress();
    _habits = LocalStore.readHabits();
    notifyListeners();
    await CoverStorage.forgetAll(photos);
    await HomeWidgetService.sync(asMap);
  }

  Future<void> create({
    required String name,
    required String icon,
    required String category,
    required String description,
    required int color,
    required HabitInterval interval,
    required int targetFrequency,
    List<int> scheduleWeekdays = const [],
    int scheduleEvery = 2,
    ScheduleUnit scheduleUnit = ScheduleUnit.days,
    ScheduleCalendar scheduleCalendar = ScheduleCalendar.gregorian,
    List<int> hijriMonths = const [],
    required List<Reminder> reminders,
    String coverPath = '',
    int coverClarity = 100,
    HabitKind kind = HabitKind.positive,
    double dailyCost = 0,
    double perDayTarget = 1,
    String unitLabel = '',
    double incrementAmount = 1,
    QuantKind quantKind = QuantKind.generic,
    String bookCoverPath = '',
    bool focusOnly = false,
    bool tracking = false,
    int difficulty = 0,
    int focusMinutes = 25,
    int focusBreakMinutes = 0,
    int startMinute = -1,
    int durationMinutes = 0,
    List<Substep> substeps = const [],
    double? minimum,
    RecoveryConfig recovery = RecoveryConfig.off,
  }) async {
    final id = _uuid.v4();
    final habit = Habit(
      id: id,
      name: name,
      icon: icon,
      category: category,
      description: description,
      color: _color(color),
      order: _nextOrder,
      interval: interval,
      targetFrequency: targetFrequency,
      scheduleWeekdays: scheduleWeekdays,
      scheduleEvery: scheduleEvery,
      scheduleUnit: scheduleUnit,
      scheduleCalendar: scheduleCalendar,
      hijriMonths: hijriMonths,
      reminders: reminders,
      coverPath: coverPath,
      coverClarity: coverClarity,
      kind: kind,
      dailyCost: dailyCost,
      perDayTarget: perDayTarget,
      unitLabel: unitLabel,
      incrementAmount: incrementAmount,
      quantKind: quantKind,
      bookCoverPath: bookCoverPath,
      focusOnly: focusOnly,
      tracking: tracking,
      difficulty: difficulty,
      focusMinutes: focusMinutes,
      focusBreakMinutes: focusBreakMinutes,
      startMinute: startMinute,
      durationMinutes: durationMinutes,
      substeps: substeps,
      maximumTargetVersions: [
        HabitMaximumTargetVersion(
          effectiveDate: AppClock.today().dayKey,
          maximum: substeps.isNotEmpty
              ? substeps.length.toDouble()
              : perDayTarget,
          recordedAt: AppClock.now(),
        ),
      ],
      recovery: recovery,
      minimumTargetVersions: [
        if (minimum != null && minimum > 0)
          HabitMinimumTargetVersion(
            effectiveDate: AppClock.today().dayKey,
            minimum: minimum,
            recordedAt: AppClock.now(),
          ),
      ],
    );
    _habits[id] = habit;
    await LocalStore.writeHabit(habit);
    notifyListeners();
    if (reminders.isNotEmpty || recovery.enabled) {
      await _notifications.scheduleFor(habit);
    }
    HomeWidgetService.syncSoon(() => asMap);
  }

  /// [minimum] is the minimum the user chose in the editor, or null when the
  /// field was not touched. History is append-only: the maximum is seeded with
  /// the old target before it changes (so past days keep it), and a minimum
  /// version is appended only when it differs from what will apply today.
  Future<void> update(Habit habit, {double? minimum}) async {
    final next = withHistory(_habits[habit.id], habit, minimum: minimum);
    _habits[next.id] = next;
    await LocalStore.writeHabit(next);
    notifyListeners();
    await _notifications.scheduleFor(next);
    HomeWidgetService.syncSoon(() => asMap);
  }

  /// The edited habit with its append-only target history brought up to date.
  @visibleForTesting
  static Habit withHistory(Habit? previous, Habit habit, {double? minimum}) {
    var next = habit;
    if (previous != null && previous.effectiveTarget != habit.effectiveTarget) {
      final now = AppClock.now();
      final today = AppClock.today().dayKey;
      next = next.copyWith(
        maximumTargetVersions: [
          if (previous.maximumTargetVersions.isEmpty)
            HabitMaximumTargetVersion(
              effectiveDate: previous.startedAt.dayKey,
              maximum: previous.effectiveTarget,
              recordedAt: previous.createdAt,
            ),
          ...next.maximumTargetVersions,
          HabitMaximumTargetVersion(
            effectiveDate: today,
            maximum: habit.effectiveTarget,
            recordedAt: now,
          ),
        ],
      );
    }
    if (previous != null && habit.kind != HabitKind.negative) {
      final today = AppClock.today();
      final full = next.fullTargetOn(today);
      // Untouched field: an unset minimum (none, or equal to the old target)
      // keeps following the target; an explicit lower one is left alone.
      final wasUnset =
          previous.requiredOn(today) >= previous.fullTargetOn(today);
      var desired = minimum;
      if (desired == null && wasUnset) desired = full;
      if (desired != null) {
        desired = desired > full ? full : desired;
        if (desired != next.requiredOn(today)) {
          next = next.copyWith(
            minimumTargetVersions: [
              ...next.minimumTargetVersions,
              HabitMinimumTargetVersion(
                effectiveDate: today.dayKey,
                minimum: desired,
                recordedAt: AppClock.now(),
              ),
            ],
          );
        }
      }
    }
    return next;
  }
  Future<void> toggle(String id, DateTime date, {bool fromFocus = false}) async {
    final habit = _habits[id];
    if (habit == null) return;
    if (habit.blocksManualCheck(date, fromFocus: fromFocus)) return;
    await _apply(habit, CompletionOps.toggle(habit, date));
  }

  Future<void> logRelapse(String id, DateTime date) async {
    final habit = _habits[id];
    if (habit == null) return;
    await _apply(habit, CompletionOps.logRelapse(habit, date));
  }

  Future<void> clearRelapse(String id, DateTime date) async {
    final habit = _habits[id];
    if (habit == null) return;
    await _apply(habit, CompletionOps.clearRelapse(habit, date));
  }

  Future<void> addProgress(String id, DateTime date, double delta) async {
    final habit = _habits[id];
    if (habit == null) return;
    await _apply(habit, CompletionOps.addProgress(habit, date, delta));
  }

  Future<void> setProgress(String id, DateTime date, double value) async {
    final habit = _habits[id];
    if (habit == null) return;
    final current = habit.completions[date.dayKey]?.count ?? 0;
    await _apply(habit, CompletionOps.addProgress(habit, date, value - current));
  }

  Future<void> setStep(
    String id,
    DateTime date,
    String stepId,
    bool checked,
  ) async {
    final habit = _habits[id];
    if (habit == null) return;
    await _apply(habit, CompletionOps.setStep(habit, date, stepId, checked));
  }

  Future<void> setVacation(String id, bool on, {bool bulk = false}) async {
    final habit = _habits[id];
    if (habit == null) return;
    final periods = [...habit.vacations];
    if (on) {
      if (!periods.any((p) => p.isOngoing)) {
        periods.add(VacationPeriod(start: AppClock.now(), bulk: bulk));
      }
    } else {
      final yesterday =
          AppClock.today().subtract(const Duration(days: 1));
      final next = <VacationPeriod>[];
      for (final p in periods) {
        if (!p.isOngoing) {
          next.add(p);
        } else if (!yesterday.isBefore(p.start)) {
          next.add(p.copyWith(end: yesterday));
        }
      }
      periods
        ..clear()
        ..addAll(next);
    }
    await update(habit.copyWith(vacations: periods));
  }

  Future<List<String>> pauseAll() async {
    final paused = <String>[];
    for (final habit in habits) {
      if (habit.isArchived || habit.isOnVacation) continue;
      paused.add(habit.id);
      await setVacation(habit.id, true, bulk: true);
    }
    return paused;
  }

  Future<void> resumeAll(List<String> ids) async {
    for (final habit in [..._habits.values]) {
      if (habit.vacations.any((p) => p.isOngoing && p.bulk) ||
          ids.contains(habit.id)) {
        await setVacation(habit.id, false);
      }
    }
  }

  Future<void> setRestDays(String id, List<int> days) async {
    final habit = _habits[id];
    if (habit == null) return;
    await update(habit.copyWith(restDays: days));
  }

  Future<void> toggleVacationDay(String id, DateTime date) async {
    final habit = _habits[id];
    if (habit == null) return;
    final day = date.atMidnight;
    final previous = day.subtract(const Duration(days: 1));
    final next = day.add(const Duration(days: 1));

    if (!habit.isPausedOn(day)) {
      await update(
        habit.copyWith(
          vacations: [...habit.vacations, VacationPeriod(start: day, end: day)],
        ),
      );
      return;
    }

    final periods = <VacationPeriod>[];
    for (final period in habit.vacations) {
      if (!period.contains(day)) {
        periods.add(period);
        continue;
      }
      if (period.start.isBefore(day)) {
        periods.add(VacationPeriod(start: period.start, end: previous));
      }
      if (period.end == null) {
        periods.add(VacationPeriod(start: next));
      } else if (period.end!.isAfter(day)) {
        periods.add(VacationPeriod(start: next, end: period.end));
      }
    }
    await update(habit.copyWith(vacations: periods));
  }

  Future<void> _apply(
    Habit habit,
    Map<String, Completion> completions,
  ) async {
    final updated = habit.copyWith(completions: completions);
    _habits[habit.id] = updated;
    notifyListeners();
    HomeWidgetService.syncSoon(() => asMap);
    await LocalStore.guardWrites(() => LocalStore.writeHabit(updated));
    final today = AppClock.now();
    if (NotificationService.remindersNeedRefresh(habit, updated, today)) {
      _refreshReminders(habit.id);
    }
  }

  Future<void> _reminderQueue = Future.value();

  void _refreshReminders(String id) {
    _reminderQueue = _reminderQueue.then((_) async {
      final habit = _habits[id];
      if (habit == null) return;
      try {
        await _notifications.scheduleFor(habit);
        await _notifications.dismissShown(habit);
      } catch (e) {
        debugPrint('Could not refresh the reminders of $id: $e');
      }
    });
  }

  void refreshDoneReminders() {
    final today = AppClock.now();
    for (final habit in _habits.values) {
      if (habit.isArchived || habit.reminders.isEmpty) continue;
      if (habit.silencesRemindersOn(today)) _refreshReminders(habit.id);
    }
  }

  Future<void> reorder(List<Habit> visible, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = [...visible];
    moved.insert(newIndex, moved.removeAt(oldIndex));

    final shown = {for (final habit in visible) habit.id};
    final ordered = [...habits];
    var next = 0;
    for (var i = 0; i < ordered.length; i++) {
      if (shown.contains(ordered[i].id)) ordered[i] = moved[next++];
    }

    final reordered = [
      for (var i = 0; i < ordered.length; i++)
        if (ordered[i].order != i) ordered[i].copyWith(order: i),
    ];
    for (final habit in reordered) {
      _habits[habit.id] = habit;
    }
    notifyListeners();

    await LocalStore.guardWrites(() async {
      for (final habit in reordered) {
        await LocalStore.writeHabit(habit);
      }
    });
    await HomeWidgetService.sync(asMap);
  }

  Future<void> archive(String id) async {
    final habit = _habits[id];
    if (habit == null) return;
    final archived = habit.copyWith(archivedAt: AppClock.now());
    _habits[id] = archived;
    await LocalStore.writeHabit(archived);
    notifyListeners();
    await _notifications.cancelFor(id);
    await HomeWidgetService.sync(asMap);
  }

  Future<void> restore(String id) async {
    final habit = _habits[id];
    if (habit == null) return;
    final restored =
        habit.copyWith(clearArchived: true, order: _nextOrder);
    _habits[id] = restored;
    await LocalStore.writeHabit(restored);
    notifyListeners();
    await HomeWidgetService.sync(asMap);
    if (restored.reminders.isNotEmpty || restored.recovery.enabled) {
      await _notifications.scheduleFor(restored);
    }
  }

  Future<void> remove(String id) async {
    try {
      await _notifications.cancelFor(id);
    } catch (e) {
      debugPrint('Could not cancel the reminders of $id: $e');
    }
    final habit = _habits[id];
    final images = [
      if (habit != null) ...[habit.coverPath, habit.bookCoverPath],
      for (final note in LocalStore.readNotes())
        if (note.habitId == id) ...note.photos,
    ];
    _habits.remove(id);
    await LocalStore.guardWrites(() async {
      await LocalStore.removeHabit(id);
      await LocalStore.removeNotesFor(id);
      await LocalStore.removeFocusFor(id);
    });
    notifyListeners();
    await CoverStorage.forgetAll(images);
    await HomeWidgetService.sync(asMap);
  }

  Future<bool> exportBackup({Rect? origin}) async {
    try {
      return await BackupService.export(
        _habits.values.toList(),
        origin: origin,
      );
    } catch (_) {
      return false;
    }
  }

  Future<ImportOutcome?> importFromApp() async {
    final outcome = await LocalStore.guardWrites(ImportService.pickAndParse);
    if (outcome == null) return null;
    await LocalStore.guardWrites(() async {
      var order = _nextOrder;
      for (final habit in outcome.habits) {
        final placed = habit.copyWith(order: order++);
        _habits[placed.id] = placed;
        await LocalStore.writeHabit(placed);
        if (placed.reminders.isNotEmpty) {
          await _notifications.scheduleFor(placed);
        }
      }
    });
    notifyListeners();
    await HomeWidgetService.sync(asMap);
    return outcome;
  }

  Future<String?> importBackup({bool replace = false}) async {
    try {
      final data = await LocalStore.guardWrites(BackupService.read);
      await LocalStore.guardWrites(() => applyBackup(data, replace: replace));
      notifyListeners();
      await HomeWidgetService.sync(asMap);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  @visibleForTesting
  Future<void> applyBackup(BackupData data, {required bool replace}) async {
    if (replace) {
      for (final id in _habits.keys.toList()) {
        await _notifications.cancelFor(id);
      }
      await LocalStore.wipeContent();
      _habits.clear();
    }
    // Parents before dependents: categories -> habits -> tags -> todos ->
    // notes/focus -> journeys -> goals -> journal -> daily plans.
    for (final category in data.categories) {
      await LocalStore.writeCategory(category);
    }
    for (final habit in data.habits) {
      _habits[habit.id] = habit;
      await LocalStore.writeHabit(habit);
    }
    for (final tag in data.todoTags) {
      await LocalStore.writeTodoTag(tag);
    }
    for (final todo in data.todos) {
      await LocalStore.writeTodo(todo);
    }
    for (final note in data.notes) {
      await LocalStore.writeNote(note);
    }
    for (final session in data.focus) {
      await LocalStore.writeFocusSession(session);
    }
    for (final journey in data.journeys) {
      await LocalStore.writeJourney(journey);
    }
    for (final goal in data.goals) {
      await LocalStore.writeGoal(goal);
    }
    for (final entry in data.journalEntries) {
      await LocalStore.writeJournalEntry(entry);
    }
    for (final plan in data.dailyPlans) {
      await LocalStore.writeDailyPlan(plan);
    }
    // Settings and profile come back only on a full restore ("replace");
    // merging a backup into existing data keeps this phone's settings.
    if (replace) {
      await LocalStore.restoreSettings(data.settings);
      await LocalStore.restoreProfile(data.profile);
    }
    for (final habit in data.habits) {
      if (habit.reminders.isNotEmpty || habit.recovery.enabled) {
        await _notifications.scheduleFor(habit);
      }
    }
  }

  static Color _color(int value) => Color(value);
}
