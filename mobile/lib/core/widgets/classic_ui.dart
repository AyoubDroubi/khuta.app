import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:khuta/app/theme/app_tokens.dart';

abstract final class ClassicLayout {
  static const double screenPadding = 16;
  static const double sectionGap = 16;
  static const double smallGap = 8;
  static const double controlRadius = 16;
  static const double compactCardRadius = 18;
  static const double cardRadius = 24;
  static const double bottomNavigationClearance = 148;
  static const double navigationBottomOffset = 12;
}

class ClassicChevronButton extends StatelessWidget {
  const ClassicChevronButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(
        icon,
        size: 20,
        color: enabled
            ? context.colors.onSurface
            : context.tokens.muted.withValues(alpha: 0.38),
      ),
    );
  }
}

class ClassicDateNavigator extends StatelessWidget {
  const ClassicDateNavigator({
    super.key,
    required this.title,
    required this.onPrevious,
    this.subtitle,
    this.onNext,
    this.previousTooltip,
    this.nextTooltip,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final String? previousTooltip;
  final String? nextTooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClassicChevronButton(
          icon: LucideIcons.chevronLeftDir,
          tooltip: previousTooltip ??
              MaterialLocalizations.of(context).previousPageTooltip,
          onPressed: onPrevious,
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: context.colors.onSurface,
                ),
              ),
              if (subtitle case final value?) ...[
                const SizedBox(height: 4),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.tokens.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        ClassicChevronButton(
          icon: LucideIcons.chevronRightDir,
          tooltip:
              nextTooltip ?? MaterialLocalizations.of(context).nextPageTooltip,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class AutoDirectionText extends StatelessWidget {
  const AutoDirectionText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final direction = Bidi.detectRtlDirectionality(text)
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign ?? TextAlign.start,
      textDirection: direction,
    );
  }
}
