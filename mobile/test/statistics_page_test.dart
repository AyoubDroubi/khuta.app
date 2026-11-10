import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/goals/widgets/goals_entry_card.dart';
import 'package:khuta/features/statistics/pages/statistics_page.dart';
import 'package:khuta/features/statistics/widgets/app_usage_card.dart';
import 'package:khuta/features/statistics/widgets/stat_donut.dart';
import 'package:khuta/features/statistics/widgets/stat_kit.dart';
import 'package:khuta/features/statistics/widgets/year_heatmap.dart';

import 'support/app_harness.dart';

Future<void> _seedTwo(WidgetTester tester) => seedHabits(tester, [
  testHabit(id: 'a', name: 'Read', order: 0, done: lastDays(9)),
  testHabit(
    id: 'b',
    name: 'Water',
    order: 1,
    kind: HabitKind.quantitative,
    perDayTarget: 8,
    done: lastDays(4),
  ),
]);

void main() {
  useEmptyStore();

  for (final style in [0, 1, 2]) {
    testWidgets('checks app-use access on open for style $style', (
      tester,
    ) async {
      await _seedTwo(tester);
      var accessChecks = 0;
      var usageReads = 0;
      const channel = MethodChannel('khuta/app_usage');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'hasUsageAccess':
            accessChecks++;
            return false;
          case 'readToday':
            usageReads++;
            return {'totalDurationMs': 0, 'apps': <Object>[]};
          case 'openUsageAccessSettings':
            return true;
          default:
            return null;
        }
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
      });

      await pumpScreen(
        tester,
        const StatisticsPage(),
        settings: {'appStyle': style},
      );

      expect(accessChecks, greaterThan(0));
      expect(usageReads, 0, reason: 'access checks do not read app usage');
    });
  }

  testWidgets(
    'express refreshes app use on resume after the card leaves view',
    (
      tester,
    ) async {
      await _seedTwo(tester);
      var usageReads = 0;
      const channel = MethodChannel('khuta/app_usage');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'hasUsageAccess':
            return true;
          case 'readToday':
            usageReads++;
            return {'totalDurationMs': 0, 'apps': <Object>[]};
          default:
            return null;
        }
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
      });

      await pumpScreen(
        tester,
        const StatisticsPage(),
        settings: const {'appStyle': 2},
      );
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('I agree, show today\'s app use'),
        300,
        scrollable: scrollable,
      );
      await tester.ensureVisible(find.text('I agree, show today\'s app use'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I agree, show today\'s app use'));
      await tester.pumpAndSettle();
      expect(usageReads, 1);

      await tester.drag(scrollable, const Offset(0, 20000));
      await tester.pumpAndSettle();
      expect(find.byType(AppUsageCard), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(usageReads, 2);
    },
  );

  for (final (style, headline) in [
    (0, find.text('Completions')),
    (1, find.byType(YearHeatmap)),
    (2, find.text('Best streak')),
  ]) {
    testWidgets('app use sits below the headline numbers for style $style', (
      tester,
    ) async {
      await _seedTwo(tester);
      await pumpScreen(
        tester,
        const StatisticsPage(),
        settings: {'appStyle': style},
      );
      tester.view.physicalSize = const Size(1080, 2340 * 6);
      await tester.pumpAndSettle();

      final card = find.byType(AppUsageCard);
      expect(card, findsOneWidget);
      expect(headline, findsWidgets);
      expect(
        tester.getTopLeft(card).dy,
        greaterThan(tester.getBottomLeft(headline.first).dy),
      );
    });
  }

  testWidgets('with no habits it says there is nothing yet', (tester) async {
    await pumpScreen(tester, const StatisticsPage());

    expect(find.text('No data yet'), findsOneWidget);
    expect(find.byType(YearHeatmap), findsNothing);
    expect(find.byType(AppUsageCard), findsOneWidget);
    expect(find.byType(GoalsEntryCard), findsOneWidget);
  });

  testWidgets('minimal statistics keeps app use visible with no habits', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const StatisticsPage(),
      settings: const {'appStyle': 1},
    );

    expect(find.byType(AppUsageCard), findsOneWidget);
    expect(find.byType(GoalsEntryCard), findsOneWidget);
  });

  testWidgets('express statistics keeps app use visible with no habits', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const StatisticsPage(),
      settings: const {'appStyle': 2},
    );

    expect(find.byType(AppUsageCard), findsOneWidget);
    expect(find.byType(GoalsEntryCard), findsOneWidget);
  });

  testWidgets('classic shows the year and the headline numbers', (
    tester,
  ) async {
    await _seedTwo(tester);
    await pumpScreen(tester, const StatisticsPage());

    expect(find.text('Statistics'), findsOneWidget);
    expect(find.byType(YearHeatmap), findsOneWidget);
    expect(find.text('Completions'), findsOneWidget);
    expect(find.text('Best streak'), findsOneWidget);

    for (final stat in tester.widgetList<MiniStat>(find.byType(MiniStat))) {
      final size = tester.getSize(find.byWidget(stat));
      expect(size.height, greaterThan(40));
    }

    await tester.scrollUntilVisible(
      find.byType(AppUsageCard),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(AppUsageCard), findsOneWidget);
  });

  testWidgets('classic draws every chart down to the bottom', (tester) async {
    await _seedTwo(tester);
    await pumpScreen(tester, const StatisticsPage());

    await scrollToEnd(tester);
    expect(find.byType(HabitDonut), findsOneWidget);
  });

  testWidgets('minimal keeps the heatmap and drops the extra charts', (
    tester,
  ) async {
    await _seedTwo(tester);
    await pumpScreen(tester, const StatisticsPage(), minimal: true);

    expect(find.text('Statistics'), findsOneWidget);
    expect(find.byType(YearHeatmap), findsOneWidget);
    await scrollToEnd(tester);
    expect(find.byType(HabitDonut), findsNothing);
  });

  testWidgets('the year heatmap opens on the current month', (tester) async {
    await _seedTwo(tester);
    await pumpScreen(tester, const StatisticsPage());

    final scroll = tester.widget<SingleChildScrollView>(
      find.descendant(
        of: find.byType(YearHeatmap),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    final position = scroll.controller!.position;

    final today = AppClock.now().atMidnight;
    final firstOfYear = DateTime(today.year, 1, 1);
    final start = firstOfYear.subtract(Duration(days: firstOfYear.weekday - 1));
    final left = (today.difference(start).inDays ~/ 7) * 15.0;

    expect(position.maxScrollExtent, greaterThan(0));
    expect(left, greaterThanOrEqualTo(position.pixels));
    expect(
      left + 12,
      lessThanOrEqualTo(position.pixels + position.viewportDimension),
    );
  });

  testWidgets('filtering by habit keeps the page together', (tester) async {
    await _seedTwo(tester);
    await pumpScreen(tester, const StatisticsPage());

    await tester.tap(find.text('Water'));
    await tester.pumpAndSettle();

    expect(find.byType(YearHeatmap), findsOneWidget);
    await scrollToEnd(tester);
  });
}
