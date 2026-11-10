import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:khuta/app/app_startup.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/services/backup_media.dart';

import 'support/app_harness.dart';

// an install that still
// carries the old sync bookkeeping keeps all its content, and a hostile
// backup zip cannot write outside the image folders.
void main() {
  useEmptyStore();

  test('legacy account bookkeeping is removed, user data is not', () async {
    await LocalStore.writeHabit(testHabit(id: 'h', name: 'Read', done: lastDays(3)));
    await LocalStore.writeSetting('dayCutoff', 3);
    await LocalStore.writeProfile(displayName: 'Ayoub', avatarPath: '/x.jpg');

    final sync = Hive.box('sync_state');
    for (final entry in {
      'op:1': {'id': '1'},
      'ver:habit:h': 4,
      'media:sha:abc': 'm1',
      'media:id:m1': '/p.jpg',
      'fp:habit::h': 'f',
      'rev:habit::h': 2,
      'cursor': 9,
      'accountOwnerId': 'owner',
      'normalizedBootstrapAt': '2026-01-01',
    }.entries) {
      await sync.put(entry.key, entry.value);
    }

    await LocalStore.dropLegacyAccountStateForTesting();

    for (final key in ['op:1', 'ver:habit:h', 'media:sha:abc', 'media:id:m1', 'fp:habit::h', 'rev:habit::h', 'cursor', 'accountOwnerId', 'normalizedBootstrapAt']) {
      expect(sync.containsKey(key), isFalse, reason: key);
    }
    expect(LocalStore.readHabits().keys, ['h']);
    expect(LocalStore.readHabits()['h']!.completions, hasLength(3));
    expect(LocalStore.setting('dayCutoff', 0), 3);
    expect(LocalStore.profile['displayName'], 'Ayoub');
  });

  test('a cold start keeps what an earlier version stored', () async {
    await LocalStore.writeHabit(testHabit(id: 'k', name: 'Keep', done: lastDays(2)));
    await Hive.box('sync_state').put('op:9', {'x': 1});
    await coldStart();
    expect(LocalStore.readHabits()['k']!.completions, hasLength(2));
    expect(Hive.box('sync_state').containsKey('op:9'), isFalse);
  });

  group('hostile backup zip', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('khuta_zip'));
    tearDown(() => root.deleteSync(recursive: true));

    List<int> zip(Map<String, List<int>> media, {Map<String, String>? manifest}) {
      final archive = Archive()
        ..addFile(ArchiveFile(
          BackupMedia.dataEntry,
          0,
          utf8.encode(jsonEncode({
            'app': 'streak',
            'habits': <Object>[],
            'media': manifest ?? {for (final k in media.keys) k: '/old/phone/${k.split('/').last}'},
            'cover': [for (final k in media.keys) '/old/phone/${k.split('/').last}'],
          })),
        ));
      for (final e in media.entries) {
        archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
      }
      return ZipEncoder().encode(archive)!;
    }

    List<String> written() => root
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.substring(root.path.length + 1))
        .toList()
      ..sort();

    test('only single images in the allowed folders are extracted', () {
      final bytes = zip({
        'media/covers/ok.png': [1],
        'media/habits.hive': [2],
        'media/covers/../escape.png': [3],
        'media/covers/evil.exe': [4],
        'media/covers/sub/deep.png': [5],
        'media/other/a.png': [6],
        'media/covers/.hidden.png': [7],
        'media/covers/back\\\\slash.png': [8],
        'media/profile_1.jpg': [9],
        'media/bg_2.png': [10],
        'media/journal/j.webp': [11],
        'media/journeys/k.jpg': [12],
        'media/random.jpg': [13],
      });
      BackupMedia.unpack(bytes, extractTo: root.path);
      expect(written(), ['bg_2.png', 'covers/ok.png', 'journal/j.webp', 'journeys/k.jpg', 'profile_1.jpg']);
      expect(File('${root.parent.path}/escape.png').existsSync(), isFalse);
    });

    test('size and count limits skip the excess', () {
      final bytes = zip({
        'media/covers/a.png': List.filled(10, 1),
        'media/covers/b.png': List.filled(10, 1),
        'media/covers/c.png': List.filled(50, 1),
      });
      BackupMedia.unpack(bytes, extractTo: root.path, entryBytes: 20, totalBytes: 100);
      expect(written(), ['covers/a.png', 'covers/b.png']);
    });

    test('an entry limit stops extraction', () {
      final bytes = zip({for (var i = 0; i < 5; i++) 'media/covers/$i.png': [1]});
      BackupMedia.unpack(bytes, extractTo: root.path, entryLimit: 2);
      expect(written().length, 2);
    });

    test('a corrupt backup.json fails instead of being guessed', () {
      final archive = Archive()..addFile(ArchiveFile(BackupMedia.dataEntry, 3, [0xFF, 0xFE, 0x7B]));
      expect(() => BackupMedia.unpack(ZipEncoder().encode(archive)!, extractTo: root.path), throwsA(anything));
    });
  });

  testWidgets('AppStartup seeds default categories on a first launch', (tester) async {
    expect(LocalStore.readCategories(), isEmpty);
    await pumpScreen(tester, const AppStartup(child: Text('home')));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('home'), findsOneWidget);
    expect(LocalStore.readCategories(), isNotEmpty);
  });
}
