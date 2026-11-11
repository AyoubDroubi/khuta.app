import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/express/express_surface.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';

/// A project as a flat row (list view) or a flat card (cards view): colour
/// chip with the project icon, name, how many are open and a progress bar.
class ProjectTile extends StatefulWidget {
  const ProjectTile({
    super.key,
    required this.card,
    required this.label,
    required this.color,
    required this.icon,
    required this.open,
    required this.done,
    required this.total,
    this.arranging = false,
    this.accent,
    this.onTap,
    this.onLongPress,
    this.onMenu,
  });

  /// True for the two-column card, false for the full-width row.
  final bool card;
  final String label;
  final Color color;
  final IconData icon;
  final int open;
  final int done;
  final int total;
  final bool arranging;
  final Color? accent;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMenu;

  /// Height of a tile, grown with the text size so large text still fits.
  static double heightFor(BuildContext context, {required bool card}) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.2);
    return card ? 150 + (scale - 1) * 78 : 92 + (scale - 1) * 46;
  }

  @override
  State<ProjectTile> createState() => _ProjectTileState();
}

class _ProjectTileState extends State<ProjectTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final style = context.watch<SettingsController>().appStyle;
    final scheme = context.colors;
    final muted = context.tokens.muted;
    final radius = switch (style) {
      2 => 26.0,
      1 => 14.0,
      _ => 20.0,
    };
    final surface = switch (style) {
      2 => expressSurface(context),
      1 => scheme.surface,
      _ => scheme.surfaceContainerHigh,
    };
    final border = style == 1
        ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6))
        : null;
    final fraction = widget.total == 0 ? 0.0 : widget.done / widget.total;
    final chipSize = widget.card ? 42.0 : 52.0;

    final chip = Container(
      width: chipSize,
      height: chipSize,
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(chipSize * 0.32),
      ),
      child: Icon(widget.icon, size: chipSize * 0.46, color: widget.color),
    );

    final menu = widget.onMenu == null
        ? const SizedBox.shrink()
        : Semantics(
            button: true,
            label: context.l10n.todo_project_edit,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onMenu,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  widget.arranging ? LucideIcons.pencil : LucideIcons.ellipsis,
                  size: 18,
                  color: widget.arranging ? widget.accent : muted,
                ),
              ),
            ),
          );

    final name = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: widget.card ? 15 : 16.5,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
    );
    final count = Text(
      widget.total == 0
          ? context.l10n.todo_tag_count(widget.open)
          : '${context.l10n.todo_tag_count(widget.open)}  ·  '
              '${context.l10n.todo_project_done_of(widget.done, widget.total)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
    );
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 6,
        color: widget.color,
        backgroundColor: widget.color.withValues(alpha: 0.14),
      ),
    );

    final body = widget.card
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [chip, const Spacer(), menu]),
              const Spacer(),
              name,
              const SizedBox(height: 2),
              count,
              const SizedBox(height: 10),
              bar,
            ],
          )
        : Row(
            children: [
              chip,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    name,
                    const SizedBox(height: 2),
                    count,
                    const SizedBox(height: 9),
                    bar,
                  ],
                ),
              ),
              menu,
            ],
          );

    return Semantics(
      button: true,
      label: '${widget.label}, ${context.l10n.todo_tag_count(widget.open)}'
          '${widget.total == 0 ? '' : ', ${context.l10n.todo_project_done_of(widget.done, widget.total)}'}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onSecondaryTap: widget.onLongPress ?? widget.onMenu,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _pressed ? 0.98 : 1,
          child: Container(
            padding: EdgeInsets.all(widget.card ? 14 : 12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(radius),
              border: border,
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}
