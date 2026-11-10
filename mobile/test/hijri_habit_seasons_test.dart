import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/calendar/calendar_display.dart';
import 'package:khuta/core/calendar/hijri_schedule.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/data/reminder.dart';
import 'package:khuta/services/reminder_schedule.dart';

import 'support/hijri_ramadan_reference.dart';

// days outside the chosen Hijri months
// are neutral; streaks carry across seasons; reminders only on due days.
DateTime _shift(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

Map<String, Completion> _every(Iterable<RamadanSpan> spans, {DateTime? skip}) => {
      for (final span in spans)
        for (var i = 0; i < span.days; i++)
          if (skip == null || !_shift(span.start, i).isSameDay(skip))
            _shift(span.start, i).dayKey:
                Completion(date: _shift(span.start, i).dayKey),
    };

Habit _ramadan(Map<String, Completion> completions) => Habit(
      id: 'fast',
      name: 'Fast',
      color: const Color(0xFF94492F),
      order: 0,
      scheduleCalendar: ScheduleCalendar.hijri,
      hijriMonths: const [9],
      completions: completions,
      createdAt: DateTime(2025, 2, 1),
    );

/// Ramadans relative to [today]: the two most recent complete ones and, if
/// today is in Ramadan, the part of the current one before today.
({List<RamadanSpan> complete, RamadanSpan? running}) _recentRamadans(DateTime today) {
  final complete = <RamadanSpan>[];
  RamadanSpan? running;
  var cursor = _shift(today, -1);
  DateTime? end; // exclusive
  while (complete.length < 2) {
    final h = hijriOf(cursor)!;
    final inRamadan = h.month == 9;
    if (inRamadan && end == null) end = _shift(cursor, 1);
    if (!inRamadan && end != null) {
      final start = _shift(cursor, 1);
      final span = RamadanSpan(hijriOf(start)!.year, start, end);
      if (end.isSameDay(today) && hijriOf(today)!.month == 9) {
        running = span; // started before today, still going
      } else {
        complete.insert(0, span);
      }
      end = null;
    }
    cursor = _shift(cursor, -1);
  }
  return (complete: complete, running: running);
}

void main() {
  tearDown(() => HijriSchedule.adjust = 0);

  final spans = ramadanReference.where((s) => s.hijriYear >= 1446).toList();

  // The streak functions read the real clock (AppClock). To stay correct on
  // any date, the cross-season tests use the two most recent complete
  // Ramadans before today, plus the days of a Ramadan in progress up to
  // yesterday. The spans come from `hijriOf`, which B0/B1
  // check against the published reference table.
  final today = AppClock.today();
  final recent = _recentRamadans(today);
  final previous = recent.complete[0];
  final last = recent.complete[1];
  final running = recent.running;

  group('streaks', () {
    test('a streak carries from one Ramadan into the next', () {
      final habit = _ramadan(_every([previous, last, ?running]));
      final total = previous.days + last.days + (running?.days ?? 0);
      expect(habit.currentStreak, total);
      expect(habit.longestStreak, total);
    });

    test('a missed Ramadan day breaks the streak', () {
      final missed = _shift(last.start, 9); // 10 Ramadan
      final habit = _ramadan(_every([previous, last, ?running], skip: missed));
      final after = last.days - 10 + (running?.days ?? 0);
      expect(habit.currentStreak, after);
      expect(habit.longestStreak, after > previous.days + 9 ? after : previous.days + 9);
    });

    test('the date helper finds whole Ramadans on any date', () {
      for (final day in [
        DateTime(2026, 11, 8),
        DateTime(2026, 2, 18), // 1 Ramadan 1447
        DateTime(2026, 3, 1), // mid-Ramadan 1447
        DateTime(2026, 3, 20), // 1 Shawwal 1447
        DateTime(2027, 6, 1),
        DateTime(2031, 1, 1),
      ]) {
        final r = _recentRamadans(day);
        for (final span in [...r.complete, ?r.running]) {
          expect(hijriOf(span.start)!.day, 1, reason: '$day');
          expect(hijriOf(_shift(span.start, -1))!.month, 8, reason: '$day');
          expect(hijriOf(_shift(span.end, -1))!.month, 9, reason: '$day');
        }
        for (final span in r.complete) {
          expect(span.days, anyOf(29, 30), reason: '$day');
          expect(hijriOf(span.end)!.month, 10, reason: '$day');
        }
        expect(r.complete[0].hijriYear + 1, r.complete[1].hijriYear);
        expect(r.running != null, hijriOf(day)!.month == 9 && hijriOf(day)!.day > 1,
            reason: '$day');
      }
    });

    test('off-season days are off days, never failures', () {
      final habit = _ramadan(_every(spans));
      final between = _shift(spans.first.end, 40); // mid-Dhu al-Qa'dah 1446
      expect(habit.isOffDay(between), isTrue);
      expect(habit.isOffDay(spans.last.start), isFalse);
    });
  });

  group('statistics', () {
    test('off-season the habit is not due, so rates and perfect days skip it', () {
      final habit = _ramadan(_every(spans));
      final offDay = _shift(spans.last.end, 5);
      expect(habit.isScheduledOn(offDay), isFalse);
      // A Gregorian daily habit next to it is the only one due off-season.
      final daily = Habit(
        id: 'walk',
        name: 'Walk',
        color: const Color(0xFF000000),
        order: 1,
        createdAt: DateTime(2025, 2, 1),
      );
      final due = [habit, daily].where((h) => h.isScheduledOn(offDay));
      expect(due.map((h) => h.id), ['walk']);
    });
  });

  group('reminders', () {
    const reminder = Reminder(id: 'r', hour: 4, minute: 30, days: [1, 2, 3, 4, 5, 6, 7]);
    final ramadan = spans.last; // 1447

    test('fire only on Ramadan days, at the reminder time', () {
      final now = _shift(ramadan.start, -3);
      final times = ReminderSchedule.hijriFireTimes(
        habit: _ramadan(const {}),
        reminder: reminder,
        now: now,
        from: now,
      );
      expect(times, isNotEmpty);
      expect(times.first, DateTime(ramadan.start.year, ramadan.start.month, ramadan.start.day, 4, 30));
      for (final t in times) {
        expect(hijriOf(t)!.month, 9, reason: '$t');
        expect((t.hour, t.minute), (4, 30));
      }
      final inThisRamadan = times.where((t) => t.isBefore(ramadan.end)).length;
      expect(inThisRamadan, ramadan.days);
      expect(times.length, lessThanOrEqualTo(ReminderSchedule.hijriMaxDays));
    });

    test('off-season: the next fire is the first day of the next Ramadan', () {
      final now = _shift(ramadan.end, 10);
      final times = ReminderSchedule.hijriFireTimes(
        habit: _ramadan(const {}),
        reminder: reminder,
        now: now,
        from: now,
      );
      expect(times, isNotEmpty);
      final first = hijriOf(times.first)!;
      expect((first.year, first.month, first.day), (1448, 9, 1));
    });

    test('times before `from` are skipped; adjustment shifts the days', () {
      HijriSchedule.adjust = 1;
      final now = _shift(ramadan.start, -3);
      final times = ReminderSchedule.hijriFireTimes(
        habit: _ramadan(const {}),
        reminder: reminder,
        now: now,
        from: now,
      );
      expect(times.first.isSameDay(_shift(ramadan.start, -1)), isTrue);
      final later = ReminderSchedule.hijriFireTimes(
        habit: _ramadan(const {}),
        reminder: reminder,
        now: now,
        from: DateTime(ramadan.start.year, ramadan.start.month, ramadan.start.day, 5),
      );
      expect(later.first.isSameDay(_shift(ramadan.start, 1)), isTrue);
    });

    test('hourly reminders stay within the notification budget', () {
      const hourly = Reminder(id: 'h', hour: 6, minute: 0, days: [1, 2, 3, 4, 5, 6, 7], everyHours: 2);
      final now = _shift(ramadan.start, -1);
      final times = ReminderSchedule.hijriFireTimes(
        habit: _ramadan(const {}),
        reminder: hourly,
        now: now,
        from: now,
      );
      expect(times.length, lessThanOrEqualTo(ReminderSchedule.slotsPerReminder));
      expect(times.every((t) => hijriOf(t)!.month == 9), isTrue);
    });
  });
}
