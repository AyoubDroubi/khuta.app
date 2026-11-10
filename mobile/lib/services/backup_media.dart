import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Photos and covers in a backup.
///
/// A backup with images is a zip: `backup.json` (the usual payload) plus
/// `media/<folder>/<file>` for every image the data points at. Importing
/// copies the images into the app's data folder and rewrites the stored
/// paths to the new location, so a backup restores on another phone.
class BackupMedia {
  const BackupMedia._();

  static const dataEntry = 'backup.json';
  static const mediaPrefix = 'media/';

  /// True for a zip that holds a Khuta backup (and not another app's export).
  static bool isBackupZip(List<int> bytes) {
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) return false;
    try {
      return ZipDecoder().decodeBytes(bytes).files.any((f) => f.name == dataEntry);
    } catch (_) {
      return false;
    }
  }

  /// Every string in [payload] that is a file under [root], as
  /// `original path → zip entry`.
  static Map<String, String> referencedFiles(Object? payload, String root) {
    final prefix = '$root/';
    final found = <String, String>{};
    void walk(Object? node) {
      if (node is String) {
        final clean = node.split('?').first;
        if (!clean.startsWith(prefix) || found.containsKey(clean)) return;
        final relative = clean.substring(prefix.length);
        if (relative.isEmpty || relative.split('/').contains('..')) return;
        if (!File(clean).existsSync()) return;
        if (safeRelative(relative) == null) return;
        found[clean] = '$mediaPrefix$relative';
      } else if (node is Map) {
        node.values.forEach(walk);
      } else if (node is Iterable) {
        node.forEach(walk);
      }
    }

    walk(payload);
    return found;
  }

  /// The zip bytes for [json], or null when it references no image.
  static List<int>? pack(String json, String root) {
    final files = referencedFiles(jsonDecode(json), root);
    if (files.isEmpty) return null;
    final archive = Archive()..addFile(_entry(dataEntry, utf8.encode(_withMedia(json, files))));
    for (final entry in files.entries) {
      archive.addFile(_entry(entry.value, File(entry.key).readAsBytesSync()));
    }
    return ZipEncoder().encode(archive);
  }

  static ArchiveFile _entry(String name, List<int> bytes) => ArchiveFile(name, bytes.length, bytes);

  static String _withMedia(String json, Map<String, String> files) {
    final map = Map<String, dynamic>.from(jsonDecode(json) as Map);
    map['media'] = {for (final e in files.entries) e.value: e.key};
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Folders (under the app data folder) that restored images may go to, and
  /// the file types allowed. Anything else in a zip is ignored, so a crafted
  /// backup cannot overwrite the database or other app files.
  static const allowedFolders = ['covers', 'journey', 'journeys', 'journal', 'todos', 'focus'];
  /// Root-level image files the app writes itself (profile photo, background).
  static const rootPrefixes = ['profile_', 'bg_'];
  static const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
  static const maxEntries = 5000;
  static const maxEntryBytes = 40 * 1024 * 1024;
  static const maxTotalBytes = 400 * 1024 * 1024;

  /// [relative] when it is a single image file directly in an allowed folder,
  /// or a root-level `profile_*`/`bg_*` image; otherwise null.
  static String? safeRelative(String relative) {
    if (relative.contains('\\') || relative.contains('\u0000')) return null;
    final parts = relative.split('/');
    if (parts.length > 2 || parts.isEmpty) return null;
    final name = parts.last;
    if (parts.length == 2) {
      if (!allowedFolders.contains(parts[0])) return null;
    } else if (!rootPrefixes.any(name.startsWith)) {
      return null;
    }
    if (name.isEmpty || name.startsWith('.') || name.contains('..')) return null;
    final dot = name.lastIndexOf('.');
    if (dot < 1) return null;
    if (!allowedExtensions.contains(name.substring(dot + 1).toLowerCase())) return null;
    return relative;
  }

  /// The JSON text inside a backup zip. With [extractTo] the images are
  /// copied there and the stored paths are rewritten to the new files.
  /// Entries that are not allowed images, and anything over the size limits,
  /// are skipped.
  static String unpack(
    List<int> zip, {
    String? extractTo,
    int entryLimit = maxEntries,
    int entryBytes = maxEntryBytes,
    int totalBytes = maxTotalBytes,
  }) {
    final archive = ZipDecoder().decodeBytes(zip);
    final data = archive.files.firstWhere((f) => f.name == dataEntry);
    final text = utf8.decode(data.content as List<int>);
    if (extractTo == null) return text;

    final root = Map<String, dynamic>.from(jsonDecode(text) as Map);
    final manifest = root['media'] is Map ? Map<String, dynamic>.from(root['media'] as Map) : <String, dynamic>{};
    final moved = <String, String>{};
    var count = 0;
    var total = 0;
    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith(mediaPrefix)) continue;
      if (++count > entryLimit) break;
      final relative = safeRelative(file.name.substring(mediaPrefix.length));
      final original = manifest[file.name];
      if (relative == null || original is! String) continue;
      if (file.size > entryBytes || total + file.size > totalBytes) continue;
      try {
        final bytes = file.content as List<int>;
        if (bytes.length > entryBytes || total + bytes.length > totalBytes) continue;
        total += bytes.length;
        final target = File('$extractTo/$relative');
        target.parent.createSync(recursive: true);
        target.writeAsBytesSync(bytes);
        moved[original] = target.path;
      } catch (e) {
        debugPrint('Could not restore ${file.name}: $e');
      }
    }
    root.remove('media');
    return jsonEncode(_rewrite(root, moved));
  }

  static Object? _rewrite(Object? node, Map<String, String> moved) {
    if (node is String) {
      final clean = node.split('?').first;
      final to = moved[clean];
      if (to == null) return node;
      return node.length > clean.length ? '$to${node.substring(clean.length)}' : to;
    }
    if (node is Map) return {for (final e in node.entries) e.key: _rewrite(e.value, moved)};
    if (node is List) return [for (final e in node) _rewrite(e, moved)];
    return node;
  }
}
