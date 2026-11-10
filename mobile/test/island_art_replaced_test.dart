import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// the island art is the
// generated Arab-oasis set. None of the earlier (third-party) files may remain,
// and every shipped file must match the recorded hash of the generator output.
Map<String, String> _hashes(String path) => {
      for (final line in File(path).readAsLinesSync())
        if (line.trim().isNotEmpty) line.split(RegExp(r'\s+'))[1]: line.split(RegExp(r'\s+'))[0],
    };

String _sha(String path) => sha256.convert(File(path).readAsBytesSync()).toString();

void main() {
  test('no file of the previous island art remains', () {
    final old = _hashes('test/fixtures/island_old_art_sha256.txt');
    expect(old.length, 160);
    final remaining = <String>[];
    for (final e in old.entries) {
      final f = 'assets/island/${e.key}';
      if (File(f).existsSync() && _sha(f) == e.value) remaining.add(e.key);
    }
    expect(remaining, isEmpty);
  });

  test('every shipped island file is the recorded generator output', () {
    final now = _hashes('test/fixtures/island_new_art_sha256.txt');
    expect(now.length, 161); // 160 tiles/sprites/shadows + preview.webp
    final wrong = <String>[];
    for (final e in now.entries) {
      final f = 'assets/island/${e.key}';
      if (!File(f).existsSync() || _sha(f) != e.value) wrong.add(e.key);
    }
    expect(wrong, isEmpty);
    final files = Directory('assets/island')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    expect(files, now.keys.toSet());
  });
}
