import 'package:flutter/foundation.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/capture/data/proposed_item.dart';
import 'package:khuta/features/capture/data/rule_parser.dart';
import 'package:khuta/features/capture/state/capture_saver.dart';
import 'package:khuta/features/journal/state/journal_controller.dart';
import 'package:khuta/features/todos/data/todo.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';

/// The editable preview: what the parser proposed, which rows are checked, and
/// the one save. Nothing is written until [save].
class CaptureDraft extends ChangeNotifier {
  CaptureDraft(List<ProposedItem> items, {DateTime Function()? now})
      : _now = now ?? AppClock.wallNow,
        _items = [...items],
        _checked = List.filled(items.length, true, growable: true),
        _ids = [for (var i = 0; i < items.length; i++) _nextId++];

  // Row ids are unique across drafts, so a view that keys per-row state to
  // them never reuses a row from an earlier draft.
  static int _nextId = 0;

  final DateTime Function() _now;
  final List<ProposedItem> _items;
  final List<bool> _checked;
  final List<int> _ids;
  bool _saving = false;
  bool _disposeAfterSave = false;
  int _lastFailed = 0;

  /// How many rows the last save could not write; they are still in [rows].
  int get lastFailed => _lastFailed;

  /// Each row keeps its [id] while rows before it are removed.
  List<({int id, ProposedItem item, bool checked})> get rows => [
        for (var i = 0; i < _items.length; i++)
          (id: _ids[i], item: _items[i], checked: _checked[i]),
      ];

  bool get saving => _saving;

  /// Nothing checked, a checked item without a title, or a checked reminder
  /// without a time.
  bool get saveBlocked {
    var any = false;
    for (var i = 0; i < _items.length; i++) {
      if (!_checked[i]) continue;
      any = true;
      if (_items[i].needsTime || _items[i].title.trim().isEmpty) return true;
    }
    return !any;
  }

  void toggle(int i) {
    _checked[i] = !_checked[i];
    notifyListeners();
  }

  void remove(int i) {
    _items.removeAt(i);
    _checked.removeAt(i);
    _ids.removeAt(i);
    notifyListeners();
  }

  void retitle(int i, String title) => _edit(i, (it) => it.copyWith(title: title));

  void setDay(int i, DateTime? day) => _edit(
        i,
        (it) => _flagPassed(
          day == null ? it.copyWith(clearDay: true) : it.copyWith(day: day),
        ),
      );

  void setMinutes(int i, int? minutes) => _edit(
        i,
        (it) => _flagPassed(
          minutes == null
              ? it.copyWith(clearMinutes: true)
              : it.copyWith(minutes: minutes),
        ),
      );

  void clearProject(int i) => _edit(i, (it) => it.copyWith(project: ''));

  void removeTag(int i, String id) => _edit(
        i,
        (it) => it.copyWith(tags: [...it.tags]..remove(id)),
      );

  void clearPriority(int i) =>
      _edit(i, (it) => it.copyWith(priority: TodoPriority.none));

  /// A note becomes a to-do and back. A note keeps no priority, project,
  /// labels or reminder (a journal entry has none); a to-do's title is capped
  /// at the composer's limit.
  void toggleKind(int i) => _edit(i, (it) {
        if (it.kind == ProposedKind.task) {
          return it.copyWith(
            kind: ProposedKind.note,
            priority: TodoPriority.none,
            project: '',
            tags: const [],
            askedToRemind: false,
            timePassed: false,
          );
        }
        return it.copyWith(kind: ProposedKind.task, title: capTitle(it.title));
      });

  void unmarkRemind(int i) => _edit(i, (it) => it.copyWith(askedToRemind: false));

  ProposedItem _flagPassed(ProposedItem it) {
    // A note records something; it is never "too late".
    if (it.kind == ProposedKind.note) return it.copyWith(timePassed: false);
    final day = it.day;
    final minutes = it.minutes;
    final passed = day != null &&
        minutes != null &&
        DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60)
            .isBefore(_now());
    return it.copyWith(timePassed: passed);
  }

  void _edit(int i, ProposedItem Function(ProposedItem) change) {
    _items[i] = change(_items[i]);
    notifyListeners();
  }

  @override
  void dispose() {
    // A save in flight still needs to finish and report; dispose after it.
    if (_saving) {
      _disposeAfterSave = true;
      return;
    }
    super.dispose();
  }

  /// Saves the checked rows. Returns `null` when a save is already running.
  /// Saved rows leave the draft; failed and unchecked rows stay.
  Future<CaptureSaveResult?> save({
    required TodosController todos,
    required JournalController journal,
    required DateTime today,
  }) async {
    if (_saving) return null;
    if (saveBlocked) {
      throw StateError('Nothing can be saved yet: a row needs attention.');
    }
    _saving = true;
    notifyListeners();
    try {
      final ids = <int>[];
      final checked = <ProposedItem>[];
      for (var i = 0; i < _items.length; i++) {
        if (!_checked[i]) continue;
        ids.add(_ids[i]);
        checked.add(_items[i]);
      }
      final result = await saveProposedItems(
        checked,
        todos: todos,
        journal: journal,
        today: today,
      );
      _lastFailed = result.failed.length;
      // Match saved items back by row id, so a row edited during the save
      // still leaves the draft.
      final savedIds = {
        for (var k = 0; k < checked.length; k++)
          if (result.saved.any((s) => identical(s, checked[k]))) ids[k],
      };
      for (var i = _items.length - 1; i >= 0; i--) {
        if (savedIds.contains(_ids[i])) {
          _items.removeAt(i);
          _checked.removeAt(i);
          _ids.removeAt(i);
        }
      }
      return result;
    } finally {
      _saving = false;
      if (_disposeAfterSave) {
        super.dispose();
      } else {
        notifyListeners();
      }
    }
  }
}
