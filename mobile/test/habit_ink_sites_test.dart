import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/focus/data/focus_session.dart';
import 'package:khuta/features/focus/pages/focus_history_page.dart';
import 'package:khuta/features/focus/pages/focus_setup_page.dart';
import 'package:khuta/features/focus/pages/focus_stats_page.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/pages/day_timeline_page.dart';
import 'package:khuta/features/habits/pages/express_quant_stats_page.dart';
import 'package:khuta/features/habits/pages/habit_details_page.dart';
import 'package:khuta/features/habits/pages/home_page.dart';
import 'package:khuta/features/habits/pages/minimal_quant_stats_page.dart';
import 'package:khuta/features/habits/pages/quant_stats_page.dart';
import 'package:khuta/features/statistics/pages/statistics_page.dart';

import 'support/app_harness.dart';

// on dark surfaces no icon or
// text may be drawn in a habit's raw colour when that colour is the default
// terracotta (2.2–2.7:1 there). Habit colours used as ink must go through
// `context.habitInk` (lib/app/theme/habit_ink.dart). Fills and tints are not
// icons or text, so they are not flagged.
const _raw = 0x94492F;

bool _isRaw(Color? c) => c != null && (c.toARGB32() & 0xFFFFFF) == _raw;

List<String> _violations(WidgetTester tester, String where) {
  final found = <String>[];
  for (final element in tester.allElements) {
    final w = element.widget;
    String? what;
    if (w is Icon && _isRaw(w.color)) {
      what = 'Icon(U+${w.icon?.codePoint.toRadixString(16)})';
    } else if (w is Text && _isRaw(w.style?.color)) {
      what = 'Text("${w.data ?? w.textSpan?.toPlainText()}")';
    }
    if (what == null) continue;
    final chain = <String>[];
    element.visitAncestorElements((a) {
      chain.add(a.widget.runtimeType.toString());
      return chain.length < 12;
    });
    // CheckSeal draws its tick on a white badge, readable in every theme.
    if (chain.contains('CheckSeal')) continue;
    found.add('$where: $what in ${chain.take(7).join(' < ')}');
  }
  return found;
}

void main() {
  useEmptyStore();

  const styles = {0: 'classic', 1: 'minimal', 2: 'express'};
  final raw = Color(0xFF000000 | _raw);

  Future<void> seed(WidgetTester tester) => seedHabits(tester, [
        testHabit(id: 'a', name: 'Read', order: 0, color: raw, done: lastDays(6)),
        testHabit(id: 'b', name: 'Water', order: 1, color: raw, kind: HabitKind.quantitative, perDayTarget: 8, unitLabel: 'glasses', done: lastDays(3)),
        testHabit(id: 'c', name: 'No sugar', order: 2, color: raw, kind: HabitKind.negative).copyWith(dailyCost: 5),
      ]);

  for (final style in styles.entries) {
    final screens = <String, Widget>{
      'today': const HomePage(),
      'stats': const StatisticsPage(),
      'timeline': const DayTimelinePage(),
      'details-positive': const HabitDetailsPage(habitId: 'a'),
      'details-quantity': const HabitDetailsPage(habitId: 'b'),
      'details-quit': const HabitDetailsPage(habitId: 'c'),
      'quantity-stats': style.key == 2
          ? const ExpressQuantStatsPage(habitId: 'b')
          : style.key == 1
              ? const MinimalQuantStatsPage(habitId: 'b')
              : const QuantStatsPage(habitId: 'b'),
    };
    for (final screen in screens.entries) {
      testWidgets('${style.value} dark ${screen.key}: no raw habit colour as icon or text ink', (tester) async {
        await seed(tester);
        await pumpScreen(
          tester,
          screen.value,
          settings: {'appStyle': style.key, 'planningEnabled': true},
          themeMode: ThemeMode.dark,
          settle: false,
        );
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(_violations(tester, '${style.value} ${screen.key}'), isEmpty);
      });
    }
  }

  // The Focus screens draw the habit colour as ink too.
  for (final style in styles.entries) {
    final screens = <String, Widget>{
      'focus-setup': const FocusSetupPage(),
      'focus-stats': const FocusStatsPage(),
      'focus-stats-habit': const FocusStatsPage(habitId: 'a'),
      'focus-history': const FocusHistoryPage(),
    };
    for (final screen in screens.entries) {
      testWidgets('${style.value} dark ${screen.key}: no raw habit colour as icon or text ink', (tester) async {
        await seed(tester);
        await tester.runAsync(() async {
          for (var i = 0; i < 3; i++) {
            await LocalStore.writeFocusSession(FocusSession(
              id: 's$i',
              habitId: i == 2 ? 'b' : 'a',
              targetMinutes: 25,
              seconds: 25 * 60,
              completed: true,
              startedAt: AppClock.now(),
            ));
          }
        });
        await pumpScreen(
          tester,
          screen.value,
          settings: {'appStyle': style.key},
          themeMode: ThemeMode.dark,
          settle: false,
        );
        for (var i = 0; i < 30; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(_violations(tester, '${style.value} ${screen.key}'), isEmpty);
      });
    }
  }
}
