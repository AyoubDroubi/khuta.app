import 'package:flutter/painting.dart';

/// Khuta identity colours: a terracotta accent with warm
/// sand neutrals in light mode and warm charcoal in dark mode.
///
/// Each style keeps its own neutral lightness; [warm] only moves a neutral
/// grey to the palette's hue, so the layout character and contrast of
/// Classic, Minimal and Express stay as they were.
class KhutaPalette {
  const KhutaPalette({
    required this.id,
    required this.accent,
    required this.accentDark,
    required this.hue,
    required this.lightSaturation,
    required this.darkSaturation,
  });

  final String id;

  /// Default accent in light mode (white text on it passes WCAG AA).
  final Color accent;

  /// The same accent tuned for dark backgrounds.
  final Color accentDark;

  /// Hue of the neutrals, in degrees.
  final double hue;
  final double lightSaturation;
  final double darkSaturation;

  /// “فخّار هادئ” — chosen by the owner.
  static const clay = KhutaPalette(
    id: 'C',
    accent: Color(0xFF94492F),
    accentDark: Color(0xFFD7957A),
    hue: 28,
    lightSaturation: 0.28,
    darkSaturation: 0.10,
  );

  /// The palette in use.
  static const KhutaPalette current = clay;

  /// Moves a neutral [grey] to this palette's hue, keeping its lightness.
  /// Colours that are already saturated (accents, status colours) are
  /// returned unchanged.
  Color warm(Color grey) {
    final hsl = HSLColor.fromColor(grey);
    if (hsl.saturation > 0.2) return grey;
    final l = hsl.lightness;
    // Pure white and black stay pure so the “plain” backgrounds keep meaning.
    if (l >= 0.995 || l <= 0.005) return grey;
    final s = l >= 0.5 ? lightSaturation : darkSaturation;
    return HSLColor.fromAHSL(hsl.alpha, hue, s, l).toColor();
  }

  /// The default accent adapted to the brightness.
  Color accentFor(bool dark) => dark ? accentDark : accent;
}
