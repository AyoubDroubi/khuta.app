import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/focus/data/focus_session.dart';
import 'package:khuta/features/focus/state/focus_controller.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/journal/data/journal_projection.dart';
import 'package:khuta/features/journeys/data/journey.dart';
import 'package:khuta/features/todos/data/todo.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';

import 'support/app_harness.dart';

// the journal is a projection of habits, focus
// sessions, to-dos and journey milestones; it never invents or drops a day.
void main() {
  useEmptyStore();

  final day = DateTime(2026, 11, 8, 12);
  final other = DateTime(2026, 11, 9, 12);

  Future<({HabitsController habits, FocusController focus, TodosController todos})> build({
    List<DateTime> done = const [],
    List<FocusSession> sessions = const [],
    List<Todo> todos = const [],
  }) async {
    await LocalStore.writeHabit(testHabit(id: 'h', name: 'Read', order: 0, done: done));
    for (final s in sessions) {
      await LocalStore.writeFocusSession(s);
    }
    for (final t in todos) {
      await LocalStore.writeTodo(t);
    }
    final focus = FocusController();
    addTearDown(focus.dispose);
    return (habits: HabitsController(), focus: focus, todos: TodosController());
  }

  FocusSession session(String id, DateTime at, {int seconds = 1500, String habit = 'h'}) => FocusSession(
        id: id,
        habitId: habit,
        targetMinutes: 25,
        seconds: seconds,
        completed: true,
        startedAt: at,
      );

  Todo todo(String id, {bool done = true, DateTime? doneAt}) =>
      Todo(id: id, text: 'Task $id\nmore', createdAt: day, done: done, doneAt: doneAt);

  test('daysWithActivity merges habits, focus and finished to-dos', () async {
    final c = await build(
      done: [day],
      sessions: [session('s', other)],
      todos: [todo('t', doneAt: DateTime(2026, 11, 10, 8))],
    );
    final days = JournalProjection.daysWithActivity(habits: c.habits, focus: c.focus, todos: c.todos);
    expect(days, {day.dayKey, other.dayKey, DateTime(2026, 11, 10).dayKey});
  });

  test('an unfinished to-do, or one without a finish time, adds no day', () async {
    final c = await build(todos: [
      todo('open', done: false, doneAt: day),
      todo('nodate'),
    ]);
    expect(JournalProjection.daysWithActivity(habits: c.habits, focus: c.focus, todos: c.todos), isEmpty);
  });

  test('forDay lists that day only, with names, amounts and todo titles', () async {
    final c = await build(
      done: [day, other],
      sessions: [session('s1', day), session('s2', other), session('orphan', day, habit: 'gone')],
      todos: [todo('t', doneAt: day), todo('u', doneAt: other)],
    );
    final items = JournalProjection.forDay(day: day, habits: c.habits, focus: c.focus, todos: c.todos);
    expect(items.map((a) => a.type).toSet(), {'habit_completion', 'focus', 'todo_completed'});
    expect(items.every((a) => a.date == day.dayKey), isTrue);
    expect(items.where((a) => a.type == 'habit_completion').single.habitName, 'Read');
    final focus = items.where((a) => a.type == 'focus').toList();
    expect(focus.map((a) => a.id).toSet(), {'focus:s1', 'focus:orphan'});
    expect(focus.firstWhere((a) => a.id == 'focus:orphan').habitName, '', reason: 'a deleted habit has no name');
    expect(focus.firstWhere((a) => a.id == 'focus:s1').seconds, 1500);
    expect(items.where((a) => a.type == 'todo_completed').single.todoTitle, 'Task t');
    for (var i = 1; i < items.length; i++) {
      expect(items[i - 1].occurredAt.isBefore(items[i].occurredAt), isFalse, reason: 'newest first');
    }
  });

  group('forJourney', () {
    Journey journey({String start = '', List<JourneyMilestone> milestones = const []}) => Journey(
          id: 'j',
          title: 'Quran',
          startDate: start,
          habitIds: const ['h', 'missing'],
          milestones: milestones,
          createdAt: day,
          updatedAt: day,
        );

    test('collects linked habit completions, focus and finished milestones', () async {
      final c = await build(done: [day], sessions: [session('s', other), session('x', other, habit: 'z')]);
      final items = JournalProjection.forJourney(
        journey: journey(milestones: [
          JourneyMilestone(id: 'm1', title: 'Juz 1', completed: true, order: 0, completedAt: DateTime(2026, 11, 9, 20)),
          const JourneyMilestone(id: 'm2', title: 'Juz 2', completed: false, order: 1),
        ]),
        habits: c.habits,
        focus: c.focus,
      );
      expect(items.map((a) => a.type).toSet(), {'habit_completion', 'focus', 'journey_milestone'});
      expect(items.where((a) => a.type == 'journey_milestone').single.milestoneTitle, 'Juz 1');
      expect(items.any((a) => a.id == 'focus:x'), isFalse, reason: 'focus of an unlinked habit');
      expect(items.every((a) => a.journeyId == 'j'), isTrue);
    });

    test('nothing before the journey start date is included', () async {
      final c = await build(done: [day, other], sessions: [session('old', day), session('new', other)]);
      final items = JournalProjection.forJourney(
        journey: journey(start: other.dayKey),
        habits: c.habits,
        focus: c.focus,
      );
      expect(items.map((a) => a.date).toSet(), {other.dayKey});
      expect(items.any((a) => a.id == 'focus:old'), isFalse);
    });
  });

  group('parseDayKeyOrNull', () {
    test('parses a day key and returns null for blanks and garbage', () {
      expect(JournalProjection.parseDayKeyOrNull('08-11-2026'), DateTime(2026, 11, 8));
      expect(JournalProjection.parseDayKeyOrNull(''), isNull);
      expect(JournalProjection.parseDayKeyOrNull('   '), isNull);
      expect(JournalProjection.parseDayKeyOrNull('not-a-day'), isNull);
    });
  });
}
