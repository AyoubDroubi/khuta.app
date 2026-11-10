import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/app/theme/khuta_palette.dart';

/// WCAG contrast ratio between two opaque colours (1…21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// A habit colour used as text or icon ink on [background].
///
/// On dark backgrounds a colour that is too dark is lightened (hue and
/// saturation kept) until it reaches [min]; on light backgrounds, and for
/// colours that already pass, it is returned unchanged. The identity accent
/// maps to its dark variant, as the theme does.
Color readableOn(Color color, Color background, {double min = 3}) {
  if (background.computeLuminance() > 0.5) return color;
  if (color.toARGB32() == KhutaPalette.current.accent.toARGB32()) {
    final dark = KhutaPalette.current.accentDark;
    if (contrastRatio(dark, background) >= min) return dark;
  }
  if (contrastRatio(color, background) >= min) return color;
  final hsl = HSLColor.fromColor(color);
  for (var l = hsl.lightness + 0.02; l < 1; l += 0.02) {
    final lighter = hsl.withLightness(l).toColor();
    if (contrastRatio(lighter, background) >= min) return lighter;
  }
  return Colors.white;
}

extension HabitInk on BuildContext {
  /// [habitColor] as ink on the raised surfaces of the current theme: 3:1 for
  /// icons and graphics, 4.5:1 for text ([min]).
  Color habitInk(Color habitColor, {double min = 3}) =>
      readableOn(habitColor, colors.surfaceContainerHighest, min: min);
}
