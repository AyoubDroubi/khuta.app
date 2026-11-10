import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// the app is local-first.
// These gates fail if network, account or sync code comes back.
void main() {
  final dart = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/'))
      .toList();

  test('the release manifest does not ask for the INTERNET permission', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest.contains('android.permission.INTERNET'), isFalse);
  });

  test('no network, account or sync dependency is declared', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final name in ['http', 'google_sign_in', 'flutter_secure_storage', 'url_launcher', 'dio', 'web_socket_channel']) {
      expect(RegExp('^  $name:', multiLine: true).hasMatch(pubspec), isFalse, reason: name);
    }
  });

  test('no source file uses the network or the removed account/sync modules', () {
    final banned = [
      'package:http/',
      'HttpClient',
      'WebSocket',
      'RawSocket',
      'Socket.connect',
      'core/auth/',
      'core/sync/',
      'core/data/account',
      'core/data/bootstrap',
      'features/auth/',
      'syncSnapshot',
      'applyRemoteSyncRecord',
      'syncCursor',
      'syncRevision',
      'syncFingerprint',
      'AccountMutationEngine',
      'AuthSessionManager',
    ];
    final hits = <String>[];
    for (final file in dart) {
      final text = file.readAsStringSync();
      for (final word in banned) {
        if (text.contains(word)) hits.add('${file.path}: $word');
      }
    }
    expect(hits, isEmpty);
  });
}
