import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/extensions/inset_extensions.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/minimal/minimal_kit.dart';
import 'package:khuta/core/routing/app_navigator.dart';
import 'package:khuta/core/utils/cover_storage.dart';
import 'package:khuta/core/widgets/photo_deck.dart';
import 'package:khuta/core/widgets/photo_viewer.dart';
import 'package:khuta/features/journal/data/journal_entry.dart';
import 'package:khuta/features/journal/state/journal_controller.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';

class JournalEntryEditorPage extends StatefulWidget {
  const JournalEntryEditorPage({
    super.key,
    required this.date,
    required this.kind,
    this.entry,
  });

  final String date;
  final JournalEntryKind kind;
  final JournalEntry? entry;

  @override
  State<JournalEntryEditorPage> createState() => _JournalEntryEditorPageState();
}

class _JournalEntryEditorPageState extends State<JournalEntryEditorPage> {
  late final TextEditingController _text =
      TextEditingController(text: widget.entry?.text ?? '');
  late final List<String> _photos = [...?widget.entry?.photos];
  late TimeOfDay? _time = widget.entry == null
      ? TimeOfDay.now()
      : _timeFromMinutes(widget.entry?.minutes);

  bool get _canSave => _text.text.trim().isNotEmpty || _photos.isNotEmpty;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  static TimeOfDay? _timeFromMinutes(int? value) => value == null
      ? null
      : TimeOfDay(hour: value ~/ 60, minute: value % 60);

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (value != null && mounted) setState(() => _time = value);
  }

  Future<void> _addPhoto({bool camera = false}) async {
    if (_photos.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.journal_photo_limit)),
      );
      return;
    }

    final path = await CoverStorage.store(
      folder: 'journal',
      fromCamera: camera,
    );
    if (path != null && mounted) setState(() => _photos.add(path));
  }

  Future<void> _save() async {
    final controller = context.read<JournalController>();
    final minutes = _time == null ? null : _time!.hour * 60 + _time!.minute;
    final existing = widget.entry;

    if (existing == null) {
      await controller.create(
        date: widget.date,
        kind: widget.kind,
        text: _text.text,
        minutes: minutes,
        photos: _photos,
      );
    } else {
      await controller.save(
        existing.copyWith(
          date: widget.date,
          kind: widget.kind,
          text: _text.text.trim(),
          minutes: minutes,
          clearMinutes: minutes == null,
          photos: _photos,
        ),
      );
    }

    AppNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final minimal = settings.isMinimalStyle;
    final express = settings.isExpressStyle;
    final accent = context.colors.primary;
    final title = widget.kind == JournalEntryKind.reflection
        ? context.l10n.journal_daily_reflection
        : context.l10n.journal_add_moment;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: minimal ? 52 : null,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(LucideIcons.arrowLeftDir),
          onPressed: AppNavigator.pop,
        ),
        title: minimal || express ? null : Text(title),
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
          minimal ? 22 : 16,
          8,
          minimal ? 22 : 16,
          28,
        ),
        children: [
          if (minimal) MinimalTitle(title: title),
          if (express)
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
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(minimal ? 20 : 16),
            ),
            child: TextField(
              controller: _text,
              autofocus: widget.entry == null,
              minLines: widget.kind == JournalEntryKind.reflection ? 6 : 4,
              maxLines: 12,
              maxLength: 20000,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                border: InputBorder.none,
                counterText: '',
                hintText: widget.kind == JournalEntryKind.reflection
                    ? context.l10n.journal_write_reflection
                    : context.l10n.journal_write_moment,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addPhoto(camera: true),
                  icon: const Icon(LucideIcons.camera, size: 18),
                  label: Text(context.l10n.note_take_photo),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addPhoto,
                  icon: const Icon(LucideIcons.image, size: 18),
                  label: Text(context.l10n.note_pick_photo),
                ),
              ),
            ],
          ),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 14),
            PhotoDeck(
              shots: [for (final path in _photos) PhotoShot(path: path)],
              onRemove: (index) => setState(() => _photos.removeAt(index)),
            ),
          ],
          const SizedBox(height: 18),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.clock, size: 18, color: context.tokens.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _time?.format(context) ?? context.l10n.note_time_optional,
                      style: TextStyle(
                        color: _time == null
                            ? context.tokens.muted
                            : context.colors.onSurface,
                      ),
                    ),
                  ),
                  if (_time != null)
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () => setState(() => _time = null),
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _canSave ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
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
