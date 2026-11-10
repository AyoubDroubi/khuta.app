import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/habit.dart';

// streak and schedule rules for every interval kind.
final _today = AppClock.today();
DateTime _monday(int weeksAgo) =>
    _today.addDays(-(_today.weekday - 1)).addDays(-7 * weeksAgo);
DateTime _firstOfMonth(int monthsAgo) => DateTime(_today.year, _today.month - monthsAgo, 1);

Habit _habit({
  HabitInterval interval = HabitInterval.daily,
  int target = 1,
  Iterable<DateTime> done = const [],
  DateTime? createdAt,
  int every = 2,
  ScheduleUnit unit = ScheduleUnit.days,
  int difficulty = 0,
  HabitKind kind = HabitKind.positive,
}) =>
    Habit(
      id: 'h',
      name: 'h',
      color: const Color(0xFF94492F),
      order: 0,
      interval: interval,
      targetFrequency: target,
      scheduleEvery: every,
      scheduleUnit: unit,
      difficulty: difficulty,
      kind: kind,
      createdAt: createdAt ?? _today.addDays(-400),
      completions: {
        for (final d in done) d.dayKey: Completion(date: d.dayKey, hour: 9),
      },
    );

void main() {
  tearDown(() => Habit.weighDifficulty = false);

  group('weekly habits (target per week)', () {
    // Two days in each of the given weeks.
    Iterable<DateTime> weeks(Iterable<int> weeksAgo) =>
        [for (final w in weeksAgo) ...[_monday(w), _monday(w).addDays(1)]];

    test('consecutive full weeks before this one count; an unfinished week does not break it', () {
      final h = _habit(interval: HabitInterval.weekly, target: 2, done: weeks([1, 2, 3]));
      expect(h.currentStreak, 3);
    });

    test('a finished current week adds one', () {
      // Target 1 so the week can be finished on its first day, whatever today is.
      final h = _habit(
        interval: HabitInterval.weekly,
        target: 1,
        done: [_monday(0), _monday(1), _monday(2)],
      );
      expect(h.currentStreak, 3);
    });

    test('one missed week ends the streak', () {
      final h = _habit(interval: HabitInterval.weekly, target: 2, done: weeks([1, 3, 4]));
      expect(h.currentStreak, 1);
    });

    test('a week with too few completions does not count', () {
      final h = _habit(interval: HabitInterval.weekly, target: 3, done: weeks([1, 2]));
      expect(h.currentStreak, 0);
      expect(h.longestStreak, 0);
    });

    test('the longest run is found even when it is not the current one', () {
      final h = _habit(interval: HabitInterval.weekly, target: 2, done: weeks([10, 9, 8, 6, 5]));
      expect(h.longestStreak, 3);
      expect(h.currentStreak, 0);
    });
  });

  group('monthly habits (target per month)', () {
    Iterable<DateTime> months(Iterable<int> monthsAgo) =>
        [for (final m in monthsAgo) ...[_firstOfMonth(m), _firstOfMonth(m).addDays(1)]];

    test('consecutive full months before this one count', () {
      final h = _habit(interval: HabitInterval.monthly, target: 2, done: months([1, 2, 3]));
      expect(h.currentStreak, 3);
    });

    test('a missed month ends the streak; the longest run is kept', () {
      final h = _habit(interval: HabitInterval.monthly, target: 2, done: months([1, 3, 4, 5]));
      expect(h.currentStreak, 1);
      expect(h.longestStreak, 3);
    });
  });

  group('every X days / weeks / months', () {
    test('every 3 days from the creation day', () {
      final start = DateTime(2026, 1, 1);
      final h = _habit(interval: HabitInterval.everyXDays, every: 3, createdAt: start);
      expect([for (var i = 0; i < 7; i++) h.isScheduledOn(start.addDays(i))], [true, false, false, true, false, false, true]);
      expect(h.isScheduledOn(start.addDays(-3)), isFalse, reason: 'before the habit existed');
    });

    test('every 2 weeks is a 14-day step', () {
      final start = DateTime(2026, 1, 5);
      final h = _habit(interval: HabitInterval.everyXDays, every: 2, unit: ScheduleUnit.weeks, createdAt: start);
      expect(h.scheduleSpanDays, 14);
      expect(h.isScheduledOn(start.addDays(14)), isTrue);
      expect(h.isScheduledOn(start.addDays(7)), isFalse);
    });

    test('every month keeps the day of the month, using the last day when it is shorter', () {
      final h = _habit(interval: HabitInterval.everyXDays, every: 1, unit: ScheduleUnit.months, createdAt: DateTime(2026, 1, 31));
      expect(h.isScheduledOn(DateTime(2026, 2, 28)), isTrue);
      expect(h.isScheduledOn(DateTime(2026, 2, 27)), isFalse);
      expect(h.isScheduledOn(DateTime(2026, 3, 31)), isTrue);
      expect(h.isScheduledOn(DateTime(2026, 4, 30)), isTrue);
    });

    test('every 2 months skips the months in between', () {
      final h = _habit(interval: HabitInterval.everyXDays, every: 2, unit: ScheduleUnit.months, createdAt: DateTime(2026, 1, 15));
      expect(h.isScheduledOn(DateTime(2026, 2, 15)), isFalse);
      expect(h.isScheduledOn(DateTime(2026, 3, 15)), isTrue);
      expect(h.isScheduledOn(DateTime(2026, 5, 15)), isTrue);
    });

    test('an interval of zero is never scheduled', () {
      final h = _habit(interval: HabitInterval.everyXDays, every: 0);
      expect(h.isScheduledOn(_today), isFalse);
    });

    test('weekday habits are due on their weekdays only', () {
      final h = Habit(
        id: 'w',
        name: 'w',
        color: Colors.red,
        order: 0,
        interval: HabitInterval.weekdays,
        scheduleWeekdays: const [DateTime.monday, DateTime.thursday],
        createdAt: _today.addDays(-30),
      );
      final monday = _monday(0);
      expect(h.isScheduledOn(monday), isTrue);
      expect(h.isScheduledOn(monday.addDays(1)), isFalse);
      expect(h.isScheduledOn(monday.addDays(3)), isTrue);
    });
  });

  group('labels and weights', () {
    test('interval labels, units and day-specific flags', () {
      expect(HabitInterval.values.map((i) => i.label), ['Daily', 'Weekly', 'Monthly', 'Days', 'Interval']);
      expect(HabitInterval.values.map((i) => i.unit), ['day', 'week', 'month', 'day', 'day']);
      expect(HabitInterval.values.where((i) => i.isDaySpecific), [HabitInterval.weekdays, HabitInterval.everyXDays]);
    });

    test('difficulty weighs 1/2/3 only when the option is on, otherwise everything weighs 2', () {
      expect([1, 2, 3, 0].map((d) => _habit(difficulty: d).difficultyWeight), [2, 2, 2, 2]);
      Habit.weighDifficulty = true;
      expect([1, 2, 3, 0].map((d) => _habit(difficulty: d).difficultyWeight), [1, 2, 3, 2]);
    });

    test('reminders stay quiet after the day is done, except for quit habits', () {
      final done = _habit(done: [_today]);
      expect(done.silencesRemindersOn(_today), isTrue);
      expect(done.silencesRemindersOn(_today.addDays(-1)), isFalse);
      expect(_habit(kind: HabitKind.negative, done: [_today]).silencesRemindersOn(_today), isFalse);
    });
  });
}
