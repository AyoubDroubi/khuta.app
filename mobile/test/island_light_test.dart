import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/features/island/data/island_light.dart';

// the island's sky tone follows the hour.
DateTime _at(int hour, [int minute = 0]) => DateTime(2026, 11, 8, hour, minute);

void main() {
  test('hourOf is the hour with the minutes as a fraction', () {
    expect(IslandLight.hourOf(_at(6, 30)), 6.5);
    expect(IslandLight.hourOf(_at(0)), 0);
  });

  test('day is light; late evening and night are dark', () {
    expect(IslandLight.isDark(_at(12)), isFalse);
    expect(IslandLight.isDark(_at(17)), isFalse);
    expect(IslandLight.isDark(_at(23)), isTrue);
    expect(IslandLight.isDark(_at(3)), isTrue);
  });

  test('midday needs no colour matrix; other hours return a 4×5 matrix', () {
    expect(IslandLight.matrixFor(_at(12)), isNull);
    expect(IslandLight.matrixFor(_at(17)), isNull);
    for (final hour in [0, 5, 7, 19, 21, 23]) {
      final m = IslandLight.matrixFor(_at(hour));
      expect(m, isNotNull, reason: 'hour $hour');
      expect(m!.length, 20);
      expect(m.sublist(15), [0, 0, 0, 1, 0], reason: 'alpha row of $hour');
    }
  });

  test('the tone moves smoothly: neighbouring half hours barely differ', () {
    for (var h = 0; h < 23; h++) {
      final a = IslandLight.matrixFor(_at(h, 0));
      final b = IslandLight.matrixFor(_at(h, 30));
      if (a == null || b == null) continue;
      for (var i = 0; i < 20; i++) {
        expect((a[i] - b[i]).abs(), lessThan(0.25), reason: 'hour $h index $i');
      }
    }
  });

  test('the ghost colour is light on dark themes and at night, dark otherwise', () {
    final dayLight = IslandLight.ghostFor(_at(12), false);
    final dayDarkTheme = IslandLight.ghostFor(_at(12), true);
    final night = IslandLight.ghostFor(_at(23), false);
    expect(dayLight.computeLuminance(), lessThan(0.3));
    expect(dayDarkTheme.computeLuminance(), greaterThan(0.5));
    expect(night, dayDarkTheme);
  });
}
