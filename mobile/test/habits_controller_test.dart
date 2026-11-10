import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/habits/data/completion_ops.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/data/vacation.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';

import 'support/app_harness.dart';

// the habit controller's state transitions, checked
// against the stored data (a fresh controller reads what the first one wrote).
void main() {
  useEmptyStore();

  final today = AppClock.today();

  Future<HabitsController> controllerWith(List<Habit> habits) async {
    for (final habit in habits) {
      await LocalStore.writeHabit(habit);
    }
    return HabitsController();
  }

  HabitsController reloaded() => HabitsController();

  Habit seed(String id, int order, {HabitKind kind = HabitKind.positive, double target = 1}) =>
      testHabit(id: id, name: 'Habit $id', order: order, kind: kind, perDayTarget: target);

  Future<void> create(HabitsController c, String name, {HabitKind kind = HabitKind.positive}) =>
      c.create(
        name: name,
        icon: 'target',
        category: '',
        description: '',
        color: 0xFF94492F,
        interval: HabitInterval.daily,
        targetFrequency: 1,
        reminders: const [],
        kind: kind,
      );

  group('create / persist', () {
    test('a new habit is stored with the next order and survives a reload', () async {
      final c = await controllerWith([seed('a', 0)]);
      await create(c, 'Read');
      expect(c.habits.map((h) => h.name), ['Habit a', 'Read']);
      final again = reloaded();
      expect(again.habits.map((h) => h.name), ['Habit a', 'Read']);
      expect(again.habits.last.order, 1);
    });

    test('a Hijri habit keeps calendar and months through create → reload', () async {
      final c = await controllerWith([]);
      await c.create(
        name: 'Fast',
        icon: 'target',
        category: '',
        description: '',
        color: 0xFF94492F,
        interval: HabitInterval.daily,
        targetFrequency: 1,
        scheduleCalendar: ScheduleCalendar.hijri,
        hijriMonths: const [8, 9],
        reminders: const [],
      );
      final habit = reloaded().habits.single;
      expect(habit.scheduleCalendar, ScheduleCalendar.hijri);
      expect(habit.hijriMonths, [8, 9]);
    });
  });

  group('completion', () {
    test('toggle marks a day done, a second toggle undoes it, and it persists', () async {
      final c = await controllerWith([seed('a', 0)]);
      await c.toggle('a', today);
      expect(c.byId('a')!.isCompletedOn(today), isTrue);
      expect(reloaded().byId('a')!.isCompletedOn(today), isTrue);
      await c.toggle('a', today);
      expect(c.byId('a')!.isCompletedOn(today), isFalse);
      expect(reloaded().byId('a')!.completions, isEmpty);
    });

    test('toggling an unknown id changes nothing', () async {
      final c = await controllerWith([seed('a', 0)]);
      await c.toggle('nope', today);
      expect(c.habits.single.completions, isEmpty);
    });

    test('quantity: progress adds up, caps nothing, and completes at the target', () async {
      final c = await controllerWith([seed('w', 0, kind: HabitKind.quantitative, target: 8)]);
      await c.addProgress('w', today, 3);
      expect(c.byId('w')!.isCompletedOn(today), isFalse);
      await c.addProgress('w', today, 5);
      expect(c.byId('w')!.completions[today.dayKey]!.count, 8);
      expect(c.byId('w')!.isCompletedOn(today), isTrue);
      await c.setProgress('w', today, 2);
      expect(c.byId('w')!.completions[today.dayKey]!.count, 2);
      expect(c.byId('w')!.isCompletedOn(today), isFalse);
      expect(reloaded().byId('w')!.completions[today.dayKey]!.count, 2);
    });

    test('a relapse on a quit habit is stored as an entry and cleared by removing it', () async {
      final c = await controllerWith([seed('q', 0, kind: HabitKind.negative)]);
      await c.logRelapse('q', today);
      expect(c.byId('q')!.completions.containsKey(today.dayKey), isTrue);
      expect(reloaded().byId('q')!.completions.containsKey(today.dayKey), isTrue);
      await c.clearRelapse('q', today);
      expect(c.byId('q')!.completions.containsKey(today.dayKey), isFalse);
      expect(reloaded().byId('q')!.completions, isEmpty);
    });
  });

  // Rest days and vacations are model rules (`Habit.copyWith` + `isPausedOn`);
  // the controller only stores them through `update`, which also asks the
  // notification plugin to reschedule and so is not exercised in unit tests.
  group('rest days and vacation (model)', () {
    // The most recent Sunday up to today (logging a future day is refused).
    final sunday = today.addDays(-(today.weekday % 7));

    test('a rest day is paused and off; other days are not', () {
      final h = seed('a', 0).copyWith(restDays: const [DateTime.sunday]);
      expect(h.isPausedOn(sunday), isTrue);
      expect(h.isOffDay(sunday), isTrue);
      expect(h.isPausedOn(sunday.addDays(1)), isFalse);
      expect(h.ringsOnWeekday(DateTime.sunday), isFalse);
    });

    test('a rest day is neutral only while nothing is logged on it', () {
      final h = seed('a', 0).copyWith(restDays: const [DateTime.sunday]);
      expect(h.isNeutralOn(sunday), isTrue);
      final logged = h.copyWith(completions: CompletionOps.toggle(h, sunday));
      expect(logged.isNeutralOn(sunday), isFalse);
    });

    test('an ongoing vacation pauses from its start; an ended one stops after its end', () {
      final ongoing = seed('a', 0).copyWith(
        vacations: [VacationPeriod(start: today.addDays(-3))],
      );
      expect(ongoing.isOnVacation, isTrue);
      expect(ongoing.isPausedOn(today), isTrue);
      expect(ongoing.isPausedOn(today.addDays(-4)), isFalse);

      final ended = seed('a', 0).copyWith(
        vacations: [VacationPeriod(start: today.addDays(-6), end: today.addDays(-3))],
      );
      expect(ended.isOnVacation, isFalse);
      expect(ended.isPausedOn(today.addDays(-5)), isTrue);
      expect(ended.isPausedOn(today), isFalse);
    });

    test('rest days and vacations survive a store round trip', () async {
      final h = seed('a', 0).copyWith(
        restDays: const [DateTime.saturday, DateTime.sunday],
        vacations: [VacationPeriod(start: today.addDays(-6), end: today.addDays(-3))],
      );
      final c = await controllerWith([h]);
      final again = reloaded().byId('a')!;
      expect(again.restDays, [DateTime.saturday, DateTime.sunday]);
      expect(again.vacations.single.end, today.addDays(-3));
      expect(c.habits.single.id, 'a');
    });
  });

  group('archive / restore / remove / reorder', () {
    test('archive hides a habit from the active list; restore puts it last', () async {
      final c = await controllerWith([seed('a', 0), seed('b', 1), seed('c', 2)]);
      await c.archive('a');
      expect(c.habits.map((h) => h.id), ['b', 'c']);
      expect(reloaded().habits.map((h) => h.id), ['b', 'c']);
      await c.restore('a');
      expect(c.habits.map((h) => h.id), ['b', 'c', 'a']);
    });

    test('a new habit after archives goes last, not into the gap', () async {
      final c = await controllerWith([seed('a', 0), seed('b', 1), seed('c', 2), seed('d', 3)]);
      await c.archive('a');
      await c.archive('b'); // active orders are now c=2, d=3 (two active habits)
      await create(c, 'New');
      expect(c.habits.map((h) => h.name), ['Habit c', 'Habit d', 'New']);
      expect(reloaded().habits.map((h) => h.name), ['Habit c', 'Habit d', 'New']);
    });

    test('remove deletes the habit from the store', () async {
      final c = await controllerWith([seed('a', 0), seed('b', 1)]);
      await c.remove('a');
      expect(c.habits.map((h) => h.id), ['b']);
      expect(reloaded().habits.map((h) => h.id), ['b']);
    });

    test('reorder moves a habit, renumbers, and persists', () async {
      final c = await controllerWith([seed('a', 0), seed('b', 1), seed('c', 2)]);
      await c.reorder(c.habits, 0, 3); // a to the end
      expect(c.habits.map((h) => h.id), ['b', 'c', 'a']);
      final again = reloaded().habits;
      expect(again.map((h) => h.id), ['b', 'c', 'a']);
      expect(again.map((h) => h.order), [0, 1, 2]);
    });

    test('reordering a filtered view keeps hidden habits in place', () async {
      final c = await controllerWith([seed('a', 0), seed('b', 1), seed('c', 2), seed('d', 3)]);
      final visible = [c.byId('a')!, c.byId('c')!]; // b and d are filtered out
      await c.reorder(visible, 0, 2); // a below c
      expect(c.habits.map((h) => h.id), ['c', 'b', 'a', 'd']);
    });
  });

  group('Hijri adjustment', () {
    test('applyHijriAdjust without Hijri habits does nothing and does not throw', () async {
      final c = await controllerWith([seed('a', 0)]);
      await c.applyHijriAdjust();
      expect(c.habits.single.id, 'a');
    });
  });
}
