import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:khuta/app/home_shell.dart';
import 'package:khuta/core/minimal/minimal_nav.dart';
import 'package:khuta/features/habits/pages/home_page.dart';
import 'package:khuta/features/journal/pages/journal_page.dart';
import 'package:khuta/features/settings/pages/settings_page.dart';
import 'package:khuta/features/statistics/pages/statistics_page.dart';
import 'package:khuta/features/todos/pages/todos_page.dart';

import 'support/app_harness.dart';

void main() {
  useEmptyStore();

  testWidgets('classic opens settings from Today and keeps Stats available', (
    tester,
  ) async {
    await seedHabits(tester, [
      testHabit(id: 'a', name: 'Read', done: lastDays(5)),
    ]);
    await pumpScreen(tester, const HomeShell());

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Today'), findsWidgets);

    await tester.tap(find.byIcon(LucideIcons.settings));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.chartColumn).last);
    await tester.pumpAndSettle();
    expect(find.text('Stats'), findsOneWidget);
    expect(find.byType(StatisticsPage), findsOneWidget);
  });

  testWidgets('journal shortcut is absent from primary navigation', (
    tester,
  ) async {
    await seedHabits(tester, [testHabit(id: 'a', name: 'Read')]);
    await pumpScreen(tester, const HomeShell());

    expect(find.byType(JournalPage, skipOffstage: false), findsNothing);
    expect(find.byIcon(LucideIcons.bookOpenText), findsNothing);
  });

  testWidgets('the stats tab only does its counting once it is opened', (
    tester,
  ) async {
    await seedHabits(tester, [
      testHabit(id: 'a', name: 'Read', done: lastDays(5)),
    ]);
    await pumpScreen(tester, const HomeShell());
    await tester.pumpAndSettle();

    expect(
      find.byType(StatisticsPage, skipOffstage: false),
      findsNothing,
      reason: 'no se construye hasta abrirla',
    );

    await tester.tap(find.byIcon(LucideIcons.chartColumn).last);
    await tester.pumpAndSettle();
    final page =
        tester.state<State<StatisticsPage>>(
              find.byType(StatisticsPage),
            )
            as dynamic;
    expect(page.debugStats.total, 5, reason: 'cuenta al abrirla');
  });

  testWidgets('the to-do tab stays hidden while the setting is off', (
    tester,
  ) async {
    await seedHabits(tester, [testHabit(id: 'a', name: 'Read')]);
    await pumpScreen(
      tester,
      const HomeShell(),
      settings: {'todosEnabled': false},
    );

    expect(find.byIcon(LucideIcons.listChecks), findsNothing);
    expect(find.byType(TodosPage), findsNothing);
  });

  testWidgets('switching to-dos on adds the tab', (tester) async {
    await seedHabits(tester, [testHabit(id: 'a', name: 'Read')]);
    await pumpScreen(
      tester,
      const HomeShell(),
      settings: {'todosEnabled': true},
    );

    await tester.tap(find.byIcon(LucideIcons.listChecks));
    await tester.pumpAndSettle();
    expect(find.byType(TodosPage), findsOneWidget);
  });

  testWidgets('swiping no longer jumps to another tab', (tester) async {
    await seedHabits(tester, [testHabit(id: 'a', name: 'Read')]);
    await pumpScreen(
      tester,
      const HomeShell(),
      settings: {'todosEnabled': true},
    );

    await tester.fling(find.byType(HomePage), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.byType(TodosPage), findsNothing);
  });

  testWidgets('a wide window gives minimal a rail and a detail pane', (
    tester,
  ) async {
    await seedHabits(tester, [
      testHabit(id: 'a', name: 'Read', done: lastDays(5)),
    ]);
    await pumpScreen(tester, const HomeShell(), minimal: true);

    tester.view.physicalSize = const Size(1500, 940);
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();

    expect(find.byType(MinimalNavRail), findsOneWidget);

    await tester.tap(find.text('Stats').first);
    await tester.pumpAndSettle();
    expect(find.byType(StatisticsPage), findsOneWidget);
  });

  testWidgets('minimal drops the bar and keeps only the home', (tester) async {
    await seedHabits(tester, [
      testHabit(id: 'a', name: 'Read', done: lastDays(5)),
    ]);
    await pumpScreen(tester, const HomeShell(), minimal: true);

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(StatisticsPage), findsNothing);
    expect(find.byType(SettingsPage), findsNothing);
  });
}
