import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/express/express_surface.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/minimal/minimal_kit.dart';
import 'package:khuta/core/widgets/sheet_type.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';

/// One immutable change of the minimum or the full target.
class TargetChange {
  const TargetChange({
    required this.day,
    required this.recordedAt,
    required this.amount,
    required this.isMinimum,
  });

  final DateTime day;
  final DateTime recordedAt;
  final double amount;
  final bool isMinimum;
}

/// Newest first. Empty when the habit never had a minimum (nothing to show).
List<TargetChange> targetChanges(Habit habit) {
  if (habit.kind == HabitKind.negative ||
      habit.minimumTargetVersions.isEmpty) {
    return const [];
  }
  final out = <TargetChange>[
    for (final v in habit.minimumTargetVersions)
      if (v.effectiveDate.isNotEmpty)
        TargetChange(
          day: parseDayKey(v.effectiveDate),
          recordedAt: v.recordedAt,
          amount: v.minimum,
          isMinimum: true,
        ),
    for (final v in habit.maximumTargetVersions)
      if (v.effectiveDate.isNotEmpty)
        TargetChange(
          day: parseDayKey(v.effectiveDate),
          recordedAt: v.recordedAt,
          amount: v.maximum,
          isMinimum: false,
        ),
  ]..sort((a, b) {
      final byDay = b.day.compareTo(a.day);
      return byDay != 0 ? byDay : b.recordedAt.compareTo(a.recordedAt);
    });
  return out;
}

class TargetHistoryTile extends StatelessWidget {
  const TargetHistoryTile({super.key, required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    if (targetChanges(habit).isEmpty) return const SizedBox.shrink();
    final settings = context.watch<SettingsController>();
    final today = AppClock.today();
    final summary = [
      context.l10n.history_minimum(habit.amountText(habit.requiredOn(today))),
      context.l10n.history_target(habit.amountText(habit.fullTargetOn(today))),
    ].join('  ·  ');
    void open() => showTargetHistorySheet(context, habit);

    final Widget tile;
    if (settings.isExpressStyle) {
      tile = ExpressTile(
        icon: LucideIcons.target,
        title: context.l10n.target_history,
        subtitle: summary,
        onTap: open,
      );
    } else if (settings.isMinimalStyle) {
      tile = MinimalList(
        children: [
          MinimalRow(
            label: context.l10n.target_history,
            caption: summary,
            onTap: open,
            last: true,
          ),
        ],
      );
    } else {
      tile = Card(
        child: ListTile(
          onTap: open,
          leading: Icon(LucideIcons.target,
              size: 22, color: context.colors.primary),
          title: Text(
            context.l10n.target_history,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.colors.onSurface,
            ),
          ),
          subtitle: Text(summary,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.tokens.muted,
              )),
          trailing: Icon(LucideIcons.chevronRightDir,
              size: 18, color: context.tokens.muted),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: tile,
    );
  }
}

Future<void> showTargetHistorySheet(BuildContext context, Habit habit) {
  final changes = targetChanges(habit);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SheetTitle(sheet.l10n.target_history),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: changes.length,
                itemBuilder: (row, i) {
                  final c = changes[i];
                  final amount = habit.amountText(c.amount);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.isMinimum
                                ? sheet.l10n.history_minimum(amount)
                                : sheet.l10n.history_target(amount),
                            style: sheetBodyStyle(sheet),
                          ),
                        ),
                        Text(
                          DateFormat.yMMMd(sheet.l10n.localeName)
                              .format(c.day),
                          style: sheetBodyStyle(sheet, size: 13),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
