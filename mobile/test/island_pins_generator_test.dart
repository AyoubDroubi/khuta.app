import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/island/data/island_piece.dart';

// writes the pins of the CURRENT island catalog (identifiers,
// sprite table, terrain kinds) to test/fixtures/island_pins.json. Opt-in:
//   ISLAND_PINS_OUT=test/fixtures/island_pins.json flutter test <this file>
void main() {
  final out = Platform.environment['ISLAND_PINS_OUT'];
  test('write island pins', () {
    final sprites = {
      for (final e in islandSprites.entries)
        e.key: {
          'cols': e.value.cols,
          'rows': e.value.rows,
          'w': e.value.size.width,
          'h': e.value.size.height,
          'ax': e.value.anchor.dx,
          'ay': e.value.anchor.dy,
          'shadow': e.value.shadow,
          'flat': e.value.flat,
          'base': e.value.base,
          'pad': e.value.pad,
        },
    };
    final pieces = [
      for (final p in islandPieces)
        [p.id, p.art, p.gx, p.gy, p.level, p.price, p.group.name, p.mirror],
    ];
    File(out!).writeAsStringSync(const JsonEncoder.withIndent(' ').convert({
      'sprites': sprites,
      'pieces': pieces,
      'terrainKinds': islandTiles.values.toList()..sort(),
    }));
  }, skip: out == null ? 'opt-in: set ISLAND_PINS_OUT' : false);
}
