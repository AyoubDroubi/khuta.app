import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/features/daily_plan/data/daily_plan.dart';
import 'package:khuta/features/goals/data/goal.dart';
import 'package:khuta/features/habits/data/habit_note.dart';
import 'package:khuta/features/habits/state/habits_controller.dart';
import 'package:khuta/features/journal/data/journal_entry.dart';
import 'package:khuta/features/journeys/data/journey.dart';
import 'package:khuta/features/todos/data/todo.dart';
import 'package:khuta/services/backup_media.dart';
import 'package:khuta/services/backup_service.dart';

import 'support/app_harness.dart';

// export -> wipe -> import brings back
// every entity, the settings that belong to a backup, and the images.
void main() {
  useEmptyStore();

  late Directory phoneA;
  late Directory phoneB;

  setUp(() {
    phoneA = Directory.systemTemp.createTempSync('khuta_phone_a');
    phoneB = Directory.systemTemp.createTempSync('khuta_phone_b');
  });
  tearDown(() {
    phoneA.deleteSync(recursive: true);
    phoneB.deleteSync(recursive: true);
  });

  String image(String folder, String name, List<int> bytes) {
    final file = File(folder.isEmpty ? '${phoneA.path}/$name' : '${phoneA.path}/$folder/$name')..createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    return file.path;
  }

  Future<void> seed() async {
    final cover = image('covers', '1.jpg', [1, 2, 3, 4]);
    final jcover = image('journeys', '4.jpg', [4, 4]);
    final bg = image('', 'bg_1700000000001.jpg', [6]);
    final todoImg = image('todos', '5.png', [3]);
    final notePhoto = image('journey', '2.png', [9, 8, 7]);
    final journalPhoto = image('journal', '3.webp', [5, 5]);
    final avatar = image('', 'profile_1700000000000.jpg', [7]);

    await LocalStore.writeHabit(
      testHabit(id: 'a', name: 'Read', order: 0, done: lastDays(5)).copyWith(coverPath: cover),
    );
    await LocalStore.writeNote(HabitNote(
      id: 'n1',
      habitId: 'a',
      text: 'a note',
      date: '08-11-2026',
      type: NoteType.note,
      photos: [notePhoto],
      createdAt: DateTime.utc(2026, 11, 8),
    ));
    await LocalStore.writeJourney(Journey(
      id: 'j1',
      title: 'Journey',
      habitIds: const ['a'],
      coverPath: jcover,
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1),
    ));
    await LocalStore.writeGoal(Goal(
      id: 'g1',
      title: 'Goal',
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1),
    ));
    await LocalStore.writeJournalEntry(JournalEntry(
      id: 'e1',
      date: '08-11-2026',
      kind: JournalEntryKind.moment,
      text: 'moment',
      photos: [journalPhoto],
      createdAt: DateTime.utc(2026, 11, 8),
    ));
    await LocalStore.writeDailyPlan(DailyPlan(
      date: '08-11-2026',
      items: const [DailyPlanItem(type: DailyPlanSourceType.habit, sourceId: 'a')],
      updatedAt: DateTime.utc(2026, 11, 8),
    ));
    await LocalStore.writeSetting('dayCutoff', 4);
    await LocalStore.writeSetting('profilePhoto', avatar);
    await LocalStore.writeSetting('bgImage', bg);
    await LocalStore.writeTodo(Todo(id: 'td', text: 'Todo', createdAt: DateTime.utc(2026, 11, 1), photos: [todoImg]));
    await LocalStore.writeSetting('appLockPin', 'secret-hash');
    await LocalStore.writeProfile(displayName: 'Ayoub', avatarPath: avatar);
  }

  test('device-only settings (app lock, backup folder) never travel with a backup', () async {
    await seed();
    final settings = LocalStore.backupSettings();
    expect(settings['dayCutoff'], 4);
    expect(settings.containsKey('appLockPin'), isFalse);
    expect(settings.containsKey('autoBackupFolder'), isFalse);
    expect(settings['profilePhoto'], isNotNull);
  });

  test('without images the backup stays plain JSON', () async {
    await LocalStore.writeGoal(Goal(
      id: 'g',
      title: 'Only data',
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1),
    ));
    final json = BackupService.payloadForTesting(const []);
    expect(BackupMedia.pack(json, phoneA.path), isNull);
    expect(jsonDecode(json)['goals'], hasLength(1));
  });

  test('export -> wipe -> import on another phone restores everything and the images', () async {
    await seed();
    final json = BackupService.payloadForTesting(LocalStore.readHabits().values.toList());
    final zip = BackupMedia.pack(json, phoneA.path)!;
    expect(BackupMedia.isBackupZip(zip), isTrue);

    await LocalStore.wipeContent();
    await LocalStore.removeSetting('dayCutoff');
    await LocalStore.removeSetting('profilePhoto');
    await LocalStore.writeProfile(displayName: '', avatarPath: '');
    expect(LocalStore.setting('dayCutoff', 0), 0);
    expect(LocalStore.readGoals(), isEmpty);
    expect(LocalStore.readJourneys(), isEmpty);
    expect(LocalStore.readJournalEntries(), isEmpty);
    expect(LocalStore.readDailyPlans(), isEmpty);

    final data = BackupService.parseBytes(zip, extractTo: phoneB.path);
    expect(data.skipped, 0);
    expect(data.habits, hasLength(1));
    expect(data.notes, hasLength(1));
    expect(data.journeys, hasLength(1));
    expect(data.goals, hasLength(1));
    expect(data.journalEntries, hasLength(1));
    expect(data.dailyPlans, hasLength(1));
    expect(data.settings['dayCutoff'], 4);
    expect(data.profile['displayName'], 'Ayoub');

    // Images were copied to the new phone and the paths point there.
    final cover = data.habits.single.coverPath;
    expect(cover.startsWith(phoneB.path), isTrue);
    expect(File(cover).readAsBytesSync(), [1, 2, 3, 4]);
    expect(File(data.notes.single.photos.single).readAsBytesSync(), [9, 8, 7]);
    expect(File(data.journalEntries.single.photos.single).readAsBytesSync(), [5, 5]);
    expect(File(data.journeys.single.coverPath).readAsBytesSync(), [4, 4]);
    expect(File(data.todos.single.photos.single).readAsBytesSync(), [3]);
    expect(File(data.settings['bgImage'] as String).readAsBytesSync(), [6]);
    expect(data.profile['avatarPath'].toString().startsWith(phoneB.path), isTrue);
    expect(File(data.profile['avatarPath'] as String).readAsBytesSync(), [7]);

    await HabitsController().applyBackup(data, replace: true);
    expect(LocalStore.readGoals().single.title, 'Goal');
    expect(LocalStore.readJourneys().single.habitIds, ['a']);
    expect(LocalStore.readJournalEntries().single.text, 'moment');
    expect(LocalStore.readDailyPlans().single.items.single.sourceId, 'a');
    expect(LocalStore.setting('dayCutoff', 0), 4);
    expect(LocalStore.profile['displayName'], 'Ayoub');
    expect(LocalStore.setting('profilePhoto', ''), startsWith(phoneB.path));
  });

  test('an old backup without the new keys still imports', () async {
    final data = BackupService.parse(jsonEncode({
      'app': 'streak',
      'version': 1,
      'habits': [testHabit(id: 'o', name: 'Old').toMap()],
    }));
    expect(data.habits, hasLength(1));
    expect(data.goals, isEmpty);
    expect(data.settings, isEmpty);
  });

  test('a zip with a path trying to leave the media folder is ignored', () {
    final json = jsonEncode({'app': 'streak', 'habits': [testHabit(id: 'z', name: 'Z').toMap()]});
    expect(BackupMedia.isBackupZip(utf8.encode(json)), isFalse);
    expect(BackupMedia.referencedFiles({'p': '${phoneA.path}/../etc/passwd'}, phoneA.path), isEmpty);
  });

  test('a merge import keeps this phone\'s own settings', () async {
    await LocalStore.writeSetting('dayCutoff', 2);
    final data = BackupService.parse(jsonEncode({
      'app': 'streak',
      'habits': [testHabit(id: 'm', name: 'M').toMap()],
      'settings': {'dayCutoff': 9},
    }));
    await HabitsController().applyBackup(data, replace: false);
    expect(LocalStore.setting('dayCutoff', 0), 2);
  });
}
