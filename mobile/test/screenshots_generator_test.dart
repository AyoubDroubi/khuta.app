import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/island/data/island_art.dart';
import 'package:khuta/features/habits/pages/habit_details_page.dart';
import 'package:khuta/features/habits/pages/home_page.dart';
import 'package:khuta/features/island/pages/island_page.dart';
import 'package:khuta/features/settings/pages/settings_page.dart';
import 'package:khuta/features/statistics/pages/statistics_page.dart';

import 'support/app_harness.dart';

// Opt-in: renders the main screens with the real fonts to PNG files so the app
// can be looked at without a phone.
//   SCREENSHOTS_OUT=/dir flutter test test/screenshots_generator_test.dart
Future<void> _fonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File('fonts/$f').readAsBytesSync())));
    }
    await loader.load();
  }

  await load('Figtree', ['Figtree-Regular.ttf', 'Figtree-Medium.ttf', 'Figtree-SemiBold.ttf', 'Figtree-Bold.ttf']);
  await load('GoogleSansFlex', ['GoogleSansFlex.ttf']);
  await load('IBMPlexSansArabic', ['IBMPlexSansArabic-Regular.ttf', 'IBMPlexSansArabic-Medium.ttf', 'IBMPlexSansArabic-SemiBold.ttf', 'IBMPlexSansArabic-Bold.ttf']);
  await load('PlayfairDisplay', ['PlayfairDisplay.ttf']);
  // Icon fonts (flutter_test ships none): found through the environment.
  final lucide = Platform.environment['LUCIDE_DIR'];
  if (lucide != null) {
    for (final entry in {
      'packages/lucide_icons_flutter/Lucide': 'lucide.ttf',
      'packages/lucide_icons_flutter/Lucide100': 'build_font/LucideVariable-w100.ttf',
      'packages/lucide_icons_flutter/Lucide200': 'build_font/LucideVariable-w200.ttf',
      'packages/lucide_icons_flutter/Lucide300': 'build_font/LucideVariable-w300.ttf',
      'packages/lucide_icons_flutter/Lucide400': 'build_font/LucideVariable-w400.ttf',
      'packages/lucide_icons_flutter/Lucide500': 'build_font/LucideVariable-w500.ttf',
      'packages/lucide_icons_flutter/Lucide600': 'build_font/LucideVariable-w600.ttf',
    }.entries) {
      final f = File('$lucide/assets/${entry.value}');
      if (!f.existsSync()) continue;
      final loader = FontLoader(entry.key)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      await loader.load();
    }
  }
  final material = Platform.environment['MATERIAL_ICONS'];
  if (material != null && File(material).existsSync()) {
    final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(File(material).readAsBytesSync())));
    await loader.load();
  }
}

void main() {
  final out = Platform.environment['SCREENSHOTS_OUT'];
  useEmptyStore();
  const styles = {0: 'classic', 1: 'minimal', 2: 'express'};
  final screens = <String, Widget Function()>{
    'today': () => const HomePage(),
    'stats': () => const StatisticsPage(),
    'details': () => const HabitDetailsPage(habitId: 'a'),
    'settings': () => const SettingsPage(),
    'island': () => const IslandPage(),
  };
  for (final lang in ['ar', 'en']) {
    for (final style in styles.entries) {
      for (final screen in screens.entries) {
        testWidgets('${lang}_${style.value}_${screen.key}', (tester) async {
          await tester.runAsync(_fonts);
          await tester.runAsync(IslandArt.load);
          await seedHabits(tester, [
            testHabit(id: 'a', name: lang == 'ar' ? 'قراءة القرآن' : 'Read', order: 0, done: lastDays(21)),
            testHabit(id: 'b', name: lang == 'ar' ? 'شرب الماء' : 'Water', order: 1, kind: HabitKind.quantitative, perDayTarget: 8, unitLabel: lang == 'ar' ? 'كوب' : 'glasses', done: lastDays(9)),
            testHabit(id: 'c', name: lang == 'ar' ? 'رياضة' : 'Workout', order: 2, done: lastDays(4)),
            testHabit(id: 'd', name: lang == 'ar' ? 'بدون سكر' : 'No sugar', order: 3, kind: HabitKind.negative),
          ]);
          await pumpScreen(
            tester,
            screen.value(),
            settings: {'appStyle': style.key, 'planningEnabled': true, 'islandEnabled': true, 'locale': lang},
            themeMode: ThemeMode.light,
            locale: Locale(lang),
            settle: false,
          );
          for (var i = 0; i < 25; i++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
            await tester.pump(const Duration(milliseconds: 100));
          }
          final boundary = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
          final bytes = await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            return data!.buffer.asUint8List();
          });
          File('$out/${lang}_${style.value}_${screen.key}.png').writeAsBytesSync(bytes!);
        }, skip: out == null);
      }
    }
  }
}
