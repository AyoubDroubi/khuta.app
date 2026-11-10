import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// tools/island_art regenerates every tile, sprite and
// shadow byte for byte. Opt-in (needs python3 with Pillow 12.3.0; about 90 s):
//   ISLAND_REGEN=1 flutter test test/island_art_regeneration_test.dart
// preview.webp is not part of this check: it is rendered by the app itself
// (see tools/island_art/README.md).
void main() {
  final on = Platform.environment['ISLAND_REGEN'] == '1';
  test('the generator reproduces the shipped island art', () {
    final out = Directory.systemTemp.createTempSync('island_regen');
    addTearDown(() => out.deleteSync(recursive: true));
    final run = Process.runSync('python3', ['../tools/island_art/generate.py', out.path]);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    final recorded = {
      for (final line in File('test/fixtures/island_new_art_sha256.txt').readAsLinesSync())
        if (line.trim().isNotEmpty) line.split(RegExp(r'\s+'))[1]: line.split(RegExp(r'\s+'))[0],
    }..remove('preview.webp');
    expect(recorded.length, 160);
    final different = <String>[];
    for (final e in recorded.entries) {
      final f = File('${out.path}/${e.key}');
      if (!f.existsSync() || sha256.convert(f.readAsBytesSync()).toString() != e.value) different.add(e.key);
    }
    expect(different, isEmpty);
  }, skip: !on, timeout: const Timeout(Duration(minutes: 6)));
}
