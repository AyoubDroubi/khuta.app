import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/statistics/data/habit_stats.dart';

// the streak chart treats days a habit
// is not due as neutral.
final _today = DateTime.now().atMidnight;
DateTime _ago(int days) => _today.addDays(-days);

Habit _habit({
  HabitInterval interval = HabitInterval.daily,
  List<int> weekdays = const [],
  List<int> restDays = const [],
  required bool Function(DateTime day) done,
  int daysOld = 200,
}) =>
    Habit(
      id: 'h',
      name: 'h',
      color: const Color(0xFF94492F),
      order: 0,
      interval: interval,
      scheduleWeekdays: weekdays,
      restDays: restDays,
      createdAt: _ago(daysOld),
      completions: {
        for (var i = 0; i < daysOld; i++)
          if (done(_ago(i))) _ago(i).dayKey: Completion(date: _ago(i).dayKey, hour: 9),
      },
    );

List<double> _series(Habit h) => HabitStats.compute([h], _today.year).streakSeries;

void main() {
  const mwf = [DateTime.monday, DateTime.wednesday, DateTime.friday];

  test('a Mon/Wed/Fri habit keeps its run across the days in between', () {
    final h = _habit(
      interval: HabitInterval.weekdays,
      weekdays: mwf,
      done: (d) => mwf.contains(d.weekday),
    );
    final s = _series(h);
    // Every due day in the whole history is done, so the run only grows.
    for (var i = 1; i < s.length; i++) {
      expect(s[i], greaterThanOrEqualTo(s[i - 1]), reason: 'index $i');
    }
    // 90 days ≈ 38 due days; the run before the window adds more.
    expect(s.last, greaterThanOrEqualTo(38));
  });

  test('missing a due day resets the run; the next due day starts again', () {
    // A Mon/Wed/Fri day about 20 days back.
    var missed = _ago(20);
    while (!mwf.contains(missed.weekday)) {
      missed = missed.addDays(1);
    }
    final h = _habit(
      interval: HabitInterval.weekdays,
      weekdays: mwf,
      done: (d) => mwf.contains(d.weekday) && !d.isSameDay(missed),
    );
    final s = _series(h);
    final idx = 89 - (_today.epochDay - missed.epochDay);
    expect(s[idx], 0, reason: 'the missed due day resets the run');
    // The run restarts at the next due day and counts due days only.
    var due = 0;
    for (var d = missed.addDays(1); !d.isAfter(_today); d = d.addDays(1)) {
      if (mwf.contains(d.weekday)) due++;
    }
    expect(s.last, due);
  });

  test('a daily habit is unchanged: one run, reset by a missed day', () {
    final missed = _ago(10);
    final h = _habit(done: (d) => !d.isSameDay(missed));
    final s = _series(h);
    expect(s[89 - 10], 0);
    expect(s.last, 10);
    expect(s[89 - 11], greaterThan(0));
  });

  test('rest days are neutral too', () {
    final h = _habit(
      restDays: const [DateTime.sunday],
      done: (d) => d.weekday != DateTime.sunday,
    );
    final s = _series(h);
    for (var i = 1; i < s.length; i++) {
      expect(s[i], greaterThanOrEqualTo(s[i - 1]), reason: 'index $i');
    }
  });

  test('a habit created recently does not walk back past its start', () {
    final h = _habit(daysOld: 5, done: (d) => true);
    expect(_series(h).last, 5);
  });
}
