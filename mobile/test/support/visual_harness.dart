import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show RepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// real fonts for screenshots (flutter_test renders text with a
/// placeholder font otherwise). Families match `pubspec.yaml`.
Future<void> loadAppFonts() async {
  const families = <String, List<String>>{
    'Figtree': [
      'fonts/Figtree-Light.ttf',
      'fonts/Figtree-Regular.ttf',
      'fonts/Figtree-Medium.ttf',
      'fonts/Figtree-SemiBold.ttf',
      'fonts/Figtree-Bold.ttf',
      'fonts/Figtree-ExtraBold.ttf',
      'fonts/Figtree-Black.ttf',
    ],
    'GoogleSansFlex': ['fonts/GoogleSansFlex.ttf'],
    'IBMPlexSansArabic': [
      'fonts/IBMPlexSansArabic-Light.ttf',
      'fonts/IBMPlexSansArabic-Regular.ttf',
      'fonts/IBMPlexSansArabic-Medium.ttf',
      'fonts/IBMPlexSansArabic-SemiBold.ttf',
      'fonts/IBMPlexSansArabic-Bold.ttf',
    ],
    'PlayfairDisplay': [
      'fonts/PlayfairDisplay.ttf',
      'fonts/PlayfairDisplay-Italic.ttf',
    ],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final file = File(path);
      if (!file.existsSync()) continue;
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
    await loader.load();
  }
  await _loadPackageIconFonts();
  await _loadMaterialIcons();
}

/// Material icons ship with the Flutter SDK; load them so screenshots show
/// icons instead of placeholder boxes.
Future<void> _loadMaterialIcons() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) return;
  final file = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!file.existsSync()) return;
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
}

/// Lucide icons come from a package font; register every family the package
/// declares under its `packages/<name>/` prefix so icons render.
Future<void> _loadPackageIconFonts() async {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return;
  final packages = (jsonDecode(config.readAsStringSync())['packages'] as List)
      .cast<Map<String, dynamic>>();
  for (final package in packages.where(
    (p) => p['name'] == 'lucide_icons_flutter',
  )) {
    final root = Uri.parse(package['rootUri'] as String).toFilePath();
    final pubspec = File('$root/pubspec.yaml').readAsLinesSync();
    String? family;
    for (final line in pubspec) {
      final f = RegExp(r'^\s*- family:\s*(\S+)').firstMatch(line);
      if (f != null) family = f.group(1);
      final a = RegExp(r'^\s*- asset:\s*(\S+\.ttf)').firstMatch(line);
      if (a != null && family != null) {
        final file = File('$root/${a.group(1)}');
        if (!file.existsSync()) continue;
        final loader = FontLoader('packages/lucide_icons_flutter/$family')
          ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
        await loader.load();
      }
    }
  }
}

/// Writes a PNG of the whole screen when `SCREENSHOT_DIR` is set; otherwise
/// does nothing, so normal test runs stay fast and write no files.
Future<void> captureScreen(WidgetTester tester, String name) async {
  final dir = Platform.environment['SCREENSHOT_DIR'];
  if (dir == null || dir.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}
