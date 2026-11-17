import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/capture/data/capture_normalize.dart';
import 'package:khuta/features/capture/data/proposed_item.dart';

void main() {
  group('stripMarks', () {
    test('removes diacritics', () {
      expect(stripMarks('مُحَمَّد'), 'محمد');
    });

    test('removes tatweel', () {
      expect(stripMarks('كتــاب'), 'كتاب');
    });
  });

  group('foldLetters', () {
    test('folds alef, ya, ta marbuta and digit forms', () {
      expect(
        foldLetters('الأحد إلى آخر ٥ ۵ ة ى'),
        'الاحد الي اخر 5 5 ه ي',
      );
    });

    test('keeps the length of its input', () {
      const samples = [
        'الأحد إلى آخر ٥ ۵ ة ى',
        'Tomorrow at 2 PM',
        'ٱلسَّلَامُ',
        '😀 ١٢٣ ،؛',
        '',
      ];
      for (final s in samples) {
        expect(foldLetters(s).length, s.length, reason: s);
      }
      for (var i = 0; i < 50; i++) {
        final s = String.fromCharCodes(
          List.generate(20, (j) => 0x0600 + (i * 31 + j * 17) % 0xFF),
        );
        expect(foldLetters(s).length, s.length);
      }
    });
  });

  group('ProposedItem.needsTime', () {
    test('a to-do that asked to be reminded needs a time', () {
      const item = ProposedItem(
        kind: ProposedKind.task,
        title: 'x',
        askedToRemind: true,
      );
      expect(item.needsTime, isTrue);
      expect(item.copyWith(minutes: 600).needsTime, isFalse);
    });

    test('a note never needs a time', () {
      const note = ProposedItem(
        kind: ProposedKind.note,
        title: 'x',
        askedToRemind: true,
      );
      expect(note.needsTime, isFalse);
    });

    test('copyWith can clear the day and the time', () {
      final item = ProposedItem(
        kind: ProposedKind.task,
        title: 'x',
        day: DateTime(2026, 11, 16),
        minutes: 60,
      );
      final cleared = item.copyWith(clearDay: true, clearMinutes: true);
      expect(cleared.day, isNull);
      expect(cleared.minutes, isNull);
    });
  });
}
