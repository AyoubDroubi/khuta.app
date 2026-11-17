import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/capture/data/proposed_item.dart';
import 'package:khuta/features/journal/data/journal_entry.dart';
import 'package:khuta/features/journal/state/journal_controller.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';
import 'package:uuid/uuid.dart';

class CaptureSaveResult {
  const CaptureSaveResult({this.saved = const [], this.failed = const []});

  final List<ProposedItem> saved;
  final List<ProposedItem> failed;
}

/// Writes [items] through the existing controllers, so notifications, widgets
/// and backup behave exactly as for items made by hand.
///
/// Throws [StateError], before writing anything, if an item still needs a
/// time. A write that fails is reported in `failed`; the rest are still saved.
Future<CaptureSaveResult> saveProposedItems(
  List<ProposedItem> items, {
  required TodosController todos,
  required JournalController journal,
  required DateTime today,
}) async {
  if (items.any((item) => item.needsTime)) {
    throw StateError('A reminder needs a time before it can be saved.');
  }
  final saved = <ProposedItem>[];
  final failed = <ProposedItem>[];
  for (final item in items) {
    // The controllers add an item to memory before its write finishes, so a
    // write that fails leaves a ghost in the list. Give the item its id here,
    // so exactly that one can be taken out again.
    final id = const Uuid().v4();
    final note = item.kind == ProposedKind.note;
    try {
      if (note) {
        await journal.create(
          date: (item.day ?? today).dayKey,
          kind: JournalEntryKind.moment,
          text: item.title,
          minutes: item.minutes,
          id: id,
        );
      } else {
        await todos.create(
          text: item.title,
          date: item.day?.dayKey ?? '',
          minutes: item.minutes,
          priority: item.priority,
          project: item.project,
          tags: item.tags,
          id: id,
        );
      }
      saved.add(item);
    } catch (_) {
      try {
        if (note) {
          if (journal.all.any((e) => e.id == id)) await journal.remove(id);
        } else {
          if (todos.all.any((t) => t.id == id)) await todos.remove(id);
        }
      } catch (_) {}
      failed.add(item);
    }
  }
  return CaptureSaveResult(saved: saved, failed: failed);
}
