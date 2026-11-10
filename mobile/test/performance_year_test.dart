import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/pages/home_page.dart';
import 'package:khuta/features/statistics/data/habit_stats.dart';
import 'package:khuta/features/statistics/pages/statistics_page.dart';

import 'support/app_harness.dart';

// timings with a year of data.
// Prints `PERF <name> <ms>` lines for the quality bar; the guards are loose
// regression limits until the owner approves thresholds.
const _habits = 20;
const _days = 365;

List<Habit> _yearOfData() {
  final today = AppClock.today();
  return [
    for (var h = 0; h < _habits; h++)
      Habit(
        id: 'h$h',
        name: 'Habit $h',
        color: const Color(0xFF94492F),
        order: h,
        interval: h % 4 == 0 ? HabitInterval.weekdays : HabitInterval.daily,
        scheduleWeekdays: const [1, 3, 5],
        createdAt: today.addDays(-_days),
        completions: {
          for (var d = 0; d < _days; d++)
            if ((d + h) % 7 != 0)
              today.addDays(-d).dayKey: Completion(date: today.addDays(-d).dayKey),
        },
      ),
  ];
}

int _time(String name, void Function() body) {
  final watch = Stopwatch()..start();
  body();
  watch.stop();
  // ignore: avoid_print
  print('PERF $name ${watch.elapsedMilliseconds}');
  return watch.elapsedMilliseconds;
}

void main() {
  useEmptyStore();

  test('model computations with a year of data', () {
    final habits = _yearOfData();
    final json = habits.map((h) => h.toJson()).toList();
    final bytes = json.fold<int>(0, (n, s) => n + utf8.encode(s).length);
    // ignore: avoid_print
    print('PERF storage_bytes $bytes');

    late List<Habit> loaded;
    expect(_time('load_${_habits}x$_days', () {
      loaded = json.map(Habit.fromJson).toList();
    }), lessThan(5000));
    expect(_time('streaks', () {
      for (final h in loaded) {
        h.currentStreak;
        h.longestStreak;
        h.strength;
      }
    }), lessThan(5000));
    expect(_time('statistics_compute', () {
      HabitStats.compute(loaded, AppClock.today().year);
    }), lessThan(5000));
  });

  for (final screen in {'today': const HomePage(), 'stats': const StatisticsPage()}.entries) {
    testWidgets('first frame of ${screen.key} with a year of data', (tester) async {
      await seedHabits(tester, _yearOfData());
      final watch = Stopwatch()..start();
      await pumpScreen(tester, screen.value, settle: false);
      await tester.pump();
      watch.stop();
      // ignore: avoid_print
      print('PERF first_frame_${screen.key} ${watch.elapsedMilliseconds}');
      expect(tester.takeException(), isNull);
      expect(watch.elapsedMilliseconds, lessThan(10000));
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
