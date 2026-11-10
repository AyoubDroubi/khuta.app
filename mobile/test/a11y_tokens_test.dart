import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/app/theme/app_theme.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/app/theme/habit_ink.dart';

// text colours meet WCAG AA (4.5:1) on
// every surface they are drawn on, in all three styles, light and dark. The
// identity contract (`docs/architecture/khuta-visual-identity.md`) requires it.
void main() {
  const styles = {0: 'classic', 1: 'minimal', 2: 'express'};

  for (final style in styles.entries) {
    for (final dark in [false, true]) {
      final label = '${style.value} ${dark ? "dark" : "light"}';
      final theme = dark ? AppTheme.dark(null, style.key) : AppTheme.light(null, style.key);
      final cs = theme.colorScheme;
      final tokens = theme.extension<AppTokens>()!;
      // The scaffold itself is transparent (the app paints its own background),
      // so text is judged against the surfaces it actually sits on.
      final surfaces = {
        'surface': cs.surface,
        'containerLow': cs.surfaceContainerLow,
        'container': cs.surfaceContainer,
        'containerHigh': cs.surfaceContainerHigh,
        'containerHighest': cs.surfaceContainerHighest,
      };
      final text = {
        'muted': tokens.muted,
        'onSurface': cs.onSurface,
        'onSurfaceVariant': cs.onSurfaceVariant,
      };

      for (final t in text.entries) {
        test('$label: ${t.key} text is ≥ 4.5:1 on every surface', () {
          for (final s in surfaces.entries) {
            expect(
              contrastRatio(t.value, s.value),
              greaterThanOrEqualTo(4.5),
              reason: '${t.key} on ${s.key}',
            );
          }
        });
      }

      test('$label: the primary colour is ≥ 4.5:1 as text on the main surfaces', () {
        for (final s in [cs.surface, cs.surfaceContainer]) {
          expect(contrastRatio(cs.primary, s), greaterThanOrEqualTo(4.5));
        }
      });
    }
  }
}
