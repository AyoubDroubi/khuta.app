import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/island/data/island_art.dart';
import 'package:khuta/features/island/data/island_piece.dart';
import 'package:khuta/features/island/widgets/island_canvas.dart';

// renders the finished island with the app's own painter to a PNG
// (converted to assets/island/preview.webp by the art tool). Opt-in:
//   ISLAND_PREVIEW_OUT=/path/preview.png flutter test test/island_preview_generator_test.dart
void main() {
  final out = Platform.environment['ISLAND_PREVIEW_OUT'];
  testWidgets('render the island preview', (tester) async {
    tester.view.physicalSize = const Size(1888, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final art = (await tester.runAsync(IslandArt.load))!;
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 944,
            height: 1000,
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
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    // Pinch in so the whole island is in view (home zoom is 1.35x the fit).
    final centre = tester.getCenter(find.byType(IslandCanvas));
    final a = await tester.startGesture(centre + const Offset(-140, 0), pointer: 1);
    final b = await tester.startGesture(centre + const Offset(140, 0), pointer: 2);
    for (var i = 1; i <= 10; i++) {
      await a.moveTo(centre + Offset(-140 + 10.0 * i, 0));
      await b.moveTo(centre + Offset(140 - 10.0 * i, 0));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await a.up();
    await b.up();
    await tester.pump(const Duration(seconds: 2));
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File(out!).writeAsBytesSync(bytes!);
  }, skip: out == null);
}
