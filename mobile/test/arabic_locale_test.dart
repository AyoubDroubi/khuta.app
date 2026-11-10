import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:khuta/features/settings/settings_actions.dart';
import 'package:khuta/l10n/app_localizations.dart';

// Arabic is shipped, complete, and uses
// Western digits.
Map<String, dynamic> _arb(String code) =>
    jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _placeholders(String text) =>
    RegExp(r'\{(\w+)[,}]').allMatches(text).map((m) => m.group(1)!).toSet();

final _easternDigits = RegExp('[٠-٩۰-۹]');

void main() {
  test('Arabic is a shipped language', () {
    expect(
      SettingsActions.shippedLocales.map((l) => l.languageCode),
      contains('ar'),
    );
  });

  test('the Arabic file has every English key and the same placeholders', () {
    final en = _arb('en');
    final ar = _arb('ar');
    final keys = en.keys.where((k) => !k.startsWith('@'));
    for (final key in keys) {
      expect(ar.containsKey(key), isTrue, reason: 'missing $key');
      expect(
        _placeholders(ar[key] as String),
        _placeholders(en[key] as String),
        reason: 'placeholders differ for $key',
      );
    }
  });

  test('Arabic strings never use Eastern Arabic digits', () {
    final ar = _arb('ar');
    for (final entry in ar.entries.where((e) => !e.key.startsWith('@'))) {
      expect(
        _easternDigits.hasMatch(entry.value as String),
        isFalse,
        reason: entry.key,
      );
    }
  });

  test('numbers and dates format with Western digits in Arabic', () async {
    await initializeDateFormatting('ar');
    final number = NumberFormat.decimalPattern('ar').format(1234567);
    final date = DateFormat.yMMMMd('ar').format(DateTime(2026, 11, 8));
    expect(_easternDigits.hasMatch(number), isFalse, reason: number);
    expect(_easternDigits.hasMatch(date), isFalse, reason: date);
  });

  test('the legal attribution keeps Streak and InlitX in Arabic', () {
    final strings = lookupAppLocalizations(const Locale('ar'));
    expect(strings.legal_attribution, contains('Streak'));
    expect(strings.legal_attribution, contains('InlitX'));
  });
}
