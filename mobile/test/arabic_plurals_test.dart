import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/l10n/app_localizations_ar.dart';

// Arabic count strings use the right
// noun form for 1, 2, 3–10, 11–99 and 100+.
void main() {
  final l = AppLocalizationsAr();

  void table(String name, String Function(int) f, Map<int, String> expected) {
    test(name, () {
      for (final e in expected.entries) {
        expect(f(e.key), e.value, reason: '$name(${e.key})');
      }
    });
  }

  table('every_n_days', l.every_n_days, {
    1: 'كل يوم',
    2: 'كل يومين',
    3: 'كل 3 أيام',
    10: 'كل 10 أيام',
    11: 'كل 11 يومًا',
    99: 'كل 99 يومًا',
    100: 'كل 100 يوم',
  });
  table('every_n_weeks', l.every_n_weeks, {
    2: 'كل أسبوعين',
    5: 'كل 5 أسابيع',
    12: 'كل 12 أسبوعًا',
  });
  table('every_n_months', l.every_n_months, {
    2: 'كل شهرين',
    6: 'كل 6 أشهر',
    11: 'كل 11 شهرًا',
  });
  table('times_per_week', l.times_per_week, {
    1: 'مرة واحدة في الأسبوع',
    2: 'مرتان في الأسبوع',
    3: '3 مرات في الأسبوع',
    10: '10 مرات في الأسبوع',
    11: '11 مرة في الأسبوع',
  });
  table('times_per_month', l.times_per_month, {
    1: 'مرة واحدة في الشهر',
    2: 'مرتان في الشهر',
    5: '5 مرات في الشهر',
    25: '25 مرة في الشهر',
  });
  table('focus_end_tasks', l.focus_end_tasks, {
    1: 'لم تُنجز مهمة واحدة بعد.',
    2: 'لم تُنجز مهمتين بعد.',
    4: 'لم تُنجز 4 مهام بعد.',
    12: 'لم تُنجز 12 مهمة بعد.',
  });
  table('island_need', l.island_need, {
    1: 'تبقّت نقطة واحدة',
    2: 'تبقّت نقطتان',
    7: 'تبقّت 7 نقاط',
    30: 'تبقّت 30 نقطة',
  });
  table('streak_unit_week', l.streak_unit_week, {
    1: '1 أسبوع',
    2: 'أسبوعان',
    3: '3 أسابيع',
    11: '11 أسبوعًا',
  });
  table('streak_unit_month', l.streak_unit_month, {
    1: '1 شهر',
    2: 'شهران',
    4: '4 أشهر',
    13: '13 شهرًا',
  });

  test('import_from_app_done inflects both counts', () {
    expect(l.import_from_app_done(1, 1, 'Khuta'), 'تم استيراد عادة واحدة (يوم واحد) من Khuta');
    expect(l.import_from_app_done(2, 5, 'Khuta'), 'تم استيراد عادتين (5 أيام) من Khuta');
    // 365 → 65 (mod 100) → “many” in CLDR → «365 يومًا»; 300 → “other”.
    expect(l.import_from_app_done(7, 365, 'Khuta'), 'تم استيراد 7 عادات (365 يومًا) من Khuta');
    expect(l.import_from_app_done(7, 300, 'Khuta'), 'تم استيراد 7 عادات (300 يوم) من Khuta');
    expect(l.import_from_app_done(12, 20, 'X'), 'تم استيراد 12 عادة (20 يومًا) من X');
  });

  test('Arabic output never contains Eastern Arabic digits', () {
    final digits = RegExp('[٠-٩۰-۹]');
    for (final n in [1, 2, 3, 11, 100]) {
      for (final s in [
        l.every_n_days(n),
        l.times_per_week(n),
        l.focus_end_tasks(n),
        l.island_need(n),
        l.streak_unit_week(n),
      ]) {
        expect(digits.hasMatch(s), isFalse, reason: s);
      }
    }
  });
}
