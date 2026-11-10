import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:khuta/features/statistics/data/app_usage.dart';
import 'package:khuta/features/statistics/widgets/app_usage_source.dart';

enum AppUsageStatus {
  checking,
  consent,
  needsAccess,
  loading,
  ready,
  error,
  unsupported,
}

/// Same-day app-use state for one Statistics session.
///
/// Holds consent and results in memory only. It refreshes when it becomes
/// active and when the app resumes while active, independently of whether
/// the card showing it has been built yet.
class AppUsageController extends ChangeNotifier with WidgetsBindingObserver {
  AppUsageController({AppUsageSource? source, TargetPlatform? platform})
    : _source = source ?? const MethodChannelAppUsageSource(),
      _platformOverride = platform {
    WidgetsBinding.instance.addObserver(this);
  }

  final AppUsageSource _source;
  final TargetPlatform? _platformOverride;

  AppUsageStatus _status = AppUsageStatus.checking;
  AppUsageSummary? _summary;
  bool _active = false;
  bool _sessionConsent = false;
  bool _busy = false;
  bool _disposed = false;

  AppUsageStatus get status => _status;
  AppUsageSummary? get summary => _summary;
  bool get busy => _busy;

  TargetPlatform get _platform => _platformOverride ?? defaultTargetPlatform;

  void setActive(bool active) {
    final becameActive = active && !_active;
    _active = active;
    if (becameActive) unawaited(refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _active && _sessionConsent) {
      unawaited(refresh());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _set(AppUsageStatus status) {
    _status = status;
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    if (_disposed || !_active || _busy) return;
    if (_platform != TargetPlatform.android) {
      _set(AppUsageStatus.unsupported);
      return;
    }

    _busy = true;
    _set(AppUsageStatus.checking);
    try {
      final hasAccess = await _source.hasUsageAccess();
      if (_disposed) return;
      if (!_sessionConsent) {
        _summary = null;
        _set(AppUsageStatus.consent);
        return;
      }
      if (!hasAccess) {
        _summary = null;
        _set(AppUsageStatus.needsAccess);
        return;
      }

      _set(AppUsageStatus.loading);
      final summary = await _source.readToday();
      if (_disposed) return;
      _summary = summary;
      _set(AppUsageStatus.ready);
    } catch (_) {
      if (!_disposed) _set(AppUsageStatus.error);
    } finally {
      _busy = false;
      _changed();
    }
  }

  Future<void> continueFlow() async {
    if (!_active || _busy) return;
    if (_status == AppUsageStatus.needsAccess) {
      _busy = true;
      _changed();
      try {
        final opened = await _source.openUsageAccessSettings();
        if (_disposed) return;
        if (!opened) {
          _set(AppUsageStatus.error);
          return;
        }
      } catch (_) {
        if (!_disposed) _set(AppUsageStatus.error);
        return;
      } finally {
        _busy = false;
      }
      if (!_disposed && _active) await refresh();
      return;
    }
    _sessionConsent = true;
    await refresh();
  }
}

/// Owns the [AppUsageController] for a Statistics page so the access check
/// runs when Statistics opens, even while the card is below the fold of a
/// lazy list.
class AppUsageScope extends StatefulWidget {
  const AppUsageScope({super.key, required this.child});

  final Widget child;

  static AppUsageController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_AppUsageScopeData>()
      ?.controller;

  @override
  State<AppUsageScope> createState() => _AppUsageScopeState();
}

class _AppUsageScopeState extends State<AppUsageScope> {
  final AppUsageController _controller = AppUsageController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.setActive(TickerMode.valuesOf(context).enabled);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _AppUsageScopeData(controller: _controller, child: widget.child);
}

class _AppUsageScopeData extends InheritedWidget {
  const _AppUsageScopeData({required this.controller, required super.child});

  final AppUsageController controller;

  @override
  bool updateShouldNotify(_AppUsageScopeData oldWidget) =>
      controller != oldWidget.controller;
}
