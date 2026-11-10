import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:khuta/core/utils/app_dirs.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/services/import_service.dart';
import 'package:khuta/features/focus/data/focus_session.dart';
import 'package:khuta/features/habits/data/category.dart';
import 'package:khuta/features/habits/data/habit.dart';
import 'package:khuta/features/daily_plan/data/daily_plan.dart';
import 'package:khuta/features/goals/data/goal.dart';
import 'package:khuta/features/habits/data/habit_note.dart';
import 'package:khuta/features/journal/data/journal_entry.dart';
import 'package:khuta/features/journeys/data/journey.dart';
import 'package:khuta/services/backup_media.dart';
import 'package:khuta/features/todos/data/todo.dart';
import 'package:khuta/features/todos/data/todo_tag.dart';
import 'package:khuta/services/vault_writer.dart';

const _kBackupVersion = 1;
const _kAutoBackupKeep = 5;

class BackupData {
  const BackupData({
    required this.habits,
    required this.notes,
    required this.focus,
    required this.todos,
    required this.todoTags,
    required this.categories,
    required this.skipped,
    this.exportedAt,
    this.journeys = const [],
    this.goals = const [],
    this.journalEntries = const [],
    this.dailyPlans = const [],
    this.settings = const {},
    this.profile = const {},
  });

  final List<Habit> habits;
  final List<HabitNote> notes;
  final List<FocusSession> focus;
  final List<Todo> todos;
  final List<TodoTag> todoTags;
  final List<Category> categories;
  final int skipped;
  final DateTime? exportedAt;
  final List<Journey> journeys;
  final List<Goal> goals;
  final List<JournalEntry> journalEntries;
  final List<DailyPlan> dailyPlans;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> profile;

  bool get isEmpty =>
      habits.isEmpty &&
      notes.isEmpty &&
      focus.isEmpty &&
      todos.isEmpty &&
      journeys.isEmpty &&
      goals.isEmpty &&
      journalEntries.isEmpty &&
      dailyPlans.isEmpty;
}

class BackupService {
  const BackupService._();

  /// Backup file names: new backups use [backupPrefix];
  /// backups written before the rename keep [legacyBackupPrefix] and stay
  /// readable.
  static const backupPrefix = 'khuta_backup_';
  static const legacyBackupPrefix = 'streak_backup_';

  static bool isBackupName(String name) =>
      (name.endsWith('.json') || name.endsWith('.zip')) &&
      (name.startsWith(backupPrefix) || name.startsWith(legacyBackupPrefix));

  /// The timestamp part of a backup name, used to order old and new names.
  static String stampOf(String name) => name.startsWith(backupPrefix)
      ? name.substring(backupPrefix.length)
      : name.startsWith(legacyBackupPrefix)
          ? name.substring(legacyBackupPrefix.length)
          : name;

  /// Marks files written by Khuta. Older backups carry `app: streak` and are
  /// still read (see [ImportService]).
  static const generatorId = 'khuta';

  @visibleForTesting
  static String payloadForTesting(List<Habit> habits) => _payloadFor(habits);

  static String _payloadFor(List<Habit> habits) {
    final payload = {
      'app': 'khuta',
      'generator': generatorId,
      'version': _kBackupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'habits': habits.map((h) => h.toMap()).toList(),
      'notes': LocalStore.readNotes().map((n) => n.toMap()).toList(),
      'focus':
          LocalStore.readFocusSessions().map((f) => f.toMap()).toList(),
      'todos': LocalStore.readTodos().map((t) => t.toMap()).toList(),
      'todoTags': LocalStore.readTodoTags().map((t) => t.toMap()).toList(),
      'categories':
          LocalStore.readCategories().map((c) => c.toMap()).toList(),
      'journeys': LocalStore.readJourneys().map((j) => j.toMap()).toList(),
      'goals': LocalStore.readGoals().map((g) => g.toMap()).toList(),
      'journalEntries':
          LocalStore.readJournalEntries().map((e) => e.toMap()).toList(),
      'dailyPlans': LocalStore.readDailyPlans().map((p) => p.toMap()).toList(),
      'settings': LocalStore.backupSettings(),
      'profile': LocalStore.profile,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// The file content for [habits]: a zip when images are referenced,
  /// otherwise the plain JSON.
  static Future<({List<int> bytes, String extension})> _encode(
    List<Habit> habits,
  ) async {
    final json = _payloadFor(habits);
    final root = (await appDataDir()).path;
    final zip = BackupMedia.pack(json, root);
    return zip == null
        ? (bytes: utf8.encode(json), extension: 'json')
        : (bytes: zip, extension: 'zip');
  }

  static Future<Directory?> defaultBackupDir() async {
    final root = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await appDataDir();
    if (root == null) return null;
    return Directory('${root.path}/backups');
  }

  static Future<bool> ensureStorageAccess() async {
    if (!Platform.isAndroid) return true;
    if (await Permission.manageExternalStorage.isGranted) return true;
    if (await Permission.storage.isGranted) return true;
    final manage = await Permission.manageExternalStorage.request();
    if (manage.isGranted) return true;
    final legacy = await Permission.storage.request();
    return legacy.isGranted;
  }

  static Future<String?> pickBackupFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return null;
    try {
      final probe = File('$path/.streak_write_test');
      await probe.writeAsString('ok');
      await probe.delete();
    } catch (_) {
      return '';
    }
    return path;
  }

  static Future<String?> runAuto({
    String folder = '',
    bool readable = true,
  }) async {
    final dir = folder.isEmpty
        ? await defaultBackupDir()
        : Directory(folder);
    if (dir == null) return null;
    try {
      if (!dir.existsSync()) await dir.create(recursive: true);
    } catch (_) {
      return null;
    }

    final stamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final habits = LocalStore.readHabits().values.toList();
    final encoded = await _encode(habits);
    final file = File('${dir.path}/$backupPrefix$stamp.${encoded.extension}');
    await file.writeAsBytes(encoded.bytes);

    try {
      if (readable) {
        await VaultWriter.write(
          Directory('${dir.path}/$vaultFolder'),
          habits: habits,
          categories: LocalStore.readCategories(),
          notes: LocalStore.readNotes(),
          todos: LocalStore.readTodos(),
          focus: LocalStore.readFocusSessions(),
        );
      }
    } catch (e) {
      debugPrint('Could not write the readable copy: $e');
    }

    String nameOf(File f) => f.uri.pathSegments.last;
    final old = dir
        .listSync()
        .whereType<File>()
        .where((f) => isBackupName(nameOf(f)))
        .toList()
      ..sort((a, b) => stampOf(nameOf(b)).compareTo(stampOf(nameOf(a))));
    for (final stale in old.skip(_kAutoBackupKeep)) {
      try {
        stale.deleteSync();
      } catch (_) {}
    }
    return file.path;
  }

  static Future<bool> export(List<Habit> habits, {Rect? origin}) async {
    final encoded = await _encode(habits);
    final stamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final name = '$backupPrefix$stamp.${encoded.extension}';

    if (!isMobile) {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save your Khuta backup',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: [encoded.extension],
      );
      if (path == null) return false;
      await File(path).writeAsBytes(encoded.bytes);
      return true;
    }

    final dir = await Directory.systemTemp.createTemp('streak_backup');
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(encoded.bytes);

    final result = await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType: encoded.extension == 'zip'
              ? 'application/zip'
              : 'application/json',
        ),
      ],
      subject: 'Khuta backup',
      sharePositionOrigin: origin,
    );
    return result.status == ShareResultStatus.success ||
        result.status == ShareResultStatus.dismissed;
  }

  static Future<BackupData> read() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select a Khuta backup file',
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      throw Exception('No file selected');
    }

    final picked = result.files.single;
    List<int>? bytes = picked.bytes;
    if (bytes == null && picked.path != null) {
      try {
        bytes = await File(picked.path!).readAsBytes();
      } catch (e) {
        debugPrint('Could not read ${picked.path}: $e');
        throw Exception('That file could not be read');
      }
    }
    if (bytes == null) {
      throw Exception('Could not read the selected file');
    }
    if (BackupMedia.isBackupZip(bytes)) {
      return parseBytes(bytes, extractTo: (await appDataDir()).path);
    }
    if (ImportService.looksLikeZip(bytes) ||
        ImportService.looksLikeSqlite(bytes)) {
      throw Exception(
        'That is an export from another app, not a Khuta backup. '
        'Use "Import from another app" for it.',
      );
    }

    return parseBytes(bytes);
  }

  /// Parses a backup file's bytes: plain JSON, or a zip with images. With
  /// [extractTo] the images are copied into that folder (the app's data
  /// folder) and the stored paths are rewritten to the new files.
  static BackupData parseBytes(List<int> bytes, {String? extractTo}) {
    if (BackupMedia.isBackupZip(bytes)) {
      return parse(BackupMedia.unpack(bytes, extractTo: extractTo));
    }
    return parse(const Utf8Decoder(allowMalformed: true).convert(bytes));
  }

  static BackupData parse(String raw) {
    dynamic decoded;
    try {
      decoded = json.decode(raw);
    } catch (_) {
      throw Exception('That file is not a valid backup');
    }

    final List<dynamic> entries;
    final Map<String, dynamic> root;
    if (decoded is List) {
      entries = decoded;
      root = const {};
    } else if (decoded is Map && decoded['habits'] is List) {
      entries = decoded['habits'] as List;
      root = Map<String, dynamic>.from(decoded);
    } else {
      throw Exception('Unrecognised backup format');
    }

    var skipped = 0;
    List<T> collect<T>(Object? source, T Function(Map<String, dynamic>) build) {
      if (source is! List) return <T>[];
      final out = <T>[];
      for (final raw in source) {
        if (raw is! Map) {
          skipped++;
          continue;
        }
        try {
          out.add(build(Map<String, dynamic>.from(raw)));
        } catch (_) {
          skipped++;
        }
      }
      return out;
    }

    final habits = collect(entries, Habit.fromMap);
    final data = BackupData(
      habits: habits,
      notes: collect(root['notes'], HabitNote.fromMap),
      focus: collect(root['focus'], FocusSession.fromMap),
      todos: collect(root['todos'], Todo.fromMap),
      todoTags: collect(root['todoTags'], TodoTag.fromMap),
      categories: collect(root['categories'], Category.fromMap),
      journeys: collect(root['journeys'], Journey.fromMap),
      goals: collect(root['goals'], Goal.fromMap),
      journalEntries: collect(root['journalEntries'], JournalEntry.fromMap),
      dailyPlans: collect(root['dailyPlans'], DailyPlan.fromMap),
      settings: root['settings'] is Map
          ? Map<String, dynamic>.from(root['settings'] as Map)
          : const {},
      profile: root['profile'] is Map
          ? Map<String, dynamic>.from(root['profile'] as Map)
          : const {},
      skipped: skipped,
      exportedAt: DateTime.tryParse((root['exportedAt'] ?? '') as String),
    );

    if (data.isEmpty) throw Exception('No habits found in that file');
    return data;
  }
}
