import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:khuta/app/theme/app_palette.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/app/theme/khuta_palette.dart';
import 'package:khuta/core/express/express_type.dart';
import 'package:khuta/core/minimal/minimal_type.dart';
import 'package:khuta/core/utils/responsive.dart';
import 'package:khuta/app/theme/app_fonts.dart';

class AppTheme {
  const AppTheme._();

  static const _fontFamily = 'Figtree';

  static ThemeData light([Color? accent, int style = 0]) =>
      _build(Brightness.light, accent ?? KhutaPalette.current.accent, style);
  static ThemeData dark([Color? accent, int style = 0]) =>
      _build(Brightness.dark, accent ?? KhutaPalette.current.accent, style);

  /// Warm neutral from the Khuta palette.
  static Color _n(Color grey) => KhutaPalette.current.warm(grey);

  static Color adaptAccent(Color accent, bool isDark) {
    // The identity accent has its own dark-mode variant.
    if (accent.toARGB32() == KhutaPalette.current.accent.toARGB32()) {
      return KhutaPalette.current.accentFor(isDark);
    }
    final luminance = accent.computeLuminance();
    if (isDark && luminance < 0.06) return const Color(0xFFF2F2F2);
    if (!isDark && luminance > 0.82) return const Color(0xFF1C1C1E);
    return accent;
  }

  static SystemUiOverlayStyle systemBars(Brightness brightness) {
    final icons =
        brightness == Brightness.dark ? Brightness.light : Brightness.dark;

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: brightness,
      statusBarIconBrightness: icons,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: icons,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static AppTokens _tokens(bool isDark) {
    final base = isDark ? AppTokens.dark : AppTokens.light;
    return base.copyWith(muted: _n(base.muted));
  }

  static ButtonStyle _expressButton(Color foreground) => ButtonStyle(
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        ),
        textStyle: WidgetStatePropertyAll(
          ExpressType.headline.at(15, weight: 800, color: foreground),
        ),
      );

  static ColorScheme expressScheme(Brightness brightness, Color seed) {
    final dark = brightness == Brightness.dark;
    final accent = adaptAccent(seed, dark);
    final base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    );

    return base.copyWith(
      primary: accent,
      onPrimary: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
      surface: dark ? _n(Color(0xFF121212)) : _n(Color(0xFFF2F2F2)),
      surfaceContainerLowest:
          dark ? _n(Color(0xFF171717)) : _n(Color(0xFFFFFFFF)),
      surfaceContainerLow:
          dark ? _n(Color(0xFF1D1D1D)) : _n(Color(0xFFF7F7F7)),
      surfaceContainer:
          dark ? _n(Color(0xFF242424)) : _n(Color(0xFFFFFFFF)),
      surfaceContainerHigh:
          dark ? _n(Color(0xFF2C2C2C)) : _n(Color(0xFFECECEC)),
      surfaceContainerHighest:
          dark ? _n(Color(0xFF363636)) : _n(Color(0xFFE0E0E0)),
      outlineVariant: dark ? _n(Color(0xFF383838)) : _n(Color(0xFFDCDCDC)),
    );
  }

  static ThemeData _express(Brightness brightness, Color accent) {
    final isDark = brightness == Brightness.dark;
    final scheme = expressScheme(brightness, accent);
    final text = ExpressType.theme(scheme.onSurface);
    final container = scheme.surfaceContainer;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: ExpressType.family,
      fontFamilyFallback: arabicFontFallback,
      textTheme: text,
      visualDensity: VisualDensity.standard,
      splashFactory: NoSplash.splashFactory,
      extensions: [_tokens(isDark)],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: systemBars(brightness),
        foregroundColor: scheme.onSurface,
        titleTextStyle: ExpressType.headline.at(
          26,
          weight: 900,
          spacing: -0.4,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: container,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: phoneWidth),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(34)),
        titleTextStyle: ExpressType.headline.at(
          22,
          weight: 800,
          color: scheme.onSurface,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme:
          FilledButtonThemeData(style: _expressButton(scheme.onPrimary)),
      outlinedButtonTheme:
          OutlinedButtonThemeData(style: _expressButton(scheme.primary)),
      textButtonTheme:
          TextButtonThemeData(style: _expressButton(scheme.primary)),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: container,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  static ThemeData _build(Brightness brightness, Color seed, int style) {
    if (style == 2) return _express(brightness, seed);
    final isDark = brightness == Brightness.dark;
    final minimal = style == 1;
    final accent = adaptAccent(seed, isDark);

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      onPrimary: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
      surface: isDark
          ? (minimal ? _n(AppPalette.paperDark) : _n(AppPalette.darkSurface))
          : (minimal ? _n(Color(0xFFFFFFFF)) : _n(Color(0xFFFAFAFC))),
      surfaceContainer: isDark
          ? (minimal ? _n(AppPalette.paperDarkCard) : _n(Color(0xFF1A1A1A)))
          : (minimal ? _n(Color(0xFFF6F6F8)) : _n(Color(0xFFF4F4F8))),
      surfaceContainerHigh: isDark
          ? (minimal ? _n(Color(0xFF1A1A1A)) : _n(Color(0xFF1F1F22)))
          : (minimal ? _n(Color(0xFFEFEFF2)) : _n(Color(0xFFEDEDF2))),
      surfaceContainerHighest: isDark
          ? (minimal ? _n(AppPalette.paperDarkRaised) : _n(AppPalette.darkElevated))
          : (minimal ? _n(Color(0xFFE9E9EC)) : _n(Color(0xFFEFEFF4))),
      outlineVariant: isDark
          ? (minimal ? _n(Color(0xFF272727)) : _n(AppPalette.darkBorder))
          : (minimal ? _n(Color(0xFFE4E4E8)) : _n(Color(0xFFD9D9E0))),
    );

    final cardColor = isDark
        ? (minimal ? _n(AppPalette.paperDarkCard) : _n(AppPalette.darkCard))
        : (minimal ? _n(Color(0xFFF6F6F8)) : _n(Colors.white));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,

      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: _fontFamily,
      fontFamilyFallback: arabicFontFallback,
      visualDensity: VisualDensity.standard,
      splashFactory: NoSplash.splashFactory,
      extensions: [_tokens(isDark)],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        toolbarHeight: minimal ? null : 64,
        titleSpacing: minimal ? null : 16,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: systemBars(brightness),
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: arabicFontFallback,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: phoneWidth),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: minimal
            ? MinimalType.display(22, color: scheme.onSurface)
            : TextStyle(
                fontFamily: _fontFamily,
                fontFamilyFallback: arabicFontFallback,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme: minimal
          ? const FilledButtonThemeData()
          : FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontFamily: _fontFamily,
                  fontFamilyFallback: arabicFontFallback,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      outlinedButtonTheme: minimal
          ? const OutlinedButtonThemeData()
          : OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                foregroundColor: scheme.primary,
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.75),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontFamily: _fontFamily,
                  fontFamilyFallback: arabicFontFallback,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
