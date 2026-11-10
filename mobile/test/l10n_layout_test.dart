import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/pages/habit_details_page.dart';
import 'package:khuta/features/habits/pages/habit_form_page.dart';
import 'package:khuta/features/habits/pages/home_page.dart';
import 'package:khuta/features/settings/pages/settings_page.dart';

import 'support/app_harness.dart';

// The longest and the right-to-left languages keep the main screens free of
// layout errors in the three styles.
void main() {
  useEmptyStore();

  const locales = ['de', 'ru', 'fa', 'he', 'id', 'pl', 'hi', 'ko'];
  const styles = {0: 'classic', 1: 'minimal', 2: 'express'};

  final screens = <String, Widget Function()>{
    'today': () => const HomePage(),
    'form': () => const HabitFormPage(),
    'settings': () => const SettingsPage(),
    'details': () => const HabitDetailsPage(habitId: 'a'),
  };

  for (final locale in locales) {
    for (final style in styles.entries) {
      for (final screen in screens.entries) {
        testWidgets('$locale ${style.value} ${screen.key}', (tester) async {
          await seedHabits(tester, [
            testHabit(id: 'a', name: 'Read', order: 0, done: lastDays(3)),
            testHabit(
              id: 'b',
              name: 'Water',
              order: 1,
              kind: HabitKind.quantitative,
              perDayTarget: 8,
              unitLabel: 'glasses',
            ),
          ]);
          await pumpScreen(
            tester,
            screen.value(),
            settings: {'appStyle': style.key},
            locale: Locale(locale),
            settle: false,
          );
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 10));
        });
      }
    }
  }
}
