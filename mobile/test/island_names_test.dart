import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// visible island texts describe the oasis,
// not the previous Mediterranean art.
void main() {
  final banned = {
    'en': ['chapel', 'church', 'bell', 'windmill', 'olive', 'cypress', 'shrine', 'mediterranean', 'archipelago', 'harbour', 'cove'],
    'ar': ['كنيسة', 'الكنيسة', 'الجرس', 'طاحونة', 'زيتون', 'سرو', 'مزار', 'متوسطي', 'أرخبيل', 'الميناء', 'الخليج'],
    'es': ['iglesia', 'ermita', 'campanario', 'molino', 'olivo', 'ciprés', 'mediterr', 'archipiélago', 'puerto', 'cala'],
  };
  for (final lang in banned.keys) {
    test('$lang: island texts no longer describe the old art', () {
      final arb = jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
      final keys = arb.keys.where((k) => k.startsWith('island_p_') || k.startsWith('island_g_') || k == 'island_enable_sub' || k == 'island_complete' || k == 'island_empty');
      expect(keys.length, greaterThan(50));
      final hits = <String>[];
      for (final k in keys) {
        final v = (arb[k] as String).toLowerCase();
        for (final w in banned[lang]!) {
          if (v.contains(w.toLowerCase())) hits.add('$k: ${arb[k]} ($w)');
        }
      }
      expect(hits, isEmpty);
    });
  }

  test('every piece kind and group the code names has an English and Arabic text', () {
    final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
    final ar = jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync()) as Map<String, dynamic>;
    final sheets = File('lib/features/island/widgets/island_sheets.dart').readAsStringSync();
    final used = RegExp(r'l10n\.(island_[pg]_[a-z_]+)').allMatches(sheets).map((m) => m.group(1)!).toSet();
    expect(used.length, greaterThan(50));
    for (final k in used) {
      expect((en[k] as String?)?.isNotEmpty, isTrue, reason: 'en $k');
      expect((ar[k] as String?)?.isNotEmpty, isTrue, reason: 'ar $k');
    }
  });
}
