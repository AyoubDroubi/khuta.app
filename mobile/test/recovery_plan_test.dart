import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/data/vacation.dart';
import 'package:khuta/features/recovery/data/recovery_config.dart';
import 'package:khuta/features/recovery/data/recovery_plan.dart';
import 'package:khuta/services/notification_service.dart';

import 'support/hijri_ramadan_reference.dart';

import 'support/app_harness.dart';

void main() {
  useEmptyStore();
  final today = AppClock.today();
  final yesterday = today.addDays(-1);

  Habit habit({
    RecoveryConfig recovery = const RecoveryConfig(enabled: true),
    HabitKind kind = HabitKind.positive,
    Map<DateTime, (int, int)> doneAt = const {},
    DateTime? created,
  }) =>
      testHabit(id: 'r', name: 'Read', kind: kind).copyWith(
        createdAt: created ?? today.addDays(-30),
        recovery: recovery,
        completions: {
          for (final e in doneAt.entries)
            e.key.dayKey: Completion(
              date: e.key.dayKey,
              count: 1,
              hour: e.value.$1,
              minute: e.value.$2,
            ),
        },
      );

  DateTime at(DateTime day, int h, [int m = 0]) =>
      DateTime(day.year, day.month, day.day, h, m);

  group('eligibility', () {
    final h = habit(doneAt: {yesterday: (8, 0)});

    test('threshold 1 day + 5 hours: not before, eligible after', () {
      expect(RecoveryPlan.isEligible(h, at(today, 12, 59), 29), isFalse);
      expect(RecoveryPlan.isEligible(h, at(today, 13), 29), isTrue);
    });

    test('off by default and for negative habits', () {
      final off = habit(recovery: RecoveryConfig.off, doneAt: {yesterday: (8, 0)});
      expect(RecoveryPlan.isEligible(off, at(today, 23), 24), isFalse);
      final negative = habit(kind: HabitKind.negative, doneAt: {yesterday: (8, 0)});
      expect(RecoveryPlan.isEligible(negative, at(today, 23), 24), isFalse);
    });

    test('not eligible once completed today (reset)', () {
      final done = habit(doneAt: {yesterday: (8, 0), today: (9, 0)});
      expect(RecoveryPlan.isEligible(done, at(today, 23), 24), isFalse);
    });

    test('archived, unscheduled and vacation days are excluded', () {
      final archived = h.copyWith(archivedAt: today);
      expect(RecoveryPlan.isEligible(archived, at(today, 23), 24), isFalse);
      final otherDay = h.copyWith(
        interval: HabitInterval.weekdays,
        scheduleWeekdays: [for (var d = 1; d <= 7; d++) if (d != today.weekday) d],
      );
      expect(RecoveryPlan.isEligible(otherDay, at(today, 23), 24), isFalse);
    });

    test('vacation and rest days are excluded', () {
      final vacation = h.copyWith(
        vacations: [VacationPeriod(start: today.addDays(-1), end: today)],
      );
      expect(RecoveryPlan.isEligible(vacation, at(today, 23), 24), isFalse);
      final rest = h.copyWith(restDays: [today.weekday]);
      expect(RecoveryPlan.isEligible(rest, at(today, 23), 24), isFalse);
      expect(RecoveryPlan.reminders(vacation, at(today, 9), 24)
          .any((t) => !t.atMidnight.isAfter(today)), isFalse);
    });

    test('a never-completed habit becomes eligible after the threshold', () {
      final fresh = habit(created: today.addDays(-3));
      expect(RecoveryPlan.isEligible(fresh, at(today, 1), 24), isTrue);
    });
  });

  group('reminder sequence', () {
    DateTime base() => at(yesterday, 8); // last completion 08:00 yesterday

    List<DateTime> plan(RecoveryConfig c, {int threshold = 24, DateTime? now}) =>
        RecoveryPlan.reminders(
          habit(recovery: c, doneAt: {yesterday: (8, 0)}),
          now ?? base(),
          threshold,
        );

    test('count 0 schedules nothing, 1 is one-time, N is finite', () {
      expect(plan(const RecoveryConfig(enabled: true, count: 0)), isEmpty);
      expect(plan(const RecoveryConfig(enabled: true, count: 1)).length, 1);
      expect(plan(const RecoveryConfig(enabled: true, count: 4)).length, 4);
    });

    test('interval mode repeats every N hours after the first delay', () {
      final times = plan(const RecoveryConfig(
          enabled: true, count: 3, firstDelayHours: 2, repeatHours: 12));
      expect(times, [
        at(today, 10),
        at(today, 22),
        at(today.addDays(1), 10),
      ]);
    });

    test('fixed-time mode uses the local time on the following days', () {
      final times = plan(const RecoveryConfig(
          enabled: true, count: 3, fixedTime: true, hour: 20, minute: 30));
      expect(times, [
        at(today, 8),
        at(today.addDays(1), 20, 30),
        at(today.addDays(2), 20, 30),
      ]);
    });

    test('reminders already in the past are not repeated', () {
      final times = plan(
        const RecoveryConfig(enabled: true, count: 3, repeatHours: 12),
        now: at(today, 9),
      );
      expect(times, [at(today, 20), at(today.addDays(1), 8)]);
    });

    test('a completion restarts the cycle', () {
      final reset = habit(
        recovery: const RecoveryConfig(enabled: true, count: 2),
        doneAt: {yesterday: (8, 0), today: (9, 0)},
      );
      final times = RecoveryPlan.reminders(reset, at(today, 9, 5), 24);
      expect(times.first, at(today.addDays(1), 9));
    });

    test('days the habit is not scheduled are skipped', () {
      final weekdays = habit(
        recovery: const RecoveryConfig(enabled: true, count: 2, repeatHours: 24),
        doneAt: {yesterday: (8, 0)},
      ).copyWith(
        interval: HabitInterval.weekdays,
        scheduleWeekdays: [today.weekday, today.addDays(2).weekday],
      );
      final times = RecoveryPlan.reminders(weekdays, base(), 24);
      expect(times.every((t) => weekdays.isScheduledOn(t.atMidnight)), isTrue);
      expect(times.length, 2);
    });
  });

  test('keeps the wall-clock time across a daylight-saving change', () {
    final created = DateTime(2026, 3, 1);
    final day = DateTime(2026, 3, 7);
    final h = testHabit(id: 'd', name: 'D').copyWith(
      createdAt: created,
      recovery: const RecoveryConfig(enabled: true, count: 3, repeatHours: 24),
      completions: {
        day.dayKey: Completion(date: day.dayKey, count: 1, hour: 8, minute: 0),
      },
    );
    final times = RecoveryPlan.reminders(h, DateTime(2026, 3, 7, 9), 24);
    expect(times, [
      DateTime(2026, 3, 8, 8),
      DateTime(2026, 3, 9, 8),
      DateTime(2026, 3, 10, 8),
    ]);
  });

  test('computing a plan never touches completions', () {
    final h = habit(doneAt: {yesterday: (8, 0)});
    final before = h.toMap().toString();
    RecoveryPlan.isEligible(h, at(today, 23), 24);
    RecoveryPlan.reminders(h, at(today, 23), 24);
    expect(h.toMap().toString(), before);
    expect(h.currentStreak, h.currentStreak);
  });

  test('config survives a map round trip; old data loads with Recovery off', () {
    final h = habit(
      recovery: const RecoveryConfig(
          enabled: true, count: 5, fixedTime: true, hour: 7, minute: 15),
    );
    final back = Habit.fromMap(h.toMap());
    expect(back.recovery.enabled, isTrue);
    expect(back.recovery.count, 5);
    expect(back.recovery.fixedTime, isTrue);
    expect(back.recovery.hour, 7);
    final plain = habit(recovery: RecoveryConfig.off).toMap();
    expect(plain.containsKey('recovery'), isFalse);
    expect(Habit.fromMap(plain).recovery.enabled, isFalse);
    expect(RecoveryConfig.fromMap({'count': 'x', 'hour': 99}).hour, 23);
  });

  group('Hijri habits', () {
    final span = ramadanReference.last;
    final inRamadan = DateTime(span.start.year, span.start.month, span.start.day + 3);
    final outside = DateTime(span.start.year, span.start.month, span.start.day - 40);

    Habit hijri() => testHabit(id: 'h', name: 'Fast').copyWith(
          createdAt: DateTime(2020),
          scheduleCalendar: ScheduleCalendar.hijri,
          hijriMonths: const [9],
          recovery: const RecoveryConfig(enabled: true, count: 3),
        );

    test('eligible only on days of the chosen Hijri months', () {
      final h = hijri();
      expect(RecoveryPlan.isEligible(h, at(inRamadan, 12), 24), isTrue);
      expect(RecoveryPlan.isEligible(h, at(outside, 12), 24), isFalse);
    });

    test('reminders land only on days inside the chosen months', () {
      final h = hijri();
      final times = RecoveryPlan.reminders(
        h.copyWith(
          recovery: h.recovery.copyWith(enabledAt: at(inRamadan, 13)),
        ),
        at(inRamadan, 12),
        24,
      );
      expect(times, isNotEmpty);
      expect(times.every((t) => hijri().isScheduledOn(t.atMidnight)), isTrue);
      expect(times.length, 3);
    });
  });

  test('enabling Recovery on a long-lapsed habit starts a fresh sequence', () {
    final now = at(today, 12);
    final lapsedHabit = habit(
      recovery: const RecoveryConfig(enabled: true, count: 2, repeatHours: 24),
      created: today.addDays(-300),
    );
    expect(RecoveryPlan.reminders(lapsedHabit, now, 24), isEmpty);
    final enabled = lapsedHabit.copyWith(
      recovery: lapsedHabit.recovery.copyWith(enabledAt: now),
    );
    final times = RecoveryPlan.reminders(enabled, now, 24);
    expect(times, [now, at(today.addDays(1), 12)]);
    expect(Habit.fromMap(enabled.toMap()).recovery.enabledAt, isNotNull);
  });

  group('notification layer', () {
    final cfg = const RecoveryConfig(enabled: true, count: 4, repeatHours: 12);

    test('slots have stable, unique ids and only future moments', () {
      final h = habit(recovery: cfg, doneAt: {yesterday: (8, 0)});
      final now = at(today, 9);
      final a = NotificationService.recoverySlots(h, now, 24);
      final b = NotificationService.recoverySlots(h, now, 24);
      expect(a, b);
      expect(a.map((e) => e.$1).toSet().length, a.length);
      expect(a.every((e) => e.$2.isAfter(now)), isTrue);
      expect(NotificationService.recoverySlots(h.copyWith(recovery: RecoveryConfig.off), now, 24),
          isEmpty);
    });

    test('a slot that is exactly now fires in a few seconds', () {
      final now = at(today, 12);
      final lapsedHabit = habit(
        recovery: RecoveryConfig(enabled: true, count: 2, enabledAt: now),
        created: today.addDays(-300),
      );
      final slots = NotificationService.recoverySlots(lapsedHabit, now, 24);
      expect(slots.length, 2);
      expect(slots.first.$2.isAfter(now), isTrue);
      expect(slots.first.$2.difference(now).inSeconds, lessThanOrEqualTo(10));
    });

    test('a completion that only reaches the minimum still refreshes Recovery', () {
      final before = testHabit(
        id: 'q',
        name: 'Water',
        kind: HabitKind.quantitative,
        perDayTarget: 10,
      ).copyWith(
        createdAt: today.addDays(-10),
        recovery: cfg,
        minimumTargetVersions: [
          HabitMinimumTargetVersion(
            effectiveDate: today.addDays(-9).dayKey,
            minimum: 3,
            recordedAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );
      final after = before.copyWith(completions: {
        today.dayKey: Completion(date: today.dayKey, count: 3, hour: 9),
      });
      // Not at the maximum, so ordinary reminders do not change: only Recovery
      // makes the refresh necessary.
      expect(after.isCompletedOn(today), isTrue);
      expect(after.silencesRemindersOn(today), isFalse);
      expect(NotificationService.remindersNeedRefresh(before, after, today), isTrue);
      expect(
        NotificationService.remindersNeedRefresh(
          before.copyWith(recovery: RecoveryConfig.off),
          after.copyWith(recovery: RecoveryConfig.off),
          today,
        ),
        isFalse,
      );
    });
  });
}
