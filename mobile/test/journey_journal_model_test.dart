import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/focus/state/focus_controller.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/journal/data/journal_entry.dart';
import 'package:khuta/features/journal/data/journal_projection.dart';
import 'package:khuta/features/journal/state/journal_controller.dart';
import 'package:khuta/features/journeys/data/journey.dart';
import 'package:khuta/features/journeys/state/journeys_controller.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';

import 'support/app_harness.dart';

void main() {
  useEmptyStore();

  test('journey persists milestones and progress locally', () async {
    final controller = JourneysController();
    final milestone = controller.newMilestone('Ship the first slice', 0);

    final journey = await controller.create(
      title: 'Build habits',
      status: JourneyStatus.active,
      milestones: [milestone],
    );

    expect(controller.byId(journey.id)?.progress, 0);

    await controller.toggleMilestone(journey.id, milestone.id);

    final updated = controller.byId(journey.id)!;
    expect(updated.milestones.single.completed, isTrue);
    expect(updated.milestones.single.completedAt, isNotNull);
    expect(updated.progress, 1);

    final reloaded = JourneysController();
    expect(reloaded.byId(journey.id)?.milestones.single.completed, isTrue);
  });

  test('journal allows one reflection per local day', () async {
    final journal = JournalController();

    await journal.create(
      date: '23-09-2026',
      kind: JournalEntryKind.reflection,
      text: 'Good progress today.',
    );

    expect(
      journal.reflectionForDay('23-09-2026')?.text,
      'Good progress today.',
    );

    await expectLater(
      journal.create(
        date: '23-09-2026',
        kind: JournalEntryKind.reflection,
        text: 'Another reflection.',
      ),
      throwsStateError,
    );
  });


  test('journal sorts DD-MM-YYYY keys by real calendar date', () async {
    final journal = JournalController();

    await journal.create(
      date: '31-12-2025',
      kind: JournalEntryKind.moment,
      text: 'Older',
    );
    await journal.create(
      date: '01-01-2026',
      kind: JournalEntryKind.moment,
      text: 'Newer',
    );

    expect(journal.all.first.text, 'Newer');
    expect(journal.all.last.text, 'Older');
  });

  test('journal timeline includes completed tasks', () async {
    final todos = TodosController();
    final todo = await todos.create(text: 'Ship journal timeline');
    await todos.toggle(todo.id);

    final activity = JournalProjection.forDay(
      day: AppClock.today(),
      habits: HabitsController(),
      focus: FocusController(restoreOnCreate: false),
      todos: todos,
    );

    final completed = activity.singleWhere(
      (item) => item.type == 'todo_completed',
    );
    expect(completed.todoId, todo.id);
    expect(completed.todoTitle, 'Ship journal timeline');
  });

  test('offline journey validation matches backend date rules', () async {
    final controller = JourneysController();

    await expectLater(
      controller.create(
        title: 'Invalid dates',
        startDate: '24-09-2026',
        targetDate: '23-09-2026',
      ),
      throwsArgumentError,
    );
  });

  test('offline journal validation enforces the photo limit', () async {
    final journal = JournalController();

    await expectLater(
      journal.create(
        date: '23-09-2026',
        kind: JournalEntryKind.moment,
        text: '',
        photos: List.generate(9, (index) => '/tmp/photo-$index.jpg'),
      ),
      throwsArgumentError,
    );
  });

  test('deleting a habit unlinks it from cached journeys', () async {
    final habit = Habit(
      id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      name: 'Read',
      color: Colors.blue,
      order: 0,
      createdAt: DateTime.utc(2026, 9, 23),
    );
    await LocalStore.writeHabit(habit);
    await LocalStore.writeJourney(
      Journey(
        id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        title: 'Reading journey',
        habitIds: [habit.id],
        createdAt: DateTime.utc(2026, 9, 23),
        updatedAt: DateTime.utc(2026, 9, 23),
      ),
    );

    await LocalStore.removeHabit(habit.id);

    expect(LocalStore.readJourneys().single.habitIds, isEmpty);
  });
}
