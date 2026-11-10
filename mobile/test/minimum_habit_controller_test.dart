import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/completion_ops.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/data/reminder.dart';
import 'package:khuta/features/habits/data/quant_stats.dart';
import 'package:khuta/features/habits/data/substep.dart';
import 'package:khuta/l10n/app_localizations_en.dart';
import 'package:khuta/services/notification_service.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';

import 'support/app_harness.dart';

// Minimum habit: history, editor semantics, reminders, toggle.
void main() {
  final today = AppClock.today();

  Habit base({double target = 10, Map<DateTime, double> counts = const {}}) =>
      testHabit(
        id: 'q',
        name: 'Water',
        order: 0,
        kind: HabitKind.quantitative,
        perDayTarget: target,
      ).copyWith(
        createdAt: today.addDays(-60),
        completions: {
          for (final e in counts.entries)
            e.key.dayKey:
                Completion(date: e.key.dayKey, count: e.value, hour: 9),
        },
      );

  Habit edit(Habit previous, Habit edited, {double? minimum}) =>
      Habit.fromMap(HabitsController.withHistory(previous, edited,
              minimum: minimum)
          .toMap());

  HabitMinimumTargetVersion minVersion(double m) => HabitMinimumTargetVersion(
        effectiveDate: today.addDays(-3).dayKey,
        minimum: m,
        recordedAt: DateTime.utc(2026, 1, 1),
      );

  test('raising the target does not change past days (no minimum set)', () {
    final past = today.addDays(-5);
    final before = base(counts: {past: 10});
    final h = edit(before, before.copyWith(perDayTarget: 20));
    expect(h.isCompletedOn(past), isTrue);
    expect(h.requiredOn(past), 10);
    expect(h.requiredOn(today), 20);
  });

  test('lowering the target keeps old requirements for past days', () {
    final past = today.addDays(-5);
    final before = base(counts: {past: 6});
    final h = edit(before, before.copyWith(perDayTarget: 5));
    expect(h.isCompletedOn(past), isFalse);
    expect(h.requiredOn(today), 5);
  });

  test('saving without touching the minimum adds no minimum version', () {
    final before = base();
    final h = edit(before, before.copyWith(name: 'Renamed'));
    expect(h.minimumTargetVersions, isEmpty);
  });

  test('an unset minimum keeps following a raised target', () {
    final before = base();
    expect(edit(before, before.copyWith(perDayTarget: 20)).requiredOn(today), 20);
  });

  test('a minimum equal to the old target follows the new target too', () {
    final before = base().copyWith(minimumTargetVersions: [minVersion(10)]);
    expect(edit(before, before.copyWith(perDayTarget: 20)).requiredOn(today), 20);
  });

  test('an explicit lower minimum stays when the target is raised', () {
    final before = base().copyWith(minimumTargetVersions: [minVersion(4)]);
    expect(edit(before, before.copyWith(perDayTarget: 20)).requiredOn(today), 4);
  });

  test('touching the minimum appends one version; same value appends none', () {
    final before = base();
    final once = edit(before, before, minimum: 4);
    expect(once.minimumTargetVersions.length, 1);
    final twice = edit(once, once, minimum: 4);
    expect(twice.minimumTargetVersions.length, 1);
    expect(twice.requiredOn(today), 4);
  });

  test('reminders continue past the minimum and stop at the maximum', () async {
    final h = base(counts: {today: 4}).copyWith(minimumTargetVersions: [
      HabitMinimumTargetVersion(
        effectiveDate: today.addDays(-3).dayKey,
        minimum: 4,
        recordedAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    expect(h.isCompletedOn(today), isTrue);
    expect(h.silencesRemindersOn(today), isFalse);
    final full = h.copyWith(completions: {
      today.dayKey: Completion(date: today.dayKey, count: 10, hour: 9),
    });
    expect(full.silencesRemindersOn(today), isTrue);
  });

  test('tapping a day at the minimum moves it to the maximum', () {
    final h = base(counts: {today: 4}).copyWith(minimumTargetVersions: [
      HabitMinimumTargetVersion(
        effectiveDate: today.addDays(-3).dayKey,
        minimum: 4,
        recordedAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    final after = CompletionOps.toggle(h, today);
    expect(after[today.dayKey]!.count, 10);
  });

  test('a checklist minimum counts steps and survives other schedules', () {
    final h = testHabit(
      id: 'c',
      name: 'Routine',
      order: 0,
      substeps: const [
        Substep(id: 'a', title: 'A'),
        Substep(id: 'b', title: 'B'),
        Substep(id: 'c', title: 'C'),
      ],
    ).copyWith(
      createdAt: today.addDays(-30),
      minimumTargetVersions: [minVersion(2)],
      completions: {
        today.dayKey: Completion(
            date: today.dayKey, count: 2, steps: const {'a', 'b'}, hour: 9),
      },
    );
    expect(h.isCompletedOn(today), isTrue);
    expect(h.isFullTargetOn(today), isFalse);
    final every2 = h.copyWith(
      scheduleEvery: 2,
      scheduleUnit: ScheduleUnit.days,
      interval: HabitInterval.everyXDays,
    );
    expect(every2.requiredOn(today), 2);
  });

  group('other schedules', () {
    Habit scheduled(HabitInterval interval, {int target = 1}) =>
        base(counts: {
          today: 4,
          today.addDays(-1): 4,
          today.addDays(-2): 4,
        }).copyWith(
          interval: interval,
          targetFrequency: target,
          minimumTargetVersions: [minVersion(4)],
        );

    test('weekly count: minimum days count toward the weekly target', () {
      final h = scheduled(HabitInterval.weekly, target: 3);
      expect(h.isCompletedOn(today), isTrue);
      expect(h.isCompletedOn(today.addDays(-1)), isTrue);
    });

    test('monthly count and every-N-days honour the minimum', () {
      for (final interval in [HabitInterval.monthly, HabitInterval.everyXDays]) {
        final h = scheduled(interval, target: 2);
        expect(h.isCompletedOn(today), isTrue, reason: '$interval');
        expect(h.isFullTargetOn(today), isFalse, reason: '$interval');
      }
    });

    test('weekdays: only scheduled days matter, minimum still completes', () {
      final h = scheduled(HabitInterval.weekdays)
          .copyWith(scheduleWeekdays: [today.weekday]);
      expect(h.isCompletedOn(today), isTrue);
      expect(h.totalCompletions, greaterThanOrEqualTo(1));
    });

    test('Hijri schedule: minimum completes a due day', () {
      final h = scheduled(HabitInterval.daily).copyWith(
        scheduleCalendar: ScheduleCalendar.hijri,
        hijriMonths: List.generate(12, (i) => i + 1),
      );
      expect(h.isCompletedOn(today), isTrue);
      expect(h.currentStreak, 3);
    });
  });

  test('goal days use the full target in force on each day', () {
    final past = today.addDays(-5);
    final before = base(counts: {past: 10, today: 20});
    final h = edit(before, before.copyWith(perDayTarget: 20));
    expect(QuantStats.totalsOf(h, today).goalDays, 2);
  });

  test('tapping a checklist at its minimum completes every step', () {
    final h = testHabit(
      id: 'c',
      name: 'Routine',
      order: 0,
      substeps: const [
        Substep(id: 'a', title: 'A'),
        Substep(id: 'b', title: 'B'),
        Substep(id: 'c', title: 'C'),
      ],
    ).copyWith(
      createdAt: today.addDays(-30),
      minimumTargetVersions: [minVersion(2)],
      completions: {
        today.dayKey: Completion(
            date: today.dayKey, count: 2, steps: const {'a', 'b'}, hour: 9),
      },
    );
    final after = CompletionOps.toggleAllSteps(h, today);
    expect(after[today.dayKey]!.steps, {'a', 'b', 'c'});
  });

  test('reminder body shows actual / maximum / remaining', () {
    final strings = AppLocalizationsEn();
    final h = base(counts: {today: 4}).copyWith(
      unitLabel: 'glasses',
      minimumTargetVersions: [minVersion(4)],
    );
    expect(NotificationService.progressLine(h, strings),
        '4 / 10 glasses  ·  6 left');
    final full = h.copyWith(completions: {
      today.dayKey: Completion(date: today.dayKey, count: 10, hour: 9),
    });
    expect(NotificationService.progressLine(full, strings), isNull);
  });

  test('a reminder refreshes when the amount of today changes, not only at the maximum', () {
    final before = base().copyWith(
      reminders: const [Reminder(id: 'r', hour: 9, minute: 0, days: [1, 2, 3, 4, 5, 6, 7])],
    );
    final after = before.copyWith(completions: {
      today.dayKey: Completion(date: today.dayKey, count: 5, hour: 9),
    });
    expect(NotificationService.remindersNeedRefresh(before, after, today), isTrue);
    expect(NotificationService.remindersNeedRefresh(before, before, today), isFalse);
    final plain = testHabit(id: 'p', name: 'p').copyWith(reminders: before.reminders);
    final plainAfter = plain.copyWith(completions: {
      today.dayKey: Completion(date: today.dayKey, count: 1, hour: 9),
    });
    // Completing a plain habit silences its reminders: that flip refreshes.
    expect(NotificationService.remindersNeedRefresh(plain, plainAfter, today), isTrue);
  });

  test('toggling a past quantitative day uses the full target of that day', () {
    final past = today.addDays(-5);
    final before = base(counts: {past: 10});
    final lowered = edit(before, before.copyWith(perDayTarget: 5));
    // Past day still needs 10; a tap on the unfinished day completes it to 10.
    final empty = lowered.copyWith(completions: {
      past.dayKey: Completion(date: past.dayKey, count: 6, hour: 9),
    });
    final after = CompletionOps.toggle(empty, past);
    expect(after[past.dayKey]!.count, 10);
    expect(CompletionOps.toggle(empty.copyWith(completions: after), past)[past.dayKey], isNull);
  });
}
