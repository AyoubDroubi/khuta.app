import 'dart:typed_data';

class AppUsageEntry {
  const AppUsageEntry({
    required this.packageName,
    required this.name,
    required this.foreground,
    this.iconPng,
  });

  final String packageName;
  final String name;
  final Duration foreground;
  final Uint8List? iconPng;
}

class AppUsageSummary {
  AppUsageSummary({
    required this.totalForeground,
    required Iterable<AppUsageEntry> apps,
  }) : apps = List.unmodifiable(
         apps.toList()..sort((a, b) => b.foreground.compareTo(a.foreground)),
       );

  factory AppUsageSummary.fromPlatform(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid app usage response');
    }

    final totalMs = value['totalDurationMs'];
    final rawApps = value['apps'];
    final apps = <AppUsageEntry>[];
    if (rawApps is List) {
      for (final raw in rawApps) {
        if (raw is! Map) continue;
        final packageName = raw['packageName'];
        if (packageName is! String || packageName.isEmpty) continue;
        final rawDuration = raw['durationMs'];
        final durationMs = rawDuration is num ? rawDuration.toInt() : 0;
        final rawIcon = raw['icon'];
        final icon = switch (rawIcon) {
          final Uint8List bytes => bytes,
          final List<int> bytes => Uint8List.fromList(bytes),
          _ => null,
        };
        final rawName = raw['name'];
        apps.add(
          AppUsageEntry(
            packageName: packageName,
            name: rawName is String && rawName.isNotEmpty
                ? rawName
                : packageName,
            foreground: Duration(
              milliseconds: durationMs.clamp(0, 1 << 62).toInt(),
            ),
            iconPng: icon,
          ),
        );
      }
    }

    final sorted = apps..sort((a, b) => b.foreground.compareTo(a.foreground));
    final totalDurationMs = totalMs is num ? totalMs.toInt() : 0;
    return AppUsageSummary(
      totalForeground: Duration(
        milliseconds: totalDurationMs.clamp(0, 1 << 62).toInt(),
      ),
      apps: sorted.take(5),
    );
  }

  final Duration totalForeground;
  final List<AppUsageEntry> apps;
}
