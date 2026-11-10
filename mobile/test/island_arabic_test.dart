import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/island/data/island_art.dart';
import 'package:khuta/features/island/data/island_piece.dart';
import 'package:khuta/features/island/pages/island_page.dart';
import 'package:khuta/features/island/widgets/island_sheets.dart';

import 'support/app_harness.dart';

// the island page with the new Arabic texts lays out
// without overflow, at normal and large text sizes.
void main() {
  useEmptyStore();
  // Decode the art once in the real zone; a load started inside a widget test's
  // fake-async zone would never finish and would be cached for later tests.
  setUpAll(IslandArt.load);

  for (final scale in [1.0, 1.4]) {
    testWidgets('Arabic island page at text scale $scale has no layout error', (tester) async {
      await pumpScreen(
        tester,
        const IslandPage(),
        settings: {'islandEnabled': true},
        locale: const Locale('ar'),
        textScale: scale,
        settle: false,
      );
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(IslandPage), findsOneWidget);
    });
  }

  testWidgets('with coins to spend the next-piece chips lay out (Arabic and English)', (tester) async {
    await seedHabits(tester, [
      testHabit(id: 'a', name: 'Read', order: 0, done: lastDays(21)),
      testHabit(id: 'b', name: 'Water', order: 1, done: lastDays(9)),
      testHabit(id: 'c', name: 'Walk', order: 2, done: lastDays(4)),
    ]);
    for (final lang in ['ar', 'en']) {
      await pumpScreen(
        tester,
        const IslandPage(),
        settings: {'islandEnabled': true},
        locale: Locale(lang),
        settle: false,
      );
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull, reason: lang);
    }
  });

  testWidgets('the Arabic shop and piece sheets lay out at large text', (tester) async {
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => showIslandShopSheet(context, owned: const {}, balance: 5000),
                child: const Text('shop'),
              ),
              TextButton(
                onPressed: () => showIslandPieceSheet(
                  context,
                  piece: islandPieces.firstWhere((p) => p.art == 'tower_chapel'),
                  owned: false,
                  balance: 100,
                  onBuy: () {},
                ),
                child: const Text('piece'),
              ),
            ],
          ),
        ),
      ),
      locale: const Locale('ar'),
      textScale: 1.4,
    );
    await tester.tap(find.text('shop'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.text('piece'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('مئذنة'), findsWidgets);
  });
}
