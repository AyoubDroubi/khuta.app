import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/goals/data/goal.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/journeys/data/journey.dart';
import 'package:khuta/features/todos/data/todo.dart';

typedef GoalHabitMaximumForDay = double? Function(
  Habit habit,
  DateTime localDay,
);

class GoalTypeProgress {
  const GoalTypeProgress({
    required this.actual,
    required this.target,
    required this.sourceCount,
  });

  final double actual;
  final double target;
  final int sourceCount;

  double get percent =>
      target <= 0 ? 0 : (actual / target * 100).clamp(0.0, 100.0);
}

class GoalProgressCalculator {
  const GoalProgressCalculator._();

  static Map<GoalSourceType, GoalTypeProgress> calculate({
    required String goalId,
    required Iterable<Goal> goals,
    required Map<String, Habit> habits,
    required Map<String, Todo> todos,
    required Map<String, Journey> journeys,
    required DateTime through,
    GoalHabitMaximumForDay? habitMaximumForDay,
  }) {
    final maximumForDay = habitMaximumForDay ?? _unversionedMaximumForDay;
    final goalList = goals.toList(growable: false);
    final matchingRoots = goalList.where((goal) => goal.id == goalId);
    if (matchingRoots.isEmpty) return const {};
    final root = matchingRoots.first;

    final byParent = <String, List<Goal>>{};
    for (final goal in goalList) {
      final parentId = goal.parentGoalId;
      if (parentId == null) continue;
      byParent.putIfAbsent(parentId, () => []).add(goal);
    }

    final links = <String, GoalSourceLink>{};
    final visited = <String>{};
    final pending = <String>[root.id];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (!visited.add(current)) continue;
      final matchingNode = goalList.where((goal) => goal.id == current);
      if (matchingNode.isEmpty) continue;
      for (final link in matchingNode.first.sources) {
        if (!link.available || link.sourceId.trim().isEmpty) continue;
        final key = '${link.type.index}:${link.sourceId}';
        final existing = links[key];
        if (existing == null || link.linkedAt.isBefore(existing.linkedAt)) {
          links[key] = link;
        }
      }
      pending.addAll(
        byParent[current]?.map((child) => child.id) ?? const <String>[],
      );
    }

    var habitActual = 0.0;
    var habitTarget = 0.0;
    var habitCount = 0;
    var todoActual = 0.0;
    var todoTarget = 0.0;
    var todoCount = 0;
    var journeyActual = 0.0;
    var journeyTarget = 0.0;
    var journeyCount = 0;

    for (final link in links.values) {
      if (link.type == GoalSourceType.habit) {
        final habit = habits[link.sourceId];
        if (habit == null || habit.isArchived) {
          continue;
        }
        final metric = _habitAmount(
          habit,
          from: link.linkedAt,
          through: through,
          maximumForDay: maximumForDay,
        );
        if (metric == null || metric.$2 <= 0) continue;
        habitActual += metric.$1;
        habitTarget += metric.$2;
        habitCount++;
        continue;
      }
      if (link.type == GoalSourceType.todo) {
        final todo = todos[link.sourceId];
        if (todo == null) continue;
        todoTarget++;
        if (todo.done) todoActual++;
        todoCount++;
        continue;
      }
      final journey = journeys[link.sourceId];
      if (journey == null || journey.status == JourneyStatus.archived) {
        continue;
      }
      journeyActual += journey.progress.clamp(0.0, 1.0);
      journeyTarget++;
      journeyCount++;
    }

    return {
      if (habitCount > 0)
        GoalSourceType.habit: GoalTypeProgress(
          actual: habitActual,
          target: habitTarget,
          sourceCount: habitCount,
        ),
      if (todoCount > 0)
        GoalSourceType.todo: GoalTypeProgress(
          actual: todoActual,
          target: todoTarget,
          sourceCount: todoCount,
        ),
      if (journeyCount > 0)
        GoalSourceType.journey: GoalTypeProgress(
          actual: journeyActual,
          target: journeyTarget,
          sourceCount: journeyCount,
        ),
    };
  }

  static (double, double)? _habitAmount(
    Habit habit, {
    required DateTime from,
    required DateTime through,
    required GoalHabitMaximumForDay maximumForDay,
  }) {
    var first = from
        .toLocal()
        .subtract(Duration(hours: AppClock.cutoffHour))
        .atMidnight;
    if (first.isBefore(habit.startedAt)) {
      first = habit.startedAt.atMidnight;
    }
    final last = through.toLocal().atMidnight;
    if (first.isAfter(last)) return (0, 0);

    if (habit.interval == HabitInterval.weekly ||
        habit.interval == HabitInterval.monthly) {
      return _periodicHabitAmount(
        habit,
        first,
        last,
        maximumForDay,
      );
    }

    var actual = 0.0;
    var target = 0.0;
    for (var day = first; !day.isAfter(last); day = _nextDay(day)) {
      if (!habit.isScheduledOn(day) || habit.isPausedOn(day)) continue;
      final dailyTarget = maximumForDay(habit, day);
      if (dailyTarget == null) return null;
      if (dailyTarget <= 0) continue;
      final amount = _habitAmountForDay(habit, day, dailyTarget);
      target += dailyTarget;
      actual += amount;
    }
    return (actual, target);
  }

  static (double, double)? _periodicHabitAmount(
    Habit habit,
    DateTime first,
    DateTime last,
    GoalHabitMaximumForDay maximumForDay,
  ) {
    final weekly = habit.interval == HabitInterval.weekly;
    final activeDays = <DateTime, Set<int>>{};
    for (var day = first; !day.isAfter(last); day = _nextDay(day)) {
      final periodStart =
          weekly ? _weekStart(day) : DateTime(day.year, day.month);
      activeDays.putIfAbsent(periodStart, () => <int>{}).add(day.epochDay);
    }

    var actual = 0.0;
    var target = 0.0;
    for (final period in activeDays.keys) {
      final periodStart = period;
      final periodEnd = weekly
          ? periodStart.add(const Duration(days: 6))
          : DateTime(periodStart.year, periodStart.month + 1, 0);
      final includedEpochDays = activeDays[period]!;
      var activeInPeriod = 0;
      var includedActive = 0;
      var actualInPeriod = 0.0;
      for (var day = periodStart; !day.isAfter(periodEnd); day = _nextDay(day)) {
        if (!habit.isScheduledOn(day) || habit.isPausedOn(day)) continue;
        activeInPeriod++;
        if (!includedEpochDays.contains(day.epochDay)) continue;
        includedActive++;
        final dailyTarget = maximumForDay(habit, day);
        if (dailyTarget == null) return null;
        if (dailyTarget <= 0) continue;
        final amount = _habitAmountForDay(habit, day, dailyTarget);
        actualInPeriod += (amount / dailyTarget).clamp(0.0, 1.0);
      }
      if (activeInPeriod == 0 || includedActive == 0) continue;
      final periodTarget =
          habit.targetFrequency * includedActive / activeInPeriod;
      if (periodTarget <= 0) continue;
      actual += actualInPeriod.clamp(0.0, periodTarget);
      target += periodTarget;
    }
    return (actual, target);
  }

  static double? _unversionedMaximumForDay(
    Habit habit,
    DateTime localDay,
  ) =>
      habit.maximumForDay(localDay);

  static double _habitAmountForDay(
    Habit habit,
    DateTime day,
    double target,
  ) {
    if (target <= 0) return 0;
    if (habit.kind == HabitKind.negative) {
      return habit.completions.containsKey(day.dayKey) ? 0 : 1;
    }

    final completion = habit.completions[day.dayKey];
    if (completion == null) return 0;
    if (habit.hasSubsteps) {
      final stepIds = habit.substeps.map((step) => step.id).toSet();
      return completion.steps
          .where(stepIds.contains)
          .length
          .toDouble()
          .clamp(0.0, target);
    }
    return completion.count.clamp(0.0, target).toDouble();
  }

  static DateTime _weekStart(DateTime day) =>
      DateTime(day.year, day.month, day.day - day.weekday + 1);

  static DateTime _nextDay(DateTime day) =>
      DateTime(day.year, day.month, day.day + 1);
}
