import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/focus/data/focus_session.dart';
import 'package:khuta/features/habits/data/category.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/data/habit_note.dart';
import 'package:khuta/features/habits/data/substep.dart';
import 'package:khuta/features/todos/data/todo.dart';
import 'package:khuta/services/backup_service.dart';

import 'support/app_harness.dart';

// writes a backup with a year of realistic data for
// the performance check on a phone. Opt-in:
//   YEAR_BACKUP_OUT=/path/khuta_backup_year.json flutter test test/year_backup_generator_test.dart
// Deterministic (fixed seed), so two runs give the same file.
void main() {
  useEmptyStore();

  final out = Platform.environment['YEAR_BACKUP_OUT'];

  test('writes a one-year backup', skip: out == null, () async {
    var seed = 20261108;
    int next(int max) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed % max;
    }

    final today = AppClock.today();
    const colors = [0xFF94492F, 0xFF0A84FF, 0xFF34C759, 0xFFFF9500, 0xFF7C3AED, 0xFF1ABC9C];

    for (final (i, name) in ['Health', 'Fitness', 'Mindfulness', 'Productivity', 'Learning', 'Faith'].indexed) {
      await LocalStore.writeCategory(Category(id: 'c$i', name: name, color: Color(colors[i]), icon: 'star'));
    }

    final specs = <(String, HabitKind, HabitInterval, double, String, int)>[
      ('Morning walk', HabitKind.positive, HabitInterval.daily, 1, '', 80),
      ('Read 20 pages', HabitKind.positive, HabitInterval.daily, 1, '', 70),
      ('Drink water', HabitKind.quantitative, HabitInterval.daily, 8, 'glasses', 85),
      ('Study Arabic', HabitKind.positive, HabitInterval.daily, 1, '', 60),
      ('Gym', HabitKind.positive, HabitInterval.weekdays, 1, '', 75),
      ('Meditate', HabitKind.positive, HabitInterval.daily, 1, '', 55),
      ('Journal', HabitKind.positive, HabitInterval.daily, 1, '', 65),
      ('No sugar', HabitKind.negative, HabitInterval.daily, 1, '', 90),
      ('Steps', HabitKind.quantitative, HabitInterval.daily, 10000, 'steps', 70),
      ('Call family', HabitKind.positive, HabitInterval.weekly, 1, '', 70),
      ('Budget review', HabitKind.positive, HabitInterval.monthly, 1, '', 80),
      ('Stretch', HabitKind.positive, HabitInterval.daily, 1, '', 60),
      ('Pray on time', HabitKind.positive, HabitInterval.daily, 1, '', 88),
      ('Quran', HabitKind.positive, HabitInterval.daily, 1, '', 75),
      ('Practice guitar', HabitKind.positive, HabitInterval.weekdays, 1, '', 50),
      ('Sleep before 11', HabitKind.positive, HabitInterval.daily, 1, '', 55),
      ('No social media', HabitKind.negative, HabitInterval.daily, 1, '', 80),
      ('Cook at home', HabitKind.positive, HabitInterval.weekdays, 1, '', 65),
      ('Walk the dog', HabitKind.positive, HabitInterval.daily, 1, '', 85),
      ('Learn a word', HabitKind.positive, HabitInterval.daily, 1, '', 60),
    ];

    final habits = <Habit>[];
    for (final (i, spec) in specs.indexed) {
      final (name, kind, interval, target, unit, rate) = spec;
      final weekdays = interval == HabitInterval.weekdays ? const [1, 3, 5] : const <int>[];
      final done = <String, Completion>{};
      for (var d = 0; d < 365; d++) {
        final day = today.addDays(-d);
        if (interval == HabitInterval.weekdays && !weekdays.contains(day.weekday)) continue;
        if (interval == HabitInterval.weekly && day.weekday != DateTime.sunday) continue;
        if (interval == HabitInterval.monthly && day.day != 1) continue;
        if (next(100) >= rate) continue;
        final count = kind == HabitKind.quantitative ? (target * (0.6 + next(60) / 100)).roundToDouble() : 1.0;
        done[day.dayKey] = Completion(
          date: day.dayKey,
          count: kind == HabitKind.negative ? 1 : count,
          hour: 6 + next(15),
          minute: next(60),
        );
      }
      habits.add(
        Habit(
          id: 'year-$i',
          name: name,
          color: Color(colors[i % colors.length]),
          order: i,
          category: ['Health', 'Fitness', 'Mindfulness', 'Productivity', 'Learning', 'Faith'][i % 6],
          kind: kind,
          interval: interval,
          scheduleWeekdays: weekdays,
          perDayTarget: target,
          unitLabel: unit,
          substeps: i == 1 ? const [Substep(id: 's1', title: 'Open the book'), Substep(id: 's2', title: 'Read')] : const [],
          createdAt: today.addDays(-365),
          completions: done,
        ),
      );
    }
    // A Hijri habit: every day of Ramadan and Sha'ban, with the last Ramadan done.
    habits.add(
      Habit(
        id: 'year-hijri',
        name: 'Fast (Ramadan)',
        color: const Color(0xFF94492F),
        order: habits.length,
        category: 'Faith',
        scheduleCalendar: ScheduleCalendar.hijri,
        hijriMonths: const [9],
        createdAt: today.addDays(-365),
        completions: {
          for (var d = 0; d < 365; d++)
            if (next(100) < 90) today.addDays(-d).dayKey: Completion(date: today.addDays(-d).dayKey, hour: 5),
        },
      ),
    );
    for (final h in habits) {
      await LocalStore.writeHabit(h);
    }

    for (var n = 0; n < 150; n++) {
      final habit = habits[next(habits.length)];
      final day = today.addDays(-next(365));
      await LocalStore.writeNote(
        HabitNote(
          id: 'note-$n',
          habitId: habit.id,
          date: day.dayKey,
          type: NoteType.values[next(NoteType.values.length)],
          text: 'Note $n for ${habit.name}',
          minutes: next(2) == 0 ? 6 * 60 + next(900) : null,
          createdAt: day.add(Duration(hours: 8 + next(10))),
        ),
      );
    }
    for (var n = 0; n < 300; n++) {
      final habit = habits[next(habits.length)];
      final at = today.addDays(-next(365)).add(Duration(hours: 6 + next(14), minutes: next(60)));
      await LocalStore.writeFocusSession(
        FocusSession(
          id: 'focus-$n',
          habitId: habit.id,
          targetMinutes: 25,
          seconds: 600 + next(1500),
          completed: next(4) != 0,
          startedAt: at,
        ),
      );
    }
    for (var n = 0; n < 60; n++) {
      final done = n % 3 != 0;
      final due = today.addDays(next(60) - 30);
      await LocalStore.writeTodo(
        Todo(
          id: 'todo-$n',
          text: 'Task $n',
          createdAt: due.subtract(const Duration(days: 5)),
          date: next(3) == 0 ? '' : due.dayKey,
          done: done,
          doneAt: done ? due : null,
        ),
      );
    }

    final json = BackupService.payloadForTesting(LocalStore.readHabits().values.toList());
    File(out!).writeAsStringSync(json);
    stdout.writeln('wrote $out: ${(json.length / 1024).round()} KB, ${habits.length} habits');
    expect(File(out).lengthSync(), greaterThan(100 * 1024));

    // The file must import back whole.
    final data = BackupService.parse(json);
    expect(data.habits, hasLength(habits.length));
    expect(data.skipped, 0);
  });
}
