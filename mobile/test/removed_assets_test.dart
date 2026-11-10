import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/features/focus/state/focus_audio.dart';
import 'package:khuta/features/focus/widgets/focus_backgrounds.dart';
import 'package:khuta/features/focus/widgets/music_sheet.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';

import 'support/app_harness.dart';

// the bundled sounds and background
// images had no documented license and were removed.
void main() {
  useEmptyStore();

  test('the removed files are no longer bundled', () async {
    for (final path in const [
      'assets/sounds/chime.ogg',
      'assets/sounds/rain.ogg',
      'assets/sounds/one_love.ogg',
      'assets/sounds/i_can_find_you.ogg',
      'assets/backgrounds/night_city.jpg',
      'assets/backgrounds/street_lamp.jpg',
      'assets/backgrounds/lantern_tree.jpg',
      'assets/backgrounds/frog_pond.jpg',
      'assets/backgrounds/valley_river.jpg',
      'assets/backgrounds/forest_cabin.jpg',
    ]) {
      await expectLater(
        () => rootBundle.load(path),
        throwsA(anything),
        reason: '$path is still bundled',
      );
    }
  });

  test('there are no built-in focus tracks', () {
    expect(builtInTracks, isEmpty);
  });

  test('removed image scenes resolve to the plain scene', () {
    for (var scene = 1; scene <= 6; scene++) {
      expect(resolveFocusScene(scene), 0);
    }
    expect(resolveFocusScene(0), 0);
    expect(resolveFocusScene(kCustomScene), kCustomScene);
    expect(resolveFocusScene(kFirstVideoScene), kFirstVideoScene);
  });

  test('a saved removed scene falls back to the plain scene', () async {
    await LocalStore.writeSetting('focusScene', 3);
    expect(SettingsController().focusScene, 0);

    await LocalStore.writeSetting('focusScene', kCustomScene);
    expect(SettingsController().focusScene, kCustomScene);
  });

  test('a fresh install starts on the plain scene', () {
    expect(SettingsController().focusScene, 0);
  });

  test('the default end-of-round alert is silent and does not throw', () async {
    await FocusAudio.alert('');
    await FocusAudio.alert(FocusAudio.silentAlert);
  });

  testWidgets('the music sheet lists no built-in track and a silent alert', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMusicSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    for (final name in const ['Rain', 'One Love', 'I Can Find You']) {
      expect(find.text(name), findsNothing);
    }
    expect(find.text('Silent'), findsOneWidget);
  });
}
