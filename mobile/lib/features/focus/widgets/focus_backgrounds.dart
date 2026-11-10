import 'dart:io';

import 'package:flutter/material.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/features/focus/widgets/focus_video_scene.dart';
import 'package:khuta/features/focus/widgets/linux_video_scene.dart';

// Scenes 1–6 were bundled images, removed (no documented
// license). Their numbers stay reserved because scene indexes are saved
// settings; a saved image scene falls back to the plain scene 0.
const focusSceneCount = 7;

int resolveFocusScene(int scene) =>
    scene > 0 && scene < focusSceneCount ? 0 : scene;
const kCustomScene = focusSceneCount;
const kFirstVideoScene = focusSceneCount + 1;

int videoSceneIndex(int scene) {
  final index = scene - kFirstVideoScene;
  if (!hasVideoScenes || index < 0 || index >= focusVideoScenes.length) {
    return -1;
  }
  return index;
}

class FocusBackground extends StatelessWidget {
  const FocusBackground({
    super.key,
    required this.scene,
    required this.imagePath,
    required this.child,
  });

  final int scene;
  final String imagePath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasImage = scene == kCustomScene &&
        imagePath.isNotEmpty &&
        File(imagePath).existsSync();

    if (hasImage) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(imagePath), fit: BoxFit.cover),
          ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
          child,
        ],
      );
    }

    final video = videoSceneIndex(scene);
    if (video >= 0) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (Platform.isLinux)
            LinuxVideoScene(name: focusVideoScenes[video])
          else
            FocusVideoScene(name: focusVideoScenes[video]),
          ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
          child,
        ],
      );
    }

    return ColoredBox(color: Colors.black, child: child);
  }
}

class FocusScenePreview extends StatelessWidget {
  const FocusScenePreview({
    super.key,
    required this.scene,
    required this.imagePath,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final int scene;
  final String imagePath;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final video = videoSceneIndex(scene);
    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.app_background,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AspectRatio(
          aspectRatio: 0.78,
          child: Container(
            padding: EdgeInsets.all(selected ? 2.5 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: selected
                  ? Border.all(color: Colors.white, width: 2.5)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(selected ? 12 : 14),
              child: video >= 0
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        FocusVideoPoster(name: focusVideoScenes[video]),
                        ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
                      ],
                    )
                  : FocusBackground(
                      scene: scene,
                      imagePath: imagePath,
                      child: const SizedBox.expand(),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
