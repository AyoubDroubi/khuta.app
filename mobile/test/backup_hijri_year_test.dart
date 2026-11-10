import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/services/backup_service.dart';

import 'support/app_harness.dart';

// backups keep the Hijri schedule, a full
// year of history, and older files that predate those fields.
void main() {
  useEmptyStore();

  final today = AppClock.today();

  Habit hijri(String id, List<int> months, {Map<String, Completion> done = const {}}) => Habit(
        id: id,
        name: 'Fast $id',
        color: const Color(0xFF94492F),
        order: 0,
        scheduleCalendar: ScheduleCalendar.hijri,
        hijriMonths: months,
        completions: done,
        createdAt: today.addDays(-400),
      );

  String export(List<Habit> habits) => BackupService.payloadForTesting(habits);

  test('a Hijri habit keeps its calendar and months through export → import', () async {
    final h = hijri('a', [8, 9]);
    await LocalStore.writeHabit(h);
    final data = BackupService.parse(export([h]));
    final back = data.habits.single;
    expect(back.scheduleCalendar, ScheduleCalendar.hijri);
    expect(back.hijriMonths, [8, 9]);
    expect(back.interval, HabitInterval.daily);
    expect(data.skipped, 0);
  });

  test('the export is marked as written by Khuta', () {
    final decoded = jsonDecode(export(const [])) as Map;
    expect(decoded['generator'], 'khuta');
    expect(decoded['app'], 'khuta');
  });

  test('a year of history for 20 habits comes back day for day', () {
    final habits = [
      for (var h = 0; h < 20; h++)
        Habit(
          id: 'h$h',
          name: 'Habit $h',
          color: const Color(0xFF94492F),
          order: h,
          createdAt: today.addDays(-366),
          completions: {
            for (var d = 0; d < 365; d++)
              if ((d + h) % 5 != 0)
                today.addDays(-d).dayKey: Completion(date: today.addDays(-d).dayKey, hour: d % 24),
          },
        ),
    ];
    final data = BackupService.parse(export(habits));
    expect(data.habits, hasLength(20));
    expect(data.skipped, 0);
    for (final original in habits) {
      final back = data.habits.firstWhere((x) => x.id == original.id);
      expect(back.completions.keys.toSet(), original.completions.keys.toSet(), reason: original.id);
      expect(back.completions[today.dayKey]?.hour, original.completions[today.dayKey]?.hour);
    }
  });

  test('a Hijri habit with a year of history keeps both its schedule and its days', () {
    final done = {
      for (var d = 0; d < 365; d += 3) today.addDays(-d).dayKey: Completion(date: today.addDays(-d).dayKey),
    };
    final back = BackupService.parse(export([hijri('r', [9], done: done)])).habits.single;
    expect(back.completions.length, done.length);
    expect(back.hijriMonths, [9]);
  });

  test('a backup from before the Hijri fields loads those habits as Gregorian', () {
    final old = Habit(
      id: 'old',
      name: 'Old',
      color: Colors.red,
      order: 0,
      createdAt: today.addDays(-5),
    ).toMap()
      ..remove('scheduleCalendar')
      ..remove('hijriMonths');
    final raw = json.encode({'app': 'streak', 'version': 1, 'habits': [old]});
    final back = BackupService.parse(raw).habits.single;
    expect(back.scheduleCalendar, ScheduleCalendar.gregorian);
    expect(back.hijriMonths, isEmpty);
    expect(back.isScheduledOn(today), isTrue);
  });

  test('a backup with no `generator` (upstream or older) is accepted the same way', () {
    final raw = json.encode({
      'app': 'streak',
      'version': 1,
      'habits': [
        Habit(id: 'u', name: 'U', color: Colors.red, order: 0, createdAt: today).toMap(),
      ],
    });
    expect(BackupService.parse(raw).habits.single.name, 'U');
  });
}
