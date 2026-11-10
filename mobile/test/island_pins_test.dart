import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/island/data/island_piece.dart';

// the island art may change, its contract may
// not. Piece identifiers, the sprite table and the pixel size of every image are
// pinned from the version before the Arab-oasis art (fixture made in B0).
(int, int) _webpSize(Uint8List b) {
  String tag(int at) => String.fromCharCodes(b.sublist(at, at + 4));
  if (tag(0) != 'RIFF' || tag(8) != 'WEBP') throw StateError('not a webp');
  switch (tag(12)) {
    case 'VP8X':
      int u24(int at) => b[at] | b[at + 1] << 8 | b[at + 2] << 16;
      return (u24(24) + 1, u24(27) + 1);
    case 'VP8L':
      final bits = b[21] | b[22] << 8 | b[23] << 16 | b[24] << 24;
      return ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1);
    case 'VP8 ':
      return ((b[26] | b[27] << 8) & 0x3FFF, (b[28] | b[29] << 8) & 0x3FFF);
  }
  throw StateError('unknown webp chunk ${tag(12)}');
}

void main() {
  final pins = jsonDecode(File('test/fixtures/island_pins.json').readAsStringSync()) as Map<String, dynamic>;

  test('the set of piece identifiers and their placement are unchanged', () {
    final now = [
      for (final p in islandPieces) [p.id, p.art, p.gx, p.gy, p.level, p.price, p.group.name, p.mirror],
    ];
    expect(now.length, (pins['pieces'] as List).length);
    expect(jsonEncode(now), jsonEncode(pins['pieces']));
  });

  test('the sprite table (keys, grid footprint, size, anchor) is unchanged', () {
    final sprites = pins['sprites'] as Map<String, dynamic>;
    expect(islandSprites.keys.toSet(), sprites.keys.toSet());
    for (final e in sprites.entries) {
      final s = islandSprites[e.key]!;
      final v = e.value as Map<String, dynamic>;
      expect([s.cols, s.rows, s.size.width, s.size.height, s.anchor.dx, s.anchor.dy, s.shadow, s.flat, s.base, s.pad],
          [v['cols'], v['rows'], v['w'], v['h'], v['ax'], v['ay'], v['shadow'], v['flat'], v['base'], v['pad']],
          reason: e.key);
    }
  });

  test('terrain kinds are unchanged', () {
    expect(islandTiles.values.toList()..sort(), pins['terrainKinds']);
  });

  test('every image exists with the pixel size the layout was made for', () {
    final sizes = (pins['imageSizes'] as Map<String, dynamic>).cast<String, List<dynamic>>();
    expect(sizes.length, 160);
    for (final e in sizes.entries) {
      final f = File('assets/island/${e.key}.webp');
      expect(f.existsSync(), isTrue, reason: e.key);
      final (w, h) = _webpSize(f.readAsBytesSync());
      expect([w, h], [e.value[0], e.value[1]], reason: e.key);
    }
  });

  test('every sprite and shadow the code asks for has a file; sprites are drawn at 2x', () {
    final sizes = (pins['imageSizes'] as Map<String, dynamic>).cast<String, List<dynamic>>();
    for (final e in islandSprites.entries) {
      expect(sizes.containsKey(e.key), isTrue, reason: e.key);
      if (e.value.base.isNotEmpty) expect(sizes.containsKey('s_${e.value.base}'), isTrue, reason: 's_${e.value.base}');
      expect((sizes[e.key]![0] as int) / e.value.size.width, closeTo(2, 0.02), reason: e.key);
    }
    for (final kind in islandTiles.values) {
      for (var flip = 0; flip < 4; flip++) {
        expect(sizes.containsKey('t_${kind}_$flip'), isTrue, reason: '$kind $flip');
      }
    }
  });
}
