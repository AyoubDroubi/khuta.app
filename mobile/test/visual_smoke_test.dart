import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/app/home_shell.dart';
import 'package:khuta/features/settings/pages/settings_page.dart';
import 'package:khuta/features/statistics/pages/statistics_page.dart';

import 'support/app_harness.dart';
import 'support/visual_harness.dart';

// every main screen renders in every style and theme without a
// layout exception. Later batches add the Arabic (RTL) locale to the matrix.
// Run with SCREENSHOT_DIR=<dir> to also write PNGs for visual review.
void main() {
  useEmptyStore();

  setUpAll(loadAppFonts);

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => <String, dynamic>{
        'appName': 'test',
        'packageName': 'test',
        'version': '0.0.0',
        'buildNumber': '0',
      },
    );
  });

  const styles = {0: 'classic', 1: 'minimal', 2: 'express'};
  const themes = {ThemeMode.light: 'light', ThemeMode.dark: 'dark'};
  final screens = <String, Widget>{
    'today': const HomeShell(),
    'stats': const StatisticsPage(),
    'settings': const SettingsPage(),
  };
  const locales = <Locale>[Locale('en'), Locale('ar')];

  for (final locale in locales) {
    for (final style in styles.entries) {
      for (final theme in themes.entries) {
        for (final screen in screens.entries) {
          final name =
              '${locale.languageCode}_${style.value}_${theme.value}_${screen.key}';
          testWidgets('renders $name', (tester) async {
            await seedHabits(tester, [
              testHabit(id: 'a', name: 'Read', order: 0, done: lastDays(5)),
              testHabit(id: 'b', name: 'Water', order: 1, done: lastDays(2)),
            ]);
            await pumpScreen(
              tester,
              screen.value,
              settings: {'appStyle': style.key},
              themeMode: theme.key,
              locale: locale,
              // Express keeps a looping animation, so do not wait to settle.
              settle: false,
            );
            for (var i = 0; i < 5; i++) {
              await tester.pump(const Duration(milliseconds: 400));
            }
            expect(tester.takeException(), isNull);
            // No Eastern Arabic digits anywhere on screen.
            final eastern = RegExp('[٠-٩۰-۹]');
            for (final widget in tester.widgetList<RichText>(
              find.byType(RichText),
            )) {
              final text = widget.text.toPlainText();
              expect(eastern.hasMatch(text), isFalse, reason: text);
            }
            await captureScreen(tester, name);
          });
        }
      }
    }
  }
}
