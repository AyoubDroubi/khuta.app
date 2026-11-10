import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/features/recovery/data/recovery_config.dart';

/// Per-habit Recovery switch and its finite reminder settings.
class RecoveryEditor extends StatelessWidget {
  const RecoveryEditor({super.key, required this.config, required this.onChanged});

  final RecoveryConfig config;
  final ValueChanged<RecoveryConfig> onChanged;

  Widget _stepper(
    BuildContext context,
    String label,
    int value,
    int min,
    int max,
    int step,
    String Function(int) text,
    ValueChanged<int> on,
  ) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          tooltip: context.l10n.a11y_decrease,
          onPressed: value > min ? () => on((value - step).clamp(min, max)) : null,
          icon: const Icon(LucideIcons.minus, size: 18),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44),
          child: Text(text(value), textAlign: TextAlign.center),
        ),
        IconButton(
          tooltip: context.l10n.a11y_increase,
          onPressed: value < max ? () => on((value + step).clamp(min, max)) : null,
          icon: const Icon(LucideIcons.plus, size: 18),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String hours(int n) => l10n.hours_short(n);
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            value: config.enabled,
            onChanged: (v) => onChanged(config.copyWith(
              enabled: v,
              enabledAt: v && !config.enabled ? DateTime.now() : null,
            )),
            secondary: Icon(LucideIcons.lifeBuoy, color: context.colors.primary),
            title: Text(l10n.recovery_enable),
            subtitle: Text(l10n.recovery_enable_sub),
          ),
          if (config.enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
              child: Column(
                children: [
                  _stepper(context, l10n.recovery_count, config.count, 0,
                      RecoveryConfig.maxCount, 1, (v) => '$v',
                      (v) => onChanged(config.copyWith(count: v))),
                  if (config.count > 0) ...[
                    _stepper(context, l10n.recovery_first_delay,
                        config.firstDelayHours, 0, RecoveryConfig.maxHours, 1,
                        hours, (v) => onChanged(config.copyWith(firstDelayHours: v))),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: config.fixedTime,
                      onChanged: (v) => onChanged(config.copyWith(fixedTime: v)),
                      title: Text(l10n.recovery_at_time),
                    ),
                    if (config.fixedTime)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.recovery_time),
                        trailing: Text(
                          '${config.hour.toString().padLeft(2, '0')}:'
                          '${config.minute.toString().padLeft(2, '0')}',
                        ),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime:
                                TimeOfDay(hour: config.hour, minute: config.minute),
                          );
                          if (picked != null) {
                            onChanged(config.copyWith(
                                hour: picked.hour, minute: picked.minute));
                          }
                        },
                      )
                    else
                      _stepper(context, l10n.recovery_repeat_every,
                          config.repeatHours, 1, RecoveryConfig.maxHours, 1,
                          hours, (v) => onChanged(config.copyWith(repeatHours: v))),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
