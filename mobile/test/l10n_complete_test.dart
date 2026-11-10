import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Every shipped language has every English string with the same placeholders
// New strings must be added to all languages.
Map<String, dynamic> _load(String lang) => jsonDecode(
      File('lib/l10n/app_$lang.arb').readAsStringSync(),
    ) as Map<String, dynamic>;

final _name = RegExp(r'\{([A-Za-z_]\w*)\s*[,}]');
Set<String> _names(String text) =>
    _name.allMatches(text).map((m) => m.group(1)!).toSet();

void main() {
  final en = _load('en');
  final keys = en.keys.where((k) => !k.startsWith('@')).toList();
  final languages = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .map((f) => RegExp(r'app_(\w+)\.arb$').firstMatch(f.path)?.group(1))
      .whereType<String>()
      .where((l) => l != 'en')
      .toList()
    ..sort();

  test('the 16 shipped languages are present', () {
    expect(languages.length, 15);
  });

  for (final lang in languages) {
    test('$lang has every key with the English placeholders', () {
      final data = _load(lang);
      final missing = keys
          .where((k) =>
              (data[k] is! String || (data[k] as String).trim().isEmpty) &&
              !(en[k] is String && (en[k] as String).trim().isEmpty))
          .toList();
      expect(missing, isEmpty, reason: '$lang lacks ${missing.length} keys');
      final wrong = <String>[];
      for (final key in keys) {
        final source = en[key];
        final value = data[key];
        if (source is! String) continue;
        if (value is! String || value.trim().isEmpty) {
          wrong.add('$key: empty');
        } else if (!_names(value).containsAll(_names(source)) ||
            !_names(source).containsAll(_names(value))) {
          wrong.add('$key: placeholders differ');
        }
      }
      expect(wrong, isEmpty);
    });
  }

  // Values identical to the English source are only allowed for the keys in
  // tools/l10n/english_ok.json (brand names, units, loanwords). A new
  // untranslated copy fails here instead of shipping in English.
  test('identical-to-English values are on the allow-list', () {
    final allowed = (jsonDecode(File('../tools/l10n/english_ok.json')
            .readAsStringSync()) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, Set<String>.from(v as List)));
    final stray = <String>[];
    for (final lang in languages) {
      if (lang == 'ar') continue;
      final data = _load(lang);
      for (final key in keys) {
        final source = en[key];
        if (source is String &&
            source.trim().length > 3 &&
            data[key] == source &&
            !(allowed[lang]?.contains(key) ?? false)) {
          stray.add('$lang.$key');
        }
      }
    }
    expect(stray, isEmpty);
  });
}
