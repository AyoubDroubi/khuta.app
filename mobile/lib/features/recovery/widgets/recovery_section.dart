import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/routing/app_navigator.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/habits/pages/habit_details_page.dart';
import 'package:khuta/features/recovery/data/recovery_plan.dart';
import 'package:khuta/features/recovery/widgets/recovery_threshold_dialog.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';

/// Today's dismissible Recovery list. Dismissing only hides it for this
/// presentation; settings, completions and streaks are never touched.
class RecoverySection extends StatefulWidget {
  const RecoverySection({super.key, required this.habits});

  final List<Habit> habits;

  @override
  State<RecoverySection> createState() => _RecoverySectionState();
}

class _RecoverySectionState extends State<RecoverySection> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final threshold = context.select<SettingsController, int>(
      (s) => s.recoveryThresholdHours,
    );
    final due = RecoveryPlan.eligible(widget.habits, AppClock.now(), threshold);
    if (due.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.lifeBuoy,
                      size: 20, color: context.colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.recovery_title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.colors.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.recovery_dismiss,
                    onPressed: () => setState(() => _dismissed = true),
                    icon: const Icon(LucideIcons.x, size: 18),
                  ),
                ],
              ),
              Text(
                context.l10n.recovery_hint,
                style: TextStyle(fontSize: 13, color: context.tokens.muted),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => showRecoveryThresholdDialog(context),
                  child: Text(context.l10n.recovery_adjust),
                ),
              ),
              const SizedBox(height: 4),
              for (final habit in due)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => AppNavigator.push(
                    HabitDetailsPage(habitId: habit.id),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: habit.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            habit.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.colors.onSurface,
                            ),
                          ),
                        ),
                        Icon(LucideIcons.chevronRightDir,
                            size: 16, color: context.tokens.muted),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
