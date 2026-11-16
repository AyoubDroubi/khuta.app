import 'package:flutter/foundation.dart';
import 'package:khuta/features/capture/data/proposed_item.dart';
import 'package:khuta/features/capture/state/capture_saver.dart';
import 'package:khuta/features/journal/state/journal_controller.dart';
import 'package:khuta/features/todos/state/todos_controller.dart';

/// The editable preview: what the parser proposed, which rows are checked, and
/// the one save. Nothing is written until [save].
class CaptureDraft extends ChangeNotifier {
  CaptureDraft(List<ProposedItem> items)
      : _items = [...items],
        _checked = List.filled(items.length, true, growable: true);

  final List<ProposedItem> _items;
  final List<bool> _checked;
  bool _saving = false;

  List<({ProposedItem item, bool checked})> get rows => [
        for (var i = 0; i < _items.length; i++)
          (item: _items[i], checked: _checked[i]),
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
    notifyListeners();
  }

  void retitle(int i, String title) => _edit(i, (it) => it.copyWith(title: title));

  void setDay(int i, DateTime? day) => _edit(
        i,
        (it) => day == null ? it.copyWith(clearDay: true) : it.copyWith(day: day),
      );

  void setMinutes(int i, int? minutes) => _edit(
        i,
        (it) => minutes == null
            ? it.copyWith(clearMinutes: true)
            : it.copyWith(minutes: minutes, timePassed: false),
      );

  void clearProject(int i) => _edit(i, (it) => it.copyWith(project: ''));

  void unmarkRemind(int i) => _edit(i, (it) => it.copyWith(askedToRemind: false));

  void _edit(int i, ProposedItem Function(ProposedItem) change) {
    _items[i] = change(_items[i]);
    notifyListeners();
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
      final checked = [
        for (var i = 0; i < _items.length; i++)
          if (_checked[i]) _items[i],
      ];
      final result = await saveProposedItems(
        checked,
        todos: todos,
        journal: journal,
        today: today,
      );
      for (final done in result.saved) {
        final i = _items.indexWhere((it) => identical(it, done));
        if (i != -1) {
          _items.removeAt(i);
          _checked.removeAt(i);
        }
      }
      return result;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
