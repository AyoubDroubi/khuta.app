import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The typed sentence never leaves the device and is never logged or kept.
void main() {
  final files = Directory('lib/features/capture')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('the capture feature has source files to scan', () {
    expect(files, isNotEmpty);
  });

  final forbidden = <String, RegExp>{
    'print': RegExp(r'(^|[^\w.])print\('),
    'debugPrint': RegExp(r'debugPrint\('),
    'log': RegExp(r'(^|[^\w])log\('),
    'dart:developer': RegExp(r'dart:developer'),
    'network': RegExp(r'dart:io|package:http|HttpClient|Socket|WebSocket'),
    'preferences': RegExp(r'SharedPreferences'),
    'direct store write': RegExp(r'LocalStore\.(write|put|set)'),
  };

  for (final file in files) {
    test('${file.path} does not log, store or send text', () {
      final source = file.readAsStringSync();
      for (final entry in forbidden.entries) {
        expect(entry.value.hasMatch(source), isFalse,
            reason: '${file.path} uses ${entry.key}');
      }
    });
  }
}
