import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/focus/data/focus_session.dart';
import 'package:khuta/features/focus/pages/focus_history_page.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/pages/habit_details_page.dart';
import 'package:khuta/features/journal/data/journal_entry.dart';
import 'package:khuta/features/journal/pages/journal_entry_editor_page.dart';
import 'package:khuta/features/journal/pages/journal_page.dart';
import 'package:khuta/features/journeys/pages/journeys_page.dart';

import 'support/app_harness.dart';

void main() {
  useEmptyStore();

  testWidgets('journal exposes moment and daily reflection actions',
      (tester) async {
    await pumpScreen(tester, const JournalPage());

    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('Add moment'), findsOneWidget);
    expect(find.text('Daily reflection'), findsOneWidget);
  });

  testWidgets('journal merges manual and automatic events by time',
      (tester) async {
    final day = AppClock.today();

    await tester.runAsync(() async {
      await LocalStore.writeJournalEntry(
        JournalEntry(
          id: '11111111-1111-1111-1111-111111111111',
          date: day.dayKey,
          kind: JournalEntryKind.moment,
          text: 'Morning note',
          minutes: 8 * 60,
          createdAt: day.add(const Duration(hours: 8)).toUtc(),
        ),
      );
    });
    await seedTodos(
      tester,
      [
        testTodo(
          id: '22222222-2222-2222-2222-222222222222',
          text: 'Finished task',
          done: true,
          createdAt: day.add(const Duration(hours: 10)),
        ),
      ],
    );

    await pumpScreen(tester, const JournalPage());

    final morning = find.text('Morning note');
    final task = find.text('Finished task');
    expect(morning, findsOneWidget);
    expect(task, findsOneWidget);
    expect(
      tester.getTopLeft(morning).dy,
      lessThan(tester.getTopLeft(task).dy),
    );
  });

  testWidgets('automatic journal events open details before their source',
      (tester) async {
    final day = AppClock.today();
    const todoId = '33333333-3333-3333-3333-333333333333';

    await seedTodos(
      tester,
      [
        testTodo(
          id: todoId,
          text: 'Source task',
          done: true,
          createdAt: day.add(const Duration(hours: 11)),
        ),
      ],
    );

    await pumpScreen(tester, const JournalPage());

    await tester.tap(
      find.byKey(const ValueKey('journal-activity-todo_completed:$todoId')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('journal_activity_details')), findsOneWidget);
    expect(find.text('Source task'), findsWidgets);
    expect(
      find.byKey(const Key('journal_activity_source_action')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('journal_activity_source_action')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Source task'), findsWidgets);
  });

  testWidgets('todo source edit action is preserved from Journal',
      (tester) async {
    final day = AppClock.today();
    const todoId = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';

    await seedTodos(
      tester,
      [
        testTodo(
          id: todoId,
          text: 'Editable source task',
          done: true,
          createdAt: day.add(const Duration(hours: 11)),
        ),
      ],
    );

    await pumpScreen(tester, const JournalPage());

    await tester.tap(
      find.byKey(const ValueKey('journal-activity-todo_completed:$todoId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('journal_activity_source_action')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'Editable source task');
  });

  testWidgets('todo source delete action is preserved from Journal',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final day = AppClock.today();
    const todoId = 'ffffffff-ffff-ffff-ffff-ffffffffffff';

    await seedTodos(
      tester,
      [
        testTodo(
          id: todoId,
          text: 'Deletable source task',
          done: true,
          createdAt: day.add(const Duration(hours: 12)),
        ),
      ],
    );

    await pumpScreen(tester, const JournalPage());

    await tester.tap(
      find.byKey(const ValueKey('journal-activity-todo_completed:$todoId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('journal_activity_source_action')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Delete').first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Delete'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Deletable source task'), findsNothing);
    semantics.dispose();
  });

  testWidgets('habit completion details can open the habit source',
      (tester) async {
    final day = AppClock.today();
    const habitId = '44444444-4444-4444-4444-444444444444';

    await seedHabits(
      tester,
      [
        testHabit(
          id: habitId,
          name: 'Read',
          done: [day],
        ),
      ],
    );

    await pumpScreen(tester, const JournalPage());

    await tester.tap(
      find.byKey(ValueKey('journal-activity-completion:$habitId:${day.dayKey}')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('journal_activity_details')), findsOneWidget);
    expect(
      find.byKey(const Key('journal_activity_source_action')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('journal_activity_source_action')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HabitDetailsPage), findsOneWidget);
  });

  testWidgets('focus details can open focus history', (tester) async {
    final day = AppClock.today();
    const habitId = '77777777-7777-7777-7777-777777777777';
    const sessionId = '88888888-8888-8888-8888-888888888888';

    await seedHabits(
      tester,
      [testHabit(id: habitId, name: 'Deep work')],
    );
    await tester.runAsync(() async {
      await LocalStore.writeFocusSession(
        FocusSession(
          id: sessionId,
          habitId: habitId,
          targetMinutes: 25,
          seconds: 25 * 60,
          completed: true,
          startedAt: day.add(const Duration(hours: 14)),
        ),
      );
    });

    await pumpScreen(tester, const JournalPage());

    await tester.tap(
      find.byKey(const ValueKey('journal-activity-focus:$sessionId')),
    );
    await tester.pumpAndSettle();

    expect(find.text('25 min'), findsWidgets);
    await tester.tap(
      find.byKey(const Key('journal_activity_source_action')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FocusHistoryPage), findsOneWidget);
  });

  testWidgets('archived habit completion can still open its source',
      (tester) async {
    final day = AppClock.today();
    const habitId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    final archived = Habit(
      id: habitId,
      name: 'Archived habit',
      color: const Color(0xFF7C5CFF),
      order: 0,
      archivedAt: day.subtract(const Duration(days: 1)),
      completions: {
        day.dayKey: Completion(
          date: day.dayKey,
          hour: 9,
          count: 1,
        ),
      },
    );

    await seedHabits(tester, [archived]);
    await pumpScreen(tester, const JournalPage());

    await tester.tap(
      find.byKey(ValueKey('journal-activity-completion:$habitId:${day.dayKey}')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('journal_activity_source_action')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('journal_activity_source_action')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HabitDetailsPage), findsOneWidget);
  });

  testWidgets('automatic activity details work in Minimal style',
      (tester) async {
    final day = AppClock.today();
    const todoId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

    await seedTodos(
      tester,
      [
        testTodo(
          id: todoId,
          text: 'Minimal source task',
          done: true,
          createdAt: day.add(const Duration(hours: 16)),
        ),
      ],
    );

    await pumpScreen(tester, const JournalPage(), minimal: true);

    await tester.tap(
      find.byKey(const ValueKey('journal-activity-todo_completed:$todoId')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('journal_activity_details')), findsOneWidget);
    expect(find.text('Minimal source task'), findsWidgets);
  });

  testWidgets('automatic activity details work in Express style',
      (tester) async {
    final day = AppClock.today();
    const todoId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

    await seedTodos(
      tester,
      [
        testTodo(
          id: todoId,
          text: 'Express source task',
          done: true,
          createdAt: day.add(const Duration(hours: 17)),
        ),
      ],
    );

    await pumpScreen(
      tester,
      const JournalPage(),
      settings: const {'appStyle': 2},
    );

    await tester.tap(
      find.byKey(const ValueKey('journal-activity-todo_completed:$todoId')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('journal_activity_details')), findsOneWidget);
    expect(find.text('Express source task'), findsWidgets);
  });

  testWidgets('manual journal entry still opens its editor', (tester) async {
    final day = AppClock.today();

    await tester.runAsync(() async {
      await LocalStore.writeJournalEntry(
        JournalEntry(
          id: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
          date: day.dayKey,
          kind: JournalEntryKind.moment,
          text: 'Manual moment',
          minutes: 18 * 60,
          createdAt: day.add(const Duration(hours: 18)).toUtc(),
        ),
      );
    });

    await pumpScreen(tester, const JournalPage());

    await tester.tap(find.text('Manual moment'));
    await tester.pumpAndSettle();

    expect(find.byType(JournalEntryEditorPage), findsOneWidget);
  });

  testWidgets('journeys empty state can create a journey', (tester) async {
    await pumpScreen(tester, const JourneysPage());

    expect(find.text('No journeys yet'), findsOneWidget);
    expect(find.text('New journey'), findsOneWidget);
  });
}
