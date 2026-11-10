import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/app/theme/app_theme.dart';
import 'package:khuta/app/theme/habit_ink.dart';
import 'package:khuta/app/theme/khuta_palette.dart';

// the default habit colour is readable
// on the dark surfaces of all three styles.
void main() {
  final accent = KhutaPalette.current.accent;
  const styles = {0: 'classic', 1: 'minimal', 2: 'express'};

  for (final style in styles.entries) {
    final theme = AppTheme.dark(null, style.key);
    final surfaces = {
      'scaffold': theme.scaffoldBackgroundColor,
      'surface': theme.colorScheme.surface,
      'container': theme.colorScheme.surfaceContainer,
      'highest': theme.colorScheme.surfaceContainerHighest,
    };
    for (final surface in surfaces.entries) {
      test('${style.value} dark / ${surface.key}: identity colour ≥ 4.5:1 text, ≥ 3:1 UI', () {
        final text = readableOn(accent, surface.value, min: 4.5);
        final ui = readableOn(accent, surface.value);
        expect(contrastRatio(text, surface.value), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(ui, surface.value), greaterThanOrEqualTo(3));
      });
    }
    test('${style.value} dark: habitInk uses the highest surface, so it also passes on lower ones', () {
      final highest = theme.colorScheme.surfaceContainerHighest;
      final ink = readableOn(accent, highest, min: 4.5);
      for (final lower in [theme.scaffoldBackgroundColor, theme.colorScheme.surface]) {
        expect(contrastRatio(ink, lower), greaterThanOrEqualTo(contrastRatio(ink, highest)));
      }
    });
  }

  test('the raw identity colour fails on dark surfaces (the reported problem)', () {
    final card = AppTheme.dark().colorScheme.surfaceContainerHighest;
    expect(contrastRatio(accent, card), lessThan(3));
  });

  test('identity colour maps to its dark variant, as in the theme', () {
    final card = AppTheme.dark().colorScheme.surfaceContainerHighest;
    expect(readableOn(accent, card, min: 4.5), KhutaPalette.current.accentDark);
  });

  test('light backgrounds are never changed', () {
    for (final c in [accent, const Color(0xFF006689), const Color(0xFFFFD60A)]) {
      expect(readableOn(c, Colors.white), c);
      expect(readableOn(c, AppTheme.light().colorScheme.surface), c);
    }
  });

  test('colours that already pass on dark are unchanged', () {
    const bg = Color(0xFF1A1A1A);
    for (final c in [const Color(0xFF30D158), const Color(0xFF5AC8FA), const Color(0xFFFFD60A)]) {
      expect(contrastRatio(c, bg), greaterThanOrEqualTo(4.5));
      expect(readableOn(c, bg, min: 4.5), c);
    }
  });

  test('a dark user colour is lightened with its hue kept and reaches the minimum', () {
    const bg = Color(0xFF232326);
    const navy = Color(0xFF006689);
    final ink = readableOn(navy, bg, min: 4.5);
    expect(contrastRatio(ink, bg), greaterThanOrEqualTo(4.5));
    expect((HSLColor.fromColor(ink).hue - HSLColor.fromColor(navy).hue).abs(), lessThan(8));
    expect(HSLColor.fromColor(ink).lightness, greaterThan(HSLColor.fromColor(navy).lightness));
  });

  test('pure black on a dark background falls back to white, never loops', () {
    expect(readableOn(Colors.black, const Color(0xFF121212), min: 4.5), isNot(Colors.black));
  });
}
