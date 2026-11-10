import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/recovery/data/recovery_plan.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';

String recoveryThresholdLabel(BuildContext context, int hours) =>
    context.l10n.duration_days_hours(hours ~/ 24, hours % 24);

/// Edits the shared inactivity threshold (days and hours).
Future<void> showRecoveryThresholdDialog(BuildContext context) async {
  final settings = context.read<SettingsController>();
  final habits = context.read<HabitsController>();
  var days = settings.recoveryThresholdHours ~/ 24;
  var hours = settings.recoveryThresholdHours % 24;
  const maxDays = RecoveryPlan.maxThresholdHours ~/ 24;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setState) {
        Widget stepper(String label, int value, int max, ValueChanged<int> on) {
          return Row(
            children: [
              Expanded(child: Text(label)),
              IconButton(
                tooltip: dialog.l10n.a11y_decrease,
                onPressed: value > 0 ? () => setState(() => on(value - 1)) : null,
                icon: const Icon(LucideIcons.minus),
              ),
              SizedBox(
                width: 36,
                child: Text('$value', textAlign: TextAlign.center),
              ),
              IconButton(
                tooltip: dialog.l10n.a11y_increase,
                onPressed:
                    value < max ? () => setState(() => on(value + 1)) : null,
                icon: const Icon(LucideIcons.plus),
              ),
            ],
          );
        }

        return AlertDialog(
          title: Text(dialog.l10n.recovery_threshold),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              stepper(dialog.l10n.recovery_days, days, maxDays,
                  (v) => days = v),
              stepper(dialog.l10n.recovery_hours, hours, 23, (v) => hours = v),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(dialog.l10n.cancel),
            ),
            TextButton(
              onPressed:
                  days * 24 + hours >= 1 ? () => Navigator.pop(dialog, true) : null,
              child: Text(dialog.l10n.save),
            ),
          ],
        );
      },
    ),
  );
  if (saved != true) return;
  await settings.setRecoveryThresholdHours(days * 24 + hours);
  await habits.rescheduleRecovery();
}
