import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/express/express_type.dart';
import 'package:khuta/core/minimal/minimal_type.dart';
import 'package:khuta/core/routing/back_handlers.dart';
import 'package:khuta/features/habits/data/category.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';
import 'package:khuta/features/todos/data/todo_tag.dart';
import 'package:khuta/features/todos/state/todo_tags_controller.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';
import 'package:khuta/features/todos/data/projects_view.dart';
import 'package:khuta/features/todos/widgets/folder_shape.dart';
import 'package:khuta/features/todos/widgets/project_tile.dart';
import 'package:khuta/features/todos/widgets/todo_tag_sheet.dart';

class TodoProjects extends StatefulWidget {
  const TodoProjects({super.key, required this.onOpen});

  final ValueChanged<String?> onOpen;

  @override
  State<TodoProjects> createState() => _TodoProjectsState();
}

class _TodoProjectsState extends State<TodoProjects>
    with SingleTickerProviderStateMixin {
  static const _spacing = 16.0;
  static const _folderRatio = 1.28;
  static const _labelHeight = 42.0;

  static double _textGrowth(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.2);

  late final AnimationController _wobble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  List<TodoTag> _order = const [];
  String? _dragging;
  bool _arranging = false;

  @override
  void initState() {
    super.initState();
    BackHandlers.add(_backOut);
  }

  @override
  void dispose() {
    BackHandlers.remove(_backOut);
    _wobble.dispose();
    super.dispose();
  }

  bool _backOut() {
    if (!_arranging || !BackHandlers.isVisible(context)) return false;
    _arrange(false);
    return true;
  }

  void _arrange(bool on) {
    if (!mounted || _arranging == on) return;
    setState(() => _arranging = on);
    if (on) {
      _wobble.repeat();
    } else {
      _wobble.stop();
      _wobble.value = 0;
    }
  }

  void _hover(String id, int target) {
    final from = _order.indexWhere((p) => p.id == id);
    if (from == -1 || from == target || target >= _order.length) return;
    setState(() {
      final moved = [..._order];
      moved.insert(target, moved.removeAt(from));
      _order = moved;
    });
  }

  Future<void> _settle() async {
    final ordered = [..._order];
    setState(() => _dragging = null);
    await context.read<TodoTagsController>().reorder(ordered);
  }

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<TodoTagsController>().projects;
    final todos = context.watch<TodosController>();
    final settings = context.watch<SettingsController>();
    final view = settings.projectsView;
    final style = settings.appStyle;
    final minimal = style == 1;
    final accent =
        minimal ? context.colors.onSurface : context.colors.primary;
    if (_dragging == null) _order = projects;
    final loose = todos.looseCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_arranging) ...[
          _ArrangeBar(
            accent: accent,
            onLabel: minimal ? context.colors.surface : context.colors.onPrimary,
            style: style,
            hint: view == ProjectsView.folders
                ? context.l10n.todo_project_arrange_hint
                : context.l10n.todo_project_arrange_hint_flat,
            onDone: () => _arrange(false),
          ),
          const SizedBox(height: 14),
        ],
        LayoutBuilder(
          builder: (context, box) {
            final columns = switch (view) {
              ProjectsView.list => 1,
              ProjectsView.cards => math.max(2, (box.maxWidth / 200).floor()),
              _ => math.max(2, (box.maxWidth / 178).floor()),
            };
            final spacing = view == ProjectsView.folders ? _spacing : 12.0;
            final cellWidth =
                (box.maxWidth - spacing * (columns - 1)) / columns;
            final cellHeight = switch (view) {
              ProjectsView.list =>
                ProjectTile.heightFor(context, card: false),
              ProjectsView.cards => ProjectTile.heightFor(context, card: true),
              _ => cellWidth / _folderRatio +
                  _labelHeight * _textGrowth(context) +
                  (_textGrowth(context) - 1) * 14,
            };
            final total = _order.length + (loose > 0 ? 1 : 0);
            final rows = (total / columns).ceil();

            Widget place(int index, Key key, Widget child) {
              final row = index ~/ columns;
              final column = index % columns;
              return AnimatedPositionedDirectional(
                key: key,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                start: column * (cellWidth + spacing),
                top: row * (cellHeight + spacing),
                width: cellWidth,
                height: cellHeight,
                child: child,
              );
            }

            final slots = <Widget>[];
            for (final (index, project) in _order.indexed) {
              slots.add(
                place(
                  index,
                  ValueKey(project.id),
                  _ProjectSlot(
                    project: project,
                    view: view,
                    progress: todos.projectProgress(project.id),
                    width: cellWidth,
                    height: cellHeight,
                    count: todos.projectCount(project.id),
                    arranging: _arranging,
                    accent: accent,
                    wobble: _wobble,
                    index: index,
                    dragging: _dragging == project.id,
                    onStart: () => setState(() => _dragging = project.id),
                    onEnd: _settle,
                    onHover: (id) => _hover(id, index),
                    onOpen: () => widget.onOpen(project.id),
                    onEdit: () => editTag(context, project),
                    onMenu: () => editOrDeleteTag(
                      context,
                      project,
                      onArrange: () => _arrange(true),
                    ),
                  ),
                ),
              );
            }
            if (loose > 0) {
              slots.add(
                place(
                  _order.length,
                  const ValueKey('loose'),
                  view == ProjectsView.folders
                      ? _ProjectCell(
                          label: context.l10n.todo_project_none,
                          color: context.tokens.muted,
                          icon: LucideIcons.inbox,
                          count: loose,
                          onTap: () => widget.onOpen(''),
                        )
                      : ProjectTile(
                          card: view == ProjectsView.cards,
                          label: context.l10n.todo_project_none,
                          color: context.tokens.muted,
                          icon: LucideIcons.inbox,
                          open: loose,
                          done: todos.projectProgress('').done,
                          total: todos.projectProgress('').total,
                          onTap: () => widget.onOpen(''),
                        ),
                ),
              );
            }
            return SizedBox(
              height: math.max(0, rows * cellHeight + (rows - 1) * spacing),
              child: Stack(children: slots),
            );
          },
        ),
        if (_order.isEmpty) ...[
          const SizedBox(height: 18),
          Text(
            context.l10n.todo_tag_empty_body,
            style: TextStyle(fontSize: 13.5, color: context.tokens.muted),
          ),
        ],
      ],
    );
  }
}

TextStyle folderNameStyle(BuildContext context, int style, Color color) =>
    switch (style) {
      2 => ExpressType.headline.at(14, weight: 700, color: color),
      1 => MinimalType.title(13.5, color: color, weight: 700),
      _ => TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    };

TextStyle folderCountStyle(BuildContext context, int style, Color color) =>
    switch (style) {
      2 => ExpressType.body.at(11.5, weight: 600, color: color),
      1 => MinimalType.body(11.5, color: color, weight: 600),
      _ => TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    };

class _ArrangeBar extends StatelessWidget {
  const _ArrangeBar({
    required this.accent,
    required this.onLabel,
    required this.style,
    required this.hint,
    required this.onDone,
  });

  final String hint;
  final Color accent;
  final Color onLabel;
  final int style;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(style == 2 ? 24 : 16),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.move, size: 16, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: onDone,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(style == 2 ? 16 : 11),
                ),
                child: Text(
                  context.l10n.done,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: onLabel,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectSlot extends StatelessWidget {
  const _ProjectSlot({
    required this.project,
    required this.view,
    required this.progress,
    required this.width,
    required this.height,
    required this.count,
    required this.arranging,
    required this.accent,
    required this.wobble,
    required this.index,
    required this.dragging,
    required this.onStart,
    required this.onEnd,
    required this.onHover,
    required this.onOpen,
    required this.onEdit,
    required this.onMenu,
  });

  final TodoTag project;
  final ProjectsView view;
  final ({int done, int total}) progress;
  final double width;
  final double height;
  final int count;
  final bool arranging;
  final Color accent;
  final Animation<double> wobble;
  final int index;
  final bool dragging;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final ValueChanged<String> onHover;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final Widget cell = view == ProjectsView.folders
        ? _ProjectCell(
            label: project.name,
            color: project.color,
            icon: CategoryIcons.resolve(project.icon),
            count: count,
            arranging: arranging,
            accent: accent,
            seed: project.id.codeUnits.fold(0, (sum, unit) => sum + unit),
            onTap: arranging ? null : onOpen,
            onLongPress: arranging ? null : onMenu,
            onMenu: arranging ? onEdit : onMenu,
          )
        : ProjectTile(
            card: view == ProjectsView.cards,
            label: project.name,
            color: project.color,
            icon: CategoryIcons.resolve(project.icon),
            open: count,
            done: progress.done,
            total: progress.total,
            arranging: arranging,
            accent: accent,
            onTap: arranging ? null : onOpen,
            onLongPress: arranging ? null : onMenu,
            onMenu: arranging ? onEdit : onMenu,
          );

    if (!arranging) return cell;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        if (details.data == project.id) return false;
        onHover(details.data);
        return true;
      },
      builder: (context, _, __) => LongPressDraggable<String>(
        data: project.id,
        delay: const Duration(milliseconds: 120),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: () {
          onStart();
        },
        onDragEnd: (_) => onEnd(),
        onDraggableCanceled: (_, __) => onEnd(),
        feedback: _DragShadow(width: width, height: height, child: cell),
        childWhenDragging: Opacity(opacity: 0.22, child: cell),
        child: AnimatedBuilder(
          animation: wobble,
          builder: (context, child) => Transform.rotate(
            angle: dragging
                ? 0
                : math.sin(
                        wobble.value * 2 * math.pi +
                            (index.isEven ? 0 : math.pi),
                      ) *
                      0.016,
            child: child,
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: dragging ? 0.22 : 1,
            child: cell,
          ),
        ),
      ),
    );
  }
}

class _DragShadow extends StatelessWidget {
  const _DragShadow({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(-width / 2, -height / 2),
      child: Transform.scale(
        scale: 1.06,
        child: SizedBox(
          width: width,
          height: height,
          child: Material(color: Colors.transparent, child: child),
        ),
      ),
    );
  }
}

class _ProjectCell extends StatefulWidget {
  const _ProjectCell({
    required this.label,
    required this.color,
    required this.icon,
    required this.count,
    this.arranging = false,
    this.accent,
    this.seed = 0,
    this.onTap,
    this.onLongPress,
    this.onMenu,
  });

  final String label;
  final Color color;
  final IconData icon;
  final int count;
  final bool arranging;
  final Color? accent;
  final int seed;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMenu;

  @override
  State<_ProjectCell> createState() => _ProjectCellState();
}

class _ProjectCellState extends State<_ProjectCell> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tap = widget.onTap;
    final style = context.watch<SettingsController>().appStyle;
    return Semantics(
      button: true,
      label: '${widget.label}, ${context.l10n.todo_tag_count(widget.count)}',
      excludeSemantics: true,
      child: MouseRegion(
        cursor:
            tap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap == null
              ? null
              : () {
                  tap();
                },
          onLongPress: widget.onLongPress,
          onSecondaryTap: widget.onLongPress ?? widget.onMenu,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 140),
            scale: _pressed
                ? 0.96
                : _hovered && tap != null
                ? 1.02
                : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FolderShape(
                    color: widget.color,
                    icon: widget.icon,
                    papers: widget.count,
                    lifted: _pressed || (_hovered && tap != null),
                    seed: widget.seed,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: folderNameStyle(
                          context,
                          style,
                          context.colors.onSurface,
                        ),
                      ),
                    ),
                    if (widget.onMenu != null)
                      Semantics(
                        button: true,
                        label: context.l10n.todo_project_edit,
                        child: GestureDetector(
                          onTap: widget.onMenu,
                          behavior: HitTestBehavior.opaque,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(5, 4, 6, 4),
                              child: Icon(
                                widget.arranging
                                    ? LucideIcons.pencil
                                    : LucideIcons.ellipsis,
                                size: 15,
                                color: widget.arranging
                                    ? widget.accent
                                    : context.tokens.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  context.l10n.todo_tag_count(widget.count),
                  style: folderCountStyle(context, style, context.tokens.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
