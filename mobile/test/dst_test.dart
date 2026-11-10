import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/extensions/date_extensions.dart';

void main() {
  // EU transitions and US transitions: whichever zone the test runs in, at
  // least one of these days is a real clock change.
  final autumn = DateTime(2025, 10, 26);
  final spring = DateTime(2026, 3, 29);
  final usAutumn = DateTime(2025, 11, 2);
  final usSpring = DateTime(2026, 3, 8);
  final transitions = [autumn, spring, usAutumn, usSpring];

  bool shifts(DateTime day) =>
      day.timeZoneOffset != day.addDays(1).timeZoneOffset;

  test('a month grid never repeats or skips a day', () {
    for (final around in transitions) {
      final start = around.addDays(-6);
      final days = List.generate(14, (i) => start.addDays(i));
      for (var i = 1; i < days.length; i++) {
        expect(
          days[i].epochDay - days[i - 1].epochDay,
          1,
          reason: 'salto raro en ${days[i - 1]} -> ${days[i]}',
        );
      }
    }
  });

  test('walking day by day lands on every day once', () {
    for (final around in transitions) {
      var cursor = around.addDays(-3);
      final seen = <int>[];
      for (var i = 0; i < 7; i++) {
        seen.add(cursor.day);
        cursor = cursor.addDays(1);
      }
      expect(seen.toSet().length, 7, reason: 'dias repetidos: $seen');
    }
  });

  test('the week always starts on the same weekday', () {
    for (final around in transitions) {
      for (var i = -7; i <= 7; i++) {
        final day = around.addDays(i);
        for (var weekStart = 1; weekStart <= 7; weekStart++) {
          expect(day.startOfWeek(weekStart).weekday, weekStart);
        }
      }
    }
  });

  test(
    'the clock really changes here, so the checks above mean something',
    () {
      expect(transitions.any(shifts), isTrue);
    },
    skip: transitions.any(shifts)
        ? null
        : 'esta maquina no cambia la hora, el test no prueba nada',
  );
}
