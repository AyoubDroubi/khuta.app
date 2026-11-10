import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/routing/app_navigator.dart';
import 'package:khuta/features/goals/data/goal.dart';
import 'package:khuta/features/goals/state/goals_controller.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/journeys/state/journeys_controller.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';

class GoalFormPage extends StatefulWidget {
  const GoalFormPage({super.key, this.goalId});

  final String? goalId;

  @override
  State<GoalFormPage> createState() => _GoalFormPageState();
}

class _GoalFormPageState extends State<GoalFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  String _targetDate = '';
  String? _parentGoalId;
  GoalState _state = GoalState.active;
  final Set<String> _selected = {};

  Goal? get _existing => widget.goalId == null
      ? null
      : context.read<GoalsController>().byId(widget.goalId!);

  @override
  void initState() {
    super.initState();
    final existing = widget.goalId == null
        ? null
        : context.read<GoalsController>().byId(widget.goalId!);
    _title = TextEditingController(text: existing?.title ?? '');
    _description = TextEditingController(text: existing?.description ?? '');
    _targetDate = existing?.targetDate ?? '';
    _parentGoalId = existing?.parentGoalId;
    _state = existing?.state ?? GoalState.active;
    for (final source in existing?.sources ?? const <GoalSourceLink>[]) {
      _selected.add(_key(source.type, source.sourceId));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalsController>();
    final habits = context.watch<HabitsController>().habits;
    final todos = context.watch<TodosController>().all;
    final journeys = context.watch<JourneysController>().all;
    final existing = _existing;

    final parentOptions = goals.active.where((candidate) {
      if (candidate.id == existing?.id) return false;
      if (existing == null) return true;
      return goals.canUseParent(existing.id, candidate.id);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          existing == null ? context.l10n.goal_new : context.l10n.goal_edit,
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(context.l10n.save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            TextFormField(
              controller: _title,
              decoration: InputDecoration(labelText: context.l10n.goal_title),
              maxLength: 160,
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.l10n.goal_title_required
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration:
                  InputDecoration(labelText: context.l10n.goal_description),
              maxLength: 4000,
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _parentGoalId,
              decoration: InputDecoration(labelText: context.l10n.goal_parent),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(context.l10n.goal_no_parent),
                ),
                for (final goal in parentOptions)
                  DropdownMenuItem<String?>(
                    value: goal.id,
                    child: Text(goal.title),
                  ),
              ],
              onChanged: (value) => setState(() => _parentGoalId = value),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.goal_target_date),
              subtitle: Text(
                _targetDate.isEmpty
                    ? context.l10n.goal_no_target_date
                    : _targetDate,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_targetDate.isNotEmpty)
                    IconButton(
                      onPressed: () => setState(() => _targetDate = ''),
                      icon: const Icon(Icons.close),
                    ),
                  IconButton(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                ],
              ),
            ),
            if (existing != null) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<GoalState>(
                initialValue: _state,
                decoration: InputDecoration(labelText: context.l10n.goal_state),
                items: [
                  DropdownMenuItem(
                    value: GoalState.active,
                    child: Text(context.l10n.goal_active),
                  ),
                  DropdownMenuItem(
                    value: GoalState.completed,
                    child: Text(context.l10n.goal_completed),
                  ),
                  DropdownMenuItem(
                    value: GoalState.archived,
                    child: Text(context.l10n.goal_archived),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _state = value ?? GoalState.active),
              ),
            ],
            const SizedBox(height: 22),
            Text(
              context.l10n.goal_link_sources,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            _section(
              context,
              context.l10n.goal_source_habits,
              GoalSourceType.habit,
              <(String, String)>[
                for (final item in habits) (item.id, item.name),
              ],
            ),
            _section(
              context,
              context.l10n.todos,
              GoalSourceType.todo,
              <(String, String)>[
                for (final item in todos) (item.id, item.text),
              ],
            ),
            _section(
              context,
              context.l10n.journeys,
              GoalSourceType.journey,
              <(String, String)>[
                for (final item in journeys) (item.id, item.title),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    GoalSourceType type,
    List<(String, String)> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      title: Text(title),
      children: [
        for (final item in items)
          CheckboxListTile(
            value: _selected.contains(_key(type, item.$1)),
            title: Text(item.$2),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (checked) {
              setState(() {
                final key = _key(type, item.$1);
                if (checked == true) {
                  _selected.add(key);
                } else {
                  _selected.remove(key);
                }
              });
            },
          ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_targetDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _targetDate =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final goals = context.read<GoalsController>();
    final existing = _existing;
    final now = DateTime.now().toUtc();
    final prior = {
      for (final source in existing?.sources ?? const <GoalSourceLink>[])
        _key(source.type, source.sourceId): source,
    };

    final sources = <GoalSourceLink>[];
    for (final selected in _selected) {
      final separator = selected.indexOf(':');
      final type =
          GoalSourceType.values[int.parse(selected.substring(0, separator))];
      final id = selected.substring(separator + 1);
      final previous = prior[selected];
      sources.add(
        GoalSourceLink(
          type: type,
          sourceId: id,
          linkedAt: previous?.linkedAt ?? now,
          sourceTitle: previous?.sourceTitle ?? '',
          available: previous?.available ?? true,
        ),
      );
    }

    if (existing == null) {
      await goals.create(
        title: _title.text,
        description: _description.text,
        targetDate: _targetDate,
        parentGoalId: _parentGoalId,
        sources: sources,
      );
    } else {
      await goals.save(
        existing.copyWith(
          title: _title.text.trim(),
          description: _description.text.trim(),
          targetDate: _targetDate,
          clearTargetDate: _targetDate.isEmpty,
          parentGoalId: _parentGoalId,
          clearParentGoal: _parentGoalId == null,
          state: _state,
          sources: sources,
        ),
      );
    }
    if (mounted) AppNavigator.pop();
  }

  static String _key(GoalSourceType type, String id) => '${type.index}:$id';
}
