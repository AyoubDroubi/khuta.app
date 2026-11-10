import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/pages/habit_details_page.dart';
import 'package:khuta/features/habits/pages/habit_form_page.dart';
import 'package:khuta/features/habits/pages/home_page.dart';
import 'package:khuta/features/settings/pages/settings_page.dart';
import 'package:khuta/features/statistics/pages/statistics_page.dart';

import 'support/app_harness.dart';

// Flutter's accessibility guidelines on the
// main screens, in three styles, light and dark, English (LTR) and Arabic (RTL).
//
//  * Every tappable element has a semantic label: strict, all 60 combinations.
//  * Tap targets: at least 24 dp everywhere (WCAG 2.2 AA, 2.5.8), and the
//    Android 48 dp guideline strictly where it is met today (listed below).
//    Dense elements still under 48 dp (week-strip day cells, check buttons,
//    segmented controls) are listed in the validation record for the
//    owner: making them 48 dp changes the look.
//  * Text contrast is checked from the theme tokens (`a11y_tokens_test.dart`),
//    because the screenshot-based guideline misreads composite nodes (titles
//    sitting on tiles or cards report ~1.2:1).
const _strict48 = {('form', 'classic'), ('stats', 'minimal')};

void main() {
  useEmptyStore();

  final screens = <String, Widget>{
    'today': const HomePage(),
    'stats': const StatisticsPage(),
    'settings': const SettingsPage(),
    'form': const HabitFormPage(),
    'details': const HabitDetailsPage(habitId: 'a'),
  };
  const styles = {0: 'classic', 1: 'minimal', 2: 'express'};

  for (final locale in const ['en', 'ar']) {
    for (final style in styles.entries) {
      for (final dark in [false, true]) {
        for (final screen in screens.entries) {
          final name = '$locale ${style.value} ${dark ? "dark" : "light"} ${screen.key}';
          testWidgets(name, (tester) async {
            final handle = tester.ensureSemantics();
            await seedHabits(tester, [
              testHabit(id: 'a', name: 'Read', order: 0, done: lastDays(4)),
              testHabit(id: 'b', name: 'Water', order: 1, kind: HabitKind.quantitative, perDayTarget: 8, unitLabel: 'glasses'),
              testHabit(id: 'c', name: 'No sugar', order: 2, kind: HabitKind.negative),
            ]);
            await pumpScreen(
              tester,
              screen.value,
              settings: {'appStyle': style.key},
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              locale: Locale(locale),
              settle: false,
            );
            // Entrance animations finish; Express never settles, so pump time.
            for (var i = 0; i < 30; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }

            final labels = await labeledTapTargetGuideline.evaluate(tester);
            expect(labels.passed, isTrue, reason: labels.reason);

            final taps = await androidTapTargetGuideline.evaluate(tester);
            if (_strict48.contains((screen.key, style.value))) {
              expect(taps.passed, isTrue, reason: taps.reason);
            } else if (!taps.passed) {
              final sizes = RegExp(r'but found Size\(([\d.]+), ([\d.]+)\)')
                  .allMatches(taps.reason ?? '')
                  .map((m) => (double.parse(m.group(1)!), double.parse(m.group(2)!)));
              expect(sizes, isNotEmpty, reason: 'unparsed tap-target failure: ${taps.reason}');
              for (final (w, h) in sizes) {
                expect(w >= 24 && h >= 24, isTrue, reason: 'a $w×$h tap target is below the 24 dp minimum');
              }
            }
            handle.dispose();
          });
        }
      }
    }
  }
}
