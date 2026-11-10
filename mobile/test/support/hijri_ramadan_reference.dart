import 'package:khuta/core/extensions/date_extensions.dart';

/// Ramadan reference spans (Umm al-Qura, published dates), shared by the
/// the Hijri tests. `start` is 1 Ramadan; `end` is 1 Shawwal (exclusive).
/// Same sources as the reference table in `calendar_display_test.dart`.
class RamadanSpan {
  const RamadanSpan(this.hijriYear, this.start, this.end);

  final int hijriYear;
  final DateTime start;
  final DateTime end;

  // Calendar days, not a Duration: a clock change inside Ramadan makes
  // `difference().inDays` one short (found by running under TZ=America/New_York).
  int get days => end.epochDay - start.epochDay;
}

final ramadanReference = [
  RamadanSpan(1445, DateTime(2024, 3, 11), DateTime(2024, 4, 10)),
  RamadanSpan(1446, DateTime(2025, 3, 1), DateTime(2025, 3, 30)),
  RamadanSpan(1447, DateTime(2026, 2, 18), DateTime(2026, 3, 20)),
];
