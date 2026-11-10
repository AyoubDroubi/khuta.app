import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/services/backup_service.dart';
import 'package:khuta/services/folder_sync.dart';

// new backups are named khuta_backup_*, older
// streak_backup_* files stay readable, and order is by time, not by name.
void main() {
  test('both prefixes are backups; other files are not', () {
    expect(BackupService.isBackupName('khuta_backup_2026-11-08_10-00-00.json'),
        isTrue);
    expect(BackupService.isBackupName('streak_backup_2026-11-08_10-00-00.json'),
        isTrue);
    expect(BackupService.isBackupName('notes.json'), isFalse);
    expect(BackupService.isBackupName('khuta_backup_x.txt'), isFalse);
  });

  test('old and new backups are ordered newest first by their time', () {
    final dir = Directory.systemTemp.createTempSync('backup_names');
    addTearDown(() => dir.deleteSync(recursive: true));
    for (final name in [
      'streak_backup_2026-11-01_09-00-00.json',
      'khuta_backup_2026-11-02_09-00-00.json',
      'streak_backup_2026-11-03_09-00-00.json',
      'other.json',
    ]) {
      File('${dir.path}/$name').writeAsStringSync('{}');
    }
    final names = FolderSync.backupsIn(dir)
        .map((f) => f.uri.pathSegments.last)
        .toList();
    expect(names, [
      'streak_backup_2026-11-03_09-00-00.json',
      'khuta_backup_2026-11-02_09-00-00.json',
      'streak_backup_2026-11-01_09-00-00.json',
    ]);
  });
}
