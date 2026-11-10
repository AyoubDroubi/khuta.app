import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/routing/app_navigator.dart';
import 'package:khuta/core/widgets/sheet_type.dart';
import 'package:khuta/features/focus/state/focus_controller.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/island/data/island_piece.dart';
import 'package:khuta/features/island/pages/island_page.dart';
import 'package:khuta/features/island/state/island_controller.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';

class IslandEntry extends StatelessWidget {
  const IslandEntry({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.watch<SettingsController>().islandEnabled) {
      return const SizedBox.shrink();
    }
    final island = context.watch<IslandController>();
    final ledger = island.ledgerFor(
      context.watch<HabitsController>().habits,
      context.watch<FocusController>().sessions,
      context.watch<TodosController>().all,
    );
    final balance = island.balanceFrom(ledger);
    final total = islandPieces.length;
    final done = island.built / total;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final sea = dark ? const Color(0xFF123246) : const Color(0xFF9FD8EE);
    final surface = Color.alphaBlend(
      sea.withValues(alpha: dark ? 0.20 : 0.30),
      scheme.surfaceContainerHighest,
    );
    final grow = MediaQuery.textScalerOf(context).scale(14) / 14;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => AppNavigator.push(const IslandPage()),
          child: SizedBox(
            height: 132 * (grow < 1.0 ? 1.0 : (grow > 1.9 ? 1.9 : grow)),
            child: Stack(
              children: [
                PositionedDirectional(
                  end: -26,
                  top: -18,
                  bottom: -26,
                  child: Opacity(
                    opacity: dark ? 0.40 : 0.72,
                    child: Image.asset(
                      'assets/island/preview.webp',
                      fit: BoxFit.contain,
                      cacheHeight: 800,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      // Opaque on the text (start) side in both directions.
                      gradient: LinearGradient(
                        begin: Directionality.of(context) == TextDirection.rtl
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        end: Directionality.of(context) == TextDirection.rtl
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        colors: [
                          surface,
                          surface.withValues(alpha: 0.96),
                          surface.withValues(alpha: 0.12),
                        ],
                        stops: const [0, 0.54, 1],
                      ),
                    ),
                  ),
                ),
                Padding(
                  // 12 dp, not 16: Arabic text lines are taller and overflowed the
                  // 100 dp content area by 3–5 dp.
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            LucideIcons.coins,
                            size: 15,
                            color: _ink(dark),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$balance',
                            style: sheetHeadingStyle(
                              context,
                              size: 15,
                              color: _ink(dark),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            island.name.isEmpty
                                ? context.l10n.island_default_name
                                : island.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: sheetTitleStyle(
                              context,
                              size: 20,
                              color: _ink(dark),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 180,
                            child: Text(
                              island.complete
                                  ? context.l10n.island_complete
                                  : context.l10n.island_built(
                                      '${island.built}',
                                      '$total',
                                    ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: sheetBodyStyle(
                                context,
                                size: 12.5,
                                color: _ink(dark).withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 150,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: done,
                                minHeight: 5,
                                color: scheme.primary,
                                backgroundColor:
                                    _ink(dark).withValues(alpha: 0.18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _ink(bool dark) =>
      dark ? const Color(0xFFE9F4FA) : const Color(0xFF11384C);
}
