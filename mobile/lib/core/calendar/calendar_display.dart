import 'package:hijri/hijri_calendar.dart';

/// How dates are shown. Stored as the enum index.
enum CalendarMode { gregorian, hijri, gregorianHijri, hijriGregorian }

/// A Hijri date from the Umm al-Qura calendar (package `hijri`, BSD-2-Clause).
class HijriDay {
  const HijriDay(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  @override
  bool operator ==(Object other) =>
      other is HijriDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$year-$month-$day';
}

/// Inside the Umm al-Qura table shipped by the package (1356–1499 AH).
final _first = DateTime(1938, 1, 1);
final _last = DateTime(2076, 12, 31);

/// The Umm al-Qura date of [date], shifted by [adjust] days (−2…+2) to match
/// local moon sighting. Null outside the supported range.
HijriDay? hijriOf(DateTime date, {int adjust = 0}) {
  // Calendar arithmetic, not a duration: a 24-hour shift can land on the
  // wrong day across a daylight-saving change.
  final day = DateTime(date.year, date.month, date.day + adjust.clamp(-2, 2));
  if (day.isBefore(_first) || day.isAfter(_last)) return null;
  final h = HijriCalendar.fromDate(day);
  return HijriDay(h.hYear, h.hMonth, h.hDay);
}

const _monthsAr = [
  'محرم',
  'صفر',
  'ربيع الأول',
  'ربيع الآخر',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوال',
  'ذو القعدة',
  'ذو الحجة',
];

const _monthsEn = [
  'Muharram',
  'Safar',
  'Rabi al-Awwal',
  'Rabi al-Thani',
  'Jumada al-Ula',
  'Jumada al-Akhirah',
  'Rajab',
  'Shaban',
  'Ramadan',
  'Shawwal',
  'Dhu al-Qadah',
  'Dhu al-Hijjah',
];

/// Hijri month name (1–12) in Arabic, or the English transliteration
/// otherwise (month picker and schedule labels).
String hijriMonthName(int month, String locale) =>
    (locale.startsWith('ar') ? _monthsAr : _monthsEn)[month - 1];

/// “16 جمادى الأولى 1448 هـ” in Arabic, “16 Jumada al-Ula 1448 AH” otherwise.
/// Western digits everywhere.
String formatHijri(HijriDay h, String locale, {bool withYear = true}) {
  final arabic = locale.startsWith('ar');
  final month = (arabic ? _monthsAr : _monthsEn)[h.month - 1];
  if (!withYear) return '${h.day} $month';
  return arabic ? '${h.day} $month ${h.year} هـ' : '${h.day} $month ${h.year} AH';
}

/// Combines the Gregorian label the screen already builds with the Hijri date
/// according to [mode]. Falls back to the Gregorian label outside the range.
String dayLabel(
  DateTime date, {
  required String gregorian,
  required String locale,
  required CalendarMode mode,
  int adjust = 0,
  bool withYear = true,
}) {
  if (mode == CalendarMode.gregorian) return gregorian;
  final h = hijriOf(date, adjust: adjust);
  if (h == null) return gregorian;
  final hijri = formatHijri(h, locale, withYear: withYear);
  return switch (mode) {
    CalendarMode.gregorian => gregorian,
    CalendarMode.hijri => hijri,
    CalendarMode.gregorianHijri => '$gregorian · $hijri',
    CalendarMode.hijriGregorian => '$hijri · $gregorian',
  };
}
