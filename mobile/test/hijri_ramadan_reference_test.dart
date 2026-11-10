import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/calendar/calendar_display.dart';

import 'support/hijri_ramadan_reference.dart';

/// the Umm al-Qura conversion places every day of the reference
/// Ramadan spans in month 9, and the days just outside them elsewhere.
void main() {
  for (final span in ramadanReference) {
    test('Ramadan ${span.hijriYear} covers exactly ${span.days} days', () {
      expect(span.days, anyOf(29, 30));
      for (var i = 0; i < span.days; i++) {
        final day = DateTime(span.start.year, span.start.month, span.start.day + i);
        final h = hijriOf(day)!;
        expect(h.year, span.hijriYear, reason: '$day');
        expect(h.month, 9, reason: '$day');
      }
      final before = DateTime(span.start.year, span.start.month, span.start.day - 1);
      expect(hijriOf(before)!.month, 8);
      expect(hijriOf(span.end)!.month, 10);
    });
  }
}
