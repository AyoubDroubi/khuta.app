import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/app/app_background.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/habits/data/completion.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/data/substep.dart';
import 'package:khuta/features/habits/pages/habit_details_page.dart';
import 'package:khuta/features/habits/pages/home_page.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/features/island/data/island_art.dart';
import 'package:khuta/features/island/data/island_catalog.dart';
import 'package:khuta/features/island/pages/island_page.dart';
import 'package:khuta/features/recovery/data/recovery_config.dart';
import 'package:khuta/features/settings/pages/about_page.dart';
import 'package:khuta/features/statistics/pages/statistics_page.dart';

import 'support/app_harness.dart';

// Opt-in: renders showcase screenshots (README, portfolio) with lived-in demo
// data and the real fonts.
//   SHOWCASE_OUT=/dir LUCIDE_DIR=... MATERIAL_ICONS=... \
//     flutter test test/showcase_generator_test.dart
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

/// A deterministic, lived-in history: most days done, a few misses.
Map<String, Completion> _history(int days, int seed, {double count = 1, bool today = true}) {
  final now = AppClock.today();
  return {
    for (var i = today ? 0 : 1; i < days; i++)
      // Recent weeks unbroken, older weeks with an occasional miss.
      if (i < 24 || (i * 7 + seed) % 11 != 0)
        now.addDays(-i).dayKey: Completion(
          date: now.addDays(-i).dayKey,
          count: count,
          hour: 7 + (i + seed) % 12,
          minute: (i * 13) % 60,
        ),
  };
}

List<Habit> _demo(bool ar) {
  final now = AppClock.today();
  String t(String a, String e) => ar ? a : e;
  final water = testHabit(
    id: 'b', name: t('شرب الماء', 'Drink water'), order: 1, color: const Color(0xFF0A84FF),
    kind: HabitKind.quantitative, perDayTarget: 8, unitLabel: t('كوب', 'glasses'), daysOld: 120,
  ).copyWith(
    icon: 'glassWater',
    minimumTargetVersions: [
      HabitMinimumTargetVersion(effectiveDate: now.addDays(-100).dayKey, minimum: 5, recordedAt: DateTime.utc(2026, 1, 1)),
    ],
    completions: {
      ..._history(110, 3, count: 8, today: false),
      now.dayKey: Completion(date: now.dayKey, count: 5, hour: 13),
    },
  );
  return [
    testHabit(id: 'a', name: t('قراءة', 'Read 20 pages'), order: 0, color: const Color(0xFF94492F), daysOld: 140)
        .copyWith(icon: 'bookOpen', completions: _history(130, 1)),
    water,
    testHabit(
      id: 'c', name: t('روتين الصباح', 'Morning routine'), order: 2, color: const Color(0xFFFF9500), daysOld: 90,
      substeps: [
        Substep(id: 's1', title: t('ماء', 'Water')),
        Substep(id: 's2', title: t('تمدد', 'Stretch')),
        Substep(id: 's3', title: t('تخطيط اليوم', 'Plan the day')),
      ],
    ).copyWith(icon: 'sun', completions: {
      for (final e in _history(80, 5, count: 3, today: false).entries)
        e.key: Completion(date: e.value.date, count: 3, steps: const {'s1', 's2', 's3'}, hour: 7),
      now.dayKey: Completion(date: now.dayKey, count: 2, steps: const {'s1', 's2'}, hour: 7),
    }),
    testHabit(id: 'd', name: t('رياضة', 'Workout'), order: 3, color: const Color(0xFF30D158), daysOld: 100,
            interval: HabitInterval.weekdays, scheduleWeekdays: const [1, 2, 3, 4, 5, 6, 7])
        .copyWith(icon: 'dumbbell', completions: _history(95, 7, today: false)),
    testHabit(id: 'e', name: t('بدون سكر', 'No sugar'), order: 4, color: const Color(0xFFFF375F),
            kind: HabitKind.negative, daysOld: 60)
        .copyWith(icon: 'apple', completions: {
      now.addDays(-23).dayKey: Completion(date: now.addDays(-23).dayKey, hour: 21),
    }),
    testHabit(id: 'f', name: t('تأمل', 'Meditate'), order: 5, color: const Color(0xFFBF5AF2), daysOld: 80)
        .copyWith(
      icon: 'brain',
      recovery: RecoveryConfig(enabled: true, enabledAt: now.addDays(-20)),
      completions: {
        for (final e in _history(80, 2).entries)
          if (!parseDayKey(e.key).isAfter(now.addDays(-3))) e.key: e.value,
      },
    ),
  ];
}

void main() {
  final out = Platform.environment['SHOWCASE_OUT'];
  useEmptyStore();
  final styles = {
    for (final s in (Platform.environment['SHOWCASE_STYLES'] ?? 'express').split(','))
      s: {'classic': 0, 'minimal': 1, 'express': 2}[s]!,
  };
  final screens = <String, Widget Function()>{
    '1_today': () => const HomePage(),
    '2_details': () => const HabitDetailsPage(habitId: 'b'),
    '3_stats': () => const StatisticsPage(),
    '4_island': () => const IslandPage(),
    '5_habit': () => const HabitDetailsPage(habitId: 'a'),
    '6_about': () => const AboutPage(),
  };
  for (final lang in ['ar', 'en']) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      for (final style in styles.entries) {
        for (final screen in screens.entries) {
          final name = '${lang}_${style.key}_${theme.name}_${screen.key}';
          testWidgets(name, (tester) async {
            await tester.runAsync(_fonts);
            await tester.runAsync(IslandArt.load);
            await seedHabits(tester, _demo(lang == 'ar'));
            // A partly built island: every fourth piece of the catalogue.
            final owned = [for (var i = 0; i < islandPieces.length; i += 4) islandPieces[i]];
            await tester.runAsync(() async {
              await LocalStore.writeSetting('islandOwned', [for (final p in owned) p.id]);
              await LocalStore.writeSetting('islandSpent', 0);
              await LocalStore.writeSetting('islandName', lang == 'ar' ? 'واحة خُطى' : 'Khuta oasis');
            });
            await pumpScreen(
              tester,
              // Screens paint over the app background, as in the app.
              AppBackground(child: screen.value()),
              settings: {
                'appStyle': style.value,
                'planningEnabled': true,
                'islandEnabled': true,
                'locale': lang,
                'profileName': lang == 'ar' ? 'أيوب' : 'Ayoub',
              },
              themeMode: theme,
              locale: Locale(lang),
              settle: false,
            );
            for (var i = 0; i < 30; i++) {
              await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
              await tester.pump(const Duration(milliseconds: 100));
            }
            final boundary = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
            final bytes = await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2.75);
              final data = await image.toByteData(format: ui.ImageByteFormat.png);
              return data!.buffer.asUint8List();
            });
            File('$out/$name.png').writeAsBytesSync(bytes!);
          }, skip: out == null);
        }
      }
    }
  }
}
