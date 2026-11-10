import 'package:flutter/foundation.dart';
import 'package:khuta/core/extensions/date_extensions.dart';
import 'package:khuta/features/journal/data/journal_entry.dart';
import 'package:khuta/features/journal/data/journal_repository.dart';
import 'package:uuid/uuid.dart';

class JournalController extends ChangeNotifier {
  JournalController({JournalRepository? repository})
      : _repository = repository ?? const JournalRepository() {
    _entries = _repository.readAll();
    _sort();
  }

  final JournalRepository _repository;
  static const _uuid = Uuid();
  late List<JournalEntry> _entries;

  List<JournalEntry> get all => List.unmodifiable(_entries);

  List<JournalEntry> forDay(String date) =>
      _entries.where((entry) => entry.date == date).toList()
        ..sort(_compareWithinDay);

  JournalEntry? reflectionForDay(String date) {
    for (final entry in _entries) {
      if (entry.date == date && entry.kind == JournalEntryKind.reflection) {
        return entry;
      }
    }
    return null;
  }

  Set<String> get daysWithEntries => _entries.map((entry) => entry.date).toSet();

  void reload() {
    _entries = _repository.readAll();
    _sort();
    notifyListeners();
  }

  Future<JournalEntry> create({
    required String date,
    required JournalEntryKind kind,
    required String text,
    int? minutes,
    List<String> photos = const [],
  }) async {
    _validateEntry(date, text, minutes, photos);
    if (kind == JournalEntryKind.reflection && reflectionForDay(date) != null) {
      throw StateError('A daily reflection already exists for this date.');
    }

    final entry = JournalEntry(
      id: _uuid.v4(),
      date: date,
      kind: kind,
      text: text.trim(),
      minutes: minutes,
      photos: List.unmodifiable(photos),
      createdAt: DateTime.now().toUtc(),
    );
    _entries.add(entry);
    _sort();
    await _repository.save(entry);
    notifyListeners();
    return entry;
  }

  Future<void> save(JournalEntry entry) async {
    _validateEntry(entry.date, entry.text, entry.minutes, entry.photos);
    if (entry.kind == JournalEntryKind.reflection) {
      final existing = reflectionForDay(entry.date);
      if (existing != null && existing.id != entry.id) {
        throw StateError('A daily reflection already exists for this date.');
      }
    }

    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      _entries.add(entry);
    } else {
      _entries[index] = entry;
    }
    _sort();
    await _repository.save(entry);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _entries.removeWhere((entry) => entry.id == id);
    await _repository.remove(id);
    notifyListeners();
  }

  static void _validateEntry(
    String date,
    String text,
    int? minutes,
    List<String> photos,
  ) {
    try {
      parseDayKey(date);
    } catch (_) {
      throw ArgumentError('Journal date is invalid.');
    }
    if (text.trim().length > 20000) {
      throw ArgumentError('Journal entry text is too long.');
    }
    if (text.trim().isEmpty && photos.isEmpty) {
      throw ArgumentError('Journal entry requires text or a photo.');
    }
    if (minutes != null && (minutes < 0 || minutes > 1439)) {
      throw ArgumentError('Journal entry time is invalid.');
    }
    if (photos.length > 8 || photos.toSet().length != photos.length) {
      throw ArgumentError('Journal entry photos are invalid.');
    }
  }

  void _sort() {
    _entries.sort((a, b) {
      final byDay = parseDayKey(b.date).compareTo(parseDayKey(a.date));
      return byDay != 0 ? byDay : _compareWithinDay(a, b);
    });
  }

  static int _compareWithinDay(JournalEntry a, JournalEntry b) {
    final am = a.minutes ?? 24 * 60;
    final bm = b.minutes ?? 24 * 60;
    if (am != bm) return am.compareTo(bm);
    return a.createdAt.compareTo(b.createdAt);
  }
}
