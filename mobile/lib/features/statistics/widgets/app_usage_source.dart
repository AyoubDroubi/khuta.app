import 'package:flutter/services.dart';
import 'package:khuta/features/statistics/data/app_usage.dart';

abstract interface class AppUsageSource {
  Future<bool> hasUsageAccess();

  Future<bool> openUsageAccessSettings();

  Future<AppUsageSummary> readToday();
}

class MethodChannelAppUsageSource implements AppUsageSource {
  const MethodChannelAppUsageSource({
    MethodChannel channel = const MethodChannel('khuta/app_usage'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<bool> hasUsageAccess() async =>
      await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;

  @override
  Future<bool> openUsageAccessSettings() async =>
      await _channel.invokeMethod<bool>('openUsageAccessSettings') ?? false;

  @override
  Future<AppUsageSummary> readToday() async {
    final result = await _channel.invokeMethod<Object?>('readToday');
    return AppUsageSummary.fromPlatform(result);
  }
}
