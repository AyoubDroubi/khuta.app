import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/island/data/island_art.dart';
import 'package:khuta/features/island/data/island_piece.dart';
import 'package:khuta/features/island/widgets/island_canvas.dart';

// the new art loads and the first island frame is drawn
// within the first-frame budget (<= 3 s in tests).
void main() {
  testWidgets('decoding all island art and painting the first frame takes under 3 s', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final clock = Stopwatch()..start();
    final art = (await tester.runAsync(IslandArt.load))!;
    await tester.pumpWidget(
      Directionality(
        textDirection: ui.TextDirection.ltr,
        child: SizedBox(
          width: 393,
          height: 850,
          child: IslandCanvas(
            art: art,
            owned: {for (final p in islandPieces) p.id},
            ghost: const Color(0x00000000),
            light: null,
            turn: ValueNotifier(0),
            onPick: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    clock.stop();
    expect(clock.elapsed, lessThan(const Duration(seconds: 3)), reason: '${clock.elapsedMilliseconds} ms');
    // ignore: avoid_print
    print('island art decode + first frame: ${clock.elapsedMilliseconds} ms');
  });
}
