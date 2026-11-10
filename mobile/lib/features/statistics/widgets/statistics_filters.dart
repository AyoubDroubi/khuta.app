import 'package:flutter/material.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/widgets/classic_ui.dart';
import 'package:khuta/features/habits/data/habit.dart';

class HabitFilter extends StatelessWidget {
  const HabitFilter({
    super.key,
    required this.habits,
    required this.selected,
    required this.onSelected,
  });

  final List<Habit> habits;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: context.l10n.all,
            color: context.colors.primary,
            active: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final habit in habits)
            _FilterChip(
              label: habit.name,
              color: habit.color,
              active: selected == habit.id,
              onTap: () => onSelected(habit.id),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Semantics(
        button: true,
        selected: active,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? color
                  : context.colors.surfaceContainerHighest.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
              border: active
                  ? null
                  : Border.all(
                      color: context.colors.outlineVariant.withValues(alpha: 0.35),
                    ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active
                    ? (color.computeLuminance() > 0.55
                        ? Colors.black
                        : Colors.white)
                    : context.tokens.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class YearNavigator extends StatelessWidget {
  const YearNavigator({
    super.key,
    required this.year,
    required this.canGoForward,
    required this.onChanged,
  });

  final int year;
  final bool canGoForward;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClassicDateNavigator(
      title: '$year',
      onPrevious: () => onChanged(-1),
      onNext: canGoForward ? () => onChanged(1) : null,
    );
  }
}
