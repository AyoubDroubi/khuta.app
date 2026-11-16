import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/routing/app_navigator.dart';
import 'package:khuta/core/utils/responsive.dart';
import 'package:khuta/features/capture/data/proposed_item.dart';
import 'package:khuta/features/capture/data/rule_parser.dart';
import 'package:khuta/features/capture/state/capture_draft.dart';
import 'package:khuta/features/journal/state/journal_controller.dart';
import 'package:khuta/features/todos/state/todo_tags_controller.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';
import 'package:khuta/features/todos/widgets/todo_labels.dart';

/// Quick capture: type a sentence, see what was found, save it with one tap.
/// Nothing is written until the person presses save, and the typed text lives
/// only in this sheet's state.
Future<void> showQuickCapture(BuildContext context) async {
  if (isWideLayout(context)) {
    AppNavigator.clearPane();
    await AppNavigator.push<void>(const _CapturePage(), fade: true);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CaptureSheet(),
  );
}

class _CapturePage extends StatelessWidget {
  const _CapturePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(LucideIcons.chevronLeftDir),
          onPressed: () => AppNavigator.pop(),
        ),
        title: Text(context.l10n.capture_title),
      ),
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: phoneWidth),
            child: _CaptureSheet(onClose: AppNavigator.pop),
          ),
        ),
      ),
    );
  }
}

class _CaptureSheet extends StatefulWidget {
  const _CaptureSheet({this.onClose});

  final VoidCallback? onClose;

  @override
  State<_CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends State<_CaptureSheet> {
  final _text = TextEditingController();
  CaptureDraft? _draft;
  int _found = 0;

  @override
  void dispose() {
    _text.dispose();
    _draft?.dispose();
    super.dispose();
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _find() async {
    final tags = context.read<TodoTagsController>();
    final items = await const RuleParser().parse(
      _text.text,
      now: AppClock.wallNow(),
      today: AppClock.today(),
      projects: tags.projects,
      labels: tags.labels,
    );
    if (!mounted) return;
    final old = _draft;
    setState(() {
      _draft = CaptureDraft(items);
      _found = items.length;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    final todos = context.read<TodosController>();
    final journal = context.read<JournalController>();
    final result = await draft.save(
      todos: todos,
      journal: journal,
      today: AppClock.today(),
    );
    if (!mounted || result == null) return;
    if (result.failed.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.capture_save_failed)),
      );
      return;
    }
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final muted = context.tokens.muted;
    final draft = _draft;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: muted.withValues(alpha: 0.16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.sparkles, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.capture_title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('capture_input'),
              controller: _text,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: maxCaptureInput,
              onChanged: (_) => setState(() {}),
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              style: TextStyle(
                fontSize: 16,
                height: 1.35,
                color: scheme.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: context.l10n.capture_hint,
                hintStyle: TextStyle(color: muted, fontSize: 16),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonal(
                key: const Key('capture_find'),
                onPressed: _text.text.trim().isEmpty ? null : _find,
                child: Text(context.l10n.capture_find),
              ),
            ),
            if (draft != null)
              ListenableBuilder(
                listenable: draft,
                builder: (context, _) => _Preview(
                  draft: draft,
                  found: _found,
                  onSave: _save,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.draft,
    required this.found,
    required this.onSave,
  });

  final CaptureDraft draft;
  final int found;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final rows = draft.rows;
    final checked = rows.where((r) => r.checked).length;
    final canSave = !draft.saveBlocked && !draft.saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (found == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              context.l10n.capture_nothing,
              key: const Key('capture_nothing'),
              style: TextStyle(color: context.tokens.muted),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.4,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    _CaptureRow(
                      key: ValueKey('row_state_${rows[i].id}'),
                      index: i,
                      draft: draft,
                      item: rows[i].item,
                      checked: rows[i].checked,
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            key: const Key('capture_save'),
            onPressed: canSave ? onSave : null,
            child: Text(context.l10n.capture_save_count(checked)),
          ),
        ),
      ],
    );
  }
}

class _CaptureRow extends StatefulWidget {
  const _CaptureRow({
    super.key,
    required this.index,
    required this.draft,
    required this.item,
    required this.checked,
  });

  final int index;
  final CaptureDraft draft;
  final ProposedItem item;
  final bool checked;

  @override
  State<_CaptureRow> createState() => _CaptureRowState();
}

class _CaptureRowState extends State<_CaptureRow> {
  late final _title = TextEditingController(text: widget.item.title);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  ProposedItem get _current => widget.draft.rows[widget.index].item;

  Future<void> _pickDay() async {
    final today = AppClock.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _current.day ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 5),
    );
    if (picked != null && mounted) widget.draft.setDay(widget.index, picked);
  }

  Future<void> _pickTime() async {
    final minutes = _current.minutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: minutes == null
          ? TimeOfDay(hour: AppClock.now().hour, minute: 0)
          : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null || !mounted) return;
    widget.draft.setMinutes(widget.index, picked.hour * 60 + picked.minute);
    if (_current.day == null) {
      widget.draft.setDay(widget.index, AppClock.today());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final muted = context.tokens.muted;
    final item = widget.item;
    final draft = widget.draft;
    final i = widget.index;
    final tags = context.watch<TodoTagsController>();
    final project = tags.byId(item.project);

    return Container(
      key: ValueKey('capture_row_$i'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 4, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: muted.withValues(alpha: 0.06),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            key: ValueKey('capture_check_$i'),
            value: widget.checked,
            onChanged: (_) => draft.toggle(i),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _title,
                  minLines: 1,
                  maxLines: 3,
                  onChanged: (value) => draft.retitle(i, value),
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.3,
                    color: scheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (item.kind == ProposedKind.note)
                      _Pill(
                        icon: LucideIcons.stickyNote,
                        label: context.l10n.capture_note,
                        color: scheme.primary,
                      ),
                    _Pill(
                      icon: LucideIcons.calendar,
                      label: item.day == null
                          ? context.l10n.capture_no_date
                          : todoDateLabel(context, item.day!),
                      color: item.day == null ? muted : scheme.primary,
                      onTap: _pickDay,
                      onRemove: item.day == null
                          ? null
                          : () {
                              draft.setDay(i, null);
                              draft.setMinutes(i, null);
                            },
                    ),
                    if (item.minutes != null)
                      _Pill(
                        icon: LucideIcons.clock,
                        label: TimeOfDay(
                          hour: item.minutes! ~/ 60,
                          minute: item.minutes! % 60,
                        ).format(context),
                        color: scheme.primary,
                        onTap: _pickTime,
                        onRemove: () => draft.setMinutes(i, null),
                      )
                    else
                      _Pill(
                        icon: LucideIcons.clock,
                        label: item.needsTime
                            ? context.l10n.capture_needs_time
                            : context.l10n.todo_time,
                        color: item.needsTime ? scheme.error : muted,
                        onTap: _pickTime,
                      ),
                    if (item.timePassed)
                      _Pill(
                        icon: LucideIcons.clockAlert,
                        label: context.l10n.capture_time_passed,
                        color: scheme.error,
                      ),
                    if (item.askedToRemind)
                      _Pill(
                        icon: LucideIcons.bellOff,
                        label: context.l10n.capture_remove_reminder,
                        color: muted,
                        onTap: () => draft.unmarkRemind(i),
                      ),
                    if (project != null)
                      _Pill(
                        icon: LucideIcons.folder,
                        label: project.name,
                        color: project.color,
                        onRemove: () => draft.clearProject(i),
                      ),
                    for (final tag in tags.resolve(item.tags))
                      _Pill(
                        icon: LucideIcons.tag,
                        label: tag.name,
                        color: tag.color,
                        onRemove: () => draft.removeTag(i, tag.id),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('capture_remove_$i'),
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            icon: Icon(LucideIcons.x, size: 18, color: muted),
            onPressed: () => draft.remove(i),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.onRemove,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12.5, color: color)),
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: Icon(LucideIcons.x, size: 13, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
