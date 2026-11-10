import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/core/extensions/inset_extensions.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/routing/app_navigator.dart';
import 'package:khuta/core/utils/cover_storage.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/journeys/data/journey.dart';
import 'package:khuta/features/journeys/state/journeys_controller.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';
import 'package:uuid/uuid.dart';

class JourneyFormPage extends StatefulWidget {
  const JourneyFormPage({super.key, this.journey});

  final Journey? journey;

  @override
  State<JourneyFormPage> createState() => _JourneyFormPageState();
}

class _JourneyFormPageState extends State<JourneyFormPage> {
  static const _uuid = Uuid();

  late final TextEditingController _title =
      TextEditingController(text: widget.journey?.title ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.journey?.description ?? '');
  late final TextEditingController _focus = TextEditingController(
    text: widget.journey?.focusTargetMinutes?.toString() ?? '',
  );
  late String _coverPath = widget.journey?.coverPath ?? '';
  late JourneyStatus _status =
      widget.journey?.status ?? JourneyStatus.active;
  late DateTime? _startDate =
      _parseDate(widget.journey?.startDate ?? '') ?? AppClock.today();
  late DateTime? _targetDate =
      _parseDate(widget.journey?.targetDate ?? '');
  late final Set<String> _habitIds = {...?widget.journey?.habitIds};
  late final List<_MilestoneDraft> _milestones = [
    for (final item in widget.journey?.milestones ?? const <JourneyMilestone>[])
      _MilestoneDraft(
        id: item.id,
        title: TextEditingController(text: item.title),
        completed: item.completed,
        completedAt: item.completedAt,
      ),
  ];

  bool get _canSave => _title.text.trim().isNotEmpty;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _focus.dispose();
    for (final item in _milestones) {
      item.title.dispose();
    }
    super.dispose();
  }

  static DateTime? _parseDate(String value) {
    if (value.isEmpty) return null;
    try {
      return parseDayKey(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickCover() async {
    final path = await CoverStorage.store(folder: 'journeys');
    if (path != null && mounted) setState(() => _coverPath = path);
  }

  Future<DateTime?> _pickDate(DateTime? current) => showDatePicker(
        context: context,
        initialDate: current ?? AppClock.today(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
      );

  String _statusLabel(BuildContext context, JourneyStatus status) =>
      switch (status) {
        JourneyStatus.planned => context.l10n.journey_planned,
        JourneyStatus.active => context.l10n.journey_active,
        JourneyStatus.completed => context.l10n.journey_completed,
        JourneyStatus.archived => context.l10n.journey_archived,
      };

  Future<void> _save() async {
    final controller = context.read<JourneysController>();
    final focusText = _focus.text.trim();
    final focusTarget = int.tryParse(focusText);

    if (_startDate != null &&
        _targetDate != null &&
        _targetDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.journey_invalid_dates)),
      );
      return;
    }

    if (focusText.isNotEmpty &&
        (focusTarget == null || focusTarget < 0 || focusTarget > 525600)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.journey_invalid_focus_target)),
      );
      return;
    }
    final milestones = [
      for (var i = 0; i < _milestones.length; i++)
        if (_milestones[i].title.text.trim().isNotEmpty)
          JourneyMilestone(
            id: _milestones[i].id,
            title: _milestones[i].title.text.trim(),
            completed: _milestones[i].completed,
            order: i,
            completedAt: _milestones[i].completedAt,
          ),
    ];

    final current = widget.journey;
    if (current == null) {
      await controller.create(
        title: _title.text,
        description: _description.text,
        coverPath: _coverPath,
        startDate: _startDate?.dayKey ?? '',
        targetDate: _targetDate?.dayKey ?? '',
        status: _status,
        focusTargetMinutes: focusTarget,
        milestones: milestones,
        habitIds: _habitIds.toList(),
      );
    } else {
      await controller.save(
        current.copyWith(
          title: _title.text.trim(),
          description: _description.text.trim(),
          coverPath: _coverPath,
          startDate: _startDate?.dayKey ?? '',
          targetDate: _targetDate?.dayKey ?? '',
          status: _status,
          focusTargetMinutes: focusTarget,
          clearFocusTarget: focusTarget == null,
          milestones: milestones,
          habitIds: _habitIds.toList(),
        ),
      );
    }

    AppNavigator.pop();
  }

  void _addMilestone() {
    setState(() {
      _milestones.add(
        _MilestoneDraft(
          id: _uuid.v4(),
          title: TextEditingController(),
        ),
      );
    });
  }

  void _removeMilestone(int index) {
    setState(() {
      final removed = _milestones.removeAt(index);
      removed.title.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final habits = context.watch<HabitsController>().habits;
    final minimal = settings.isMinimalStyle;
    final title = widget.journey == null
        ? context.l10n.journey_new
        : context.l10n.journey_edit;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: minimal ? 52 : null,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(LucideIcons.arrowLeftDir),
          onPressed: AppNavigator.pop,
        ),
        title: minimal ? null : Text(title),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: Text(context.l10n.save),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: context.pagePadding(
          minimal ? 20 : 16,
          6,
          minimal ? 20 : 16,
          40,
        ),
        children: [
          if (minimal)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: context.colors.onSurface,
                ),
              ),
            ),
          GestureDetector(
            onTap: _pickCover,
            child: Container(
              height: 150,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(22),
              ),
              child: _coverPath.isNotEmpty && File(_coverPath).existsSync()
                  ? Image.file(File(_coverPath), fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.imagePlus,
                          color: context.tokens.muted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.add_image,
                          style: TextStyle(color: context.tokens.muted),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _title,
            autofocus: widget.journey == null,
            maxLength: 160,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.l10n.journey_title,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 5,
            maxLength: 4000,
            decoration: InputDecoration(
              labelText: context.l10n.journey_description,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<JourneyStatus>(
            initialValue: _status,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: [
              for (final status in JourneyStatus.values)
                DropdownMenuItem(
                  value: status,
                  child: Text(_statusLabel(context, status)),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _status = value);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: context.l10n.journey_start_date,
                  value: _startDate,
                  onTap: () async {
                    final value = await _pickDate(_startDate);
                    if (value != null && mounted) {
                      setState(() => _startDate = value);
                    }
                  },
                  onClear: () => setState(() => _startDate = null),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: context.l10n.journey_target_date,
                  value: _targetDate,
                  onTap: () async {
                    final value = await _pickDate(_targetDate);
                    if (value != null && mounted) {
                      setState(() => _targetDate = value);
                    }
                  },
                  onClear: () => setState(() => _targetDate = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _focus,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.l10n.journey_focus_target,
              suffixText: context.l10n.unit_min_short,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(context.l10n.journey_milestones),
          const SizedBox(height: 8),
          for (var i = 0; i < _milestones.length; i++) ...[
            Row(
              children: [
                Checkbox(
                  value: _milestones[i].completed,
                  onChanged: (value) => setState(() {
                    _milestones[i].completed = value == true;
                    _milestones[i].completedAt = value == true
                        ? (_milestones[i].completedAt ?? DateTime.now().toUtc())
                        : null;
                  }),
                ),
                Expanded(
                  child: TextField(
                    controller: _milestones[i].title,
                    maxLength: 240,
                    decoration: InputDecoration(
                      hintText: context.l10n.journey_add_milestone,
                      counterText: '',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => _removeMilestone(i),
                  icon: const Icon(LucideIcons.x, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: _addMilestone,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: Text(context.l10n.journey_add_milestone),
          ),
          const SizedBox(height: 24),
          _SectionTitle(context.l10n.journey_linked_habits),
          const SizedBox(height: 8),
          if (habits.isEmpty)
            Text(
              context.l10n.no_habits_yet,
              style: TextStyle(color: context.tokens.muted),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  for (final habit in habits)
                    CheckboxListTile(
                      value: _habitIds.contains(habit.id),
                      secondary: Text(
                        habit.icon,
                        style: const TextStyle(fontSize: 20),
                      ),
                      title: Text(habit.name),
                      controlAffinity: ListTileControlAffinity.trailing,
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _habitIds.add(habit.id);
                        } else {
                          _habitIds.remove(habit.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _canSave ? _save : null,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(context.l10n.save),
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneDraft {
  _MilestoneDraft({
    required this.id,
    required this.title,
    this.completed = false,
    this.completedAt,
  });

  final String id;
  final TextEditingController title;
  bool completed;
  DateTime? completedAt;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: context.colors.onSurface,
        ),
      );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: value == null
                ? const Icon(LucideIcons.calendarDays, size: 18)
                : IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: onClear,
                    icon: const Icon(LucideIcons.x, size: 17),
                  ),
          ),
          child: Text(value?.dayKey ?? '—'),
        ),
      );
}
