import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/calendar/hijri_schedule.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/habit.dart';

import 'support/hijri_ramadan_reference.dart';

// Hijri schedule model.
Habit _habit({
  ScheduleCalendar calendar = ScheduleCalendar.hijri,
  List<int> months = const [9],
  Map<String, Completion> completions = const {},
}) =>
    Habit(
      id: 'h',
      name: 'Fast',
      color: const Color(0xFF94492F),
      order: 0,
      scheduleCalendar: calendar,
      hijriMonths: months,
      completions: completions,
      createdAt: DateTime(2020),
    );

DateTime _shift(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

void main() {
  tearDown(() => HijriSchedule.adjust = 0);

  group('whole Hijri month', () {
    for (final span in ramadanReference) {
      test('Ramadan ${span.hijriYear}: due every day of the month and no other', () {
        final habit = _habit();
        for (var i = -3; i < span.days + 3; i++) {
          final day = _shift(span.start, i);
          final inside = i >= 0 && i < span.days;
          expect(habit.isScheduledOn(day), inside, reason: '$day');
          expect(habit.isOffDay(day), !inside, reason: '$day');
        }
      });
    }

    test('two months: due in both, not between', () {
      final habit = _habit(months: const [8, 9]); // Sha'ban + Ramadan
      final r = ramadanReference.last; // 1447
      expect(habit.isScheduledOn(_shift(r.start, -1)), isTrue); // 29/30 Sha'ban
      expect(habit.isScheduledOn(r.start), isTrue);
      expect(habit.isScheduledOn(r.end), isFalse); // 1 Shawwal
    });

    test('no months chosen → never due', () {
      final habit = _habit(months: const []);
      expect(habit.isScheduledOn(ramadanReference.last.start), isFalse);
    });
  });

  group('adjustment', () {
    for (final adjust in [-2, -1, 1, 2]) {
      test('adjust $adjust shifts the due days by ${-adjust}', () {
        HijriSchedule.adjust = adjust;
        final habit = _habit();
        final r = ramadanReference.last;
        // A +1 adjustment reads each day as one Hijri day later, so Ramadan
        // starts one Gregorian day earlier.
        final start = _shift(r.start, -adjust);
        final end = _shift(r.end, -adjust);
        expect(habit.isScheduledOn(start), isTrue);
        expect(habit.isScheduledOn(_shift(start, -1)), isFalse);
        expect(habit.isScheduledOn(_shift(end, -1)), isTrue);
        expect(habit.isScheduledOn(end), isFalse);
      });
    }

    test('changing the adjustment never moves logged days', () {
      final r = ramadanReference.last;
      final logged = {r.start.dayKey: Completion(date: r.start.dayKey)};
      final habit = _habit(completions: logged);
      HijriSchedule.adjust = -2; // r.start now falls outside the schedule
      expect(habit.isScheduledOn(r.start), isFalse);
      expect(habit.completions.keys, [r.start.dayKey]);
      expect(habit.isCompletedOn(r.start), isTrue);
    });

    test('value is clamped to −2…+2', () {
      HijriSchedule.adjust = 7;
      expect(HijriSchedule.adjust, 2);
      HijriSchedule.adjust = -9;
      expect(HijriSchedule.adjust, -2);
    });

    test('dates outside the Umm al-Qura range are not due', () {
      final habit = _habit(months: List.generate(12, (i) => i + 1));
      expect(habit.isScheduledOn(DateTime(2100, 3, 1)), isFalse);
      expect(habit.isScheduledOn(DateTime(1900, 3, 1)), isFalse);
    });
  });

  group('compatibility', () {
    test('a stored habit without the new keys loads as Gregorian', () {
      final old = _habit(calendar: ScheduleCalendar.gregorian, months: const [])
          .toMap()
        ..remove('scheduleCalendar')
        ..remove('hijriMonths');
      final habit = Habit.fromMap(old);
      expect(habit.scheduleCalendar, ScheduleCalendar.gregorian);
      expect(habit.hijriMonths, isEmpty);
      expect(habit.isScheduledOn(ramadanReference.last.end), isTrue); // daily
    });

    test('toMap → fromMap round-trips calendar and months', () {
      final habit = Habit.fromMap(_habit(months: const [8, 9]).toMap());
      expect(habit.scheduleCalendar, ScheduleCalendar.hijri);
      expect(habit.hijriMonths, [8, 9]);
    });

    test('bad stored values are ignored', () {
      final map = _habit().toMap()
        ..['scheduleCalendar'] = 9
        ..['hijriMonths'] = [0, 9, 13];
      final habit = Habit.fromMap(map);
      expect(habit.scheduleCalendar, ScheduleCalendar.hijri); // clamped
      expect(habit.hijriMonths, [9]);
    });

    test('a Hijri habit always loads as daily (malformed interval)', () {
      final map = _habit().toMap()..['interval'] = HabitInterval.weekly.index;
      expect(Habit.fromMap(map).interval, HabitInterval.daily);
      final gregorian = _habit(calendar: ScheduleCalendar.gregorian).toMap()
        ..['interval'] = HabitInterval.weekly.index;
      expect(Habit.fromMap(gregorian).interval, HabitInterval.weekly);
    });

    test('Gregorian habits ignore the Hijri adjustment', () {
      HijriSchedule.adjust = 2;
      final habit = _habit(calendar: ScheduleCalendar.gregorian, months: const []);
      expect(habit.isScheduledOn(ramadanReference.last.end), isTrue);
    });
  });
}
