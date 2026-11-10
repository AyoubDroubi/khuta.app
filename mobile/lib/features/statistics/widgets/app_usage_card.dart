import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/express/express_surface.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/minimal/minimal_kit.dart';
import 'package:khuta/core/widgets/classic_ui.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';
import 'package:khuta/features/statistics/data/app_usage.dart';
import 'package:khuta/features/statistics/state/app_usage_controller.dart';
import 'package:khuta/features/statistics/widgets/app_usage_source.dart';

class AppUsageCard extends StatefulWidget {
  const AppUsageCard({
    super.key,
    this.source,
    this.platform,
  });

  final AppUsageSource? source;
  final TargetPlatform? platform;

  @override
  State<AppUsageCard> createState() => _AppUsageCardState();
}

class _AppUsageCardState extends State<AppUsageCard>
    with AutomaticKeepAliveClientMixin {
  AppUsageController? _own;
  AppUsageController? _controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scoped = AppUsageScope.maybeOf(context);
    final next =
        scoped ??
        (_own ??= AppUsageController(
          source: widget.source,
          platform: widget.platform,
        ));
    if (!identical(next, _controller)) {
      _controller?.removeListener(_onChanged);
      _controller = next..addListener(_onChanged);
    }
    if (scoped == null) _own!.setActive(TickerMode.valuesOf(context).enabled);
  }

  AppUsageController get _usage => _controller!;

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChanged);
    _own?.dispose();
    super.dispose();
  }

  String _durationLabel(BuildContext context, Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return context.l10n.app_usage_duration_hours_minutes(hours, minutes);
    }
    if (duration.inMinutes > 0) {
      return context.l10n.app_usage_duration_minutes(duration.inMinutes);
    }
    return context.l10n.app_usage_duration_under_minute;
  }

  Widget _frame(BuildContext context, Widget child) {
    final settings = context.watch<SettingsController>();
    if (settings.isExpressStyle) {
      return ExpressCard(
        padding: const EdgeInsets.all(18),
        child: child,
      );
    }
    if (settings.isMinimalStyle) {
      return MinimalCard(
        padding: const EdgeInsets.all(18),
        child: child,
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }

  Widget _appIcon(BuildContext context, AppUsageEntry app) {
    final bytes = app.iconPng;
    if (bytes == null || bytes.isEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: context.colors.surfaceContainerHighest,
        child: Icon(
          LucideIcons.appWindow,
          size: 17,
          color: context.tokens.muted,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Image.memory(
        bytes,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          LucideIcons.appWindow,
          size: 18,
          color: context.tokens.muted,
        ),
      ),
    );
  }

  Widget _appRow(BuildContext context, AppUsageEntry app) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: [
        _appIcon(context, app),
        const SizedBox(width: 12),
        Expanded(
          child: AutoDirectionText(
            app.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _durationLabel(context, app.foreground),
          style: TextStyle(
            color: context.tokens.muted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );

  Widget _permissionBody(
    BuildContext context, {
    required bool hasAccess,
    required String buttonLabel,
  }) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.app_usage_disclosure,
          style: TextStyle(color: context.tokens.muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _usage.busy ? null : _usage.continueFlow,
            icon: Icon(
              hasAccess ? LucideIcons.chartColumn : LucideIcons.shieldCheck,
              size: 18,
            ),
            label: Text(buttonLabel),
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context) {
    final l10n = context.l10n;
    final summary = _usage.summary;
    final body = switch (_usage.status) {
      AppUsageStatus.checking || AppUsageStatus.loading => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            if (_usage.status == AppUsageStatus.loading)
              Text(
                l10n.app_usage_loading,
                style: TextStyle(color: context.tokens.muted),
              ),
          ],
        ),
      ),
      AppUsageStatus.consent => _permissionBody(
        context,
        hasAccess: true,
        buttonLabel: l10n.app_usage_accept_and_show,
      ),
      AppUsageStatus.needsAccess => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.app_usage_access_off,
            style: TextStyle(color: context.tokens.muted),
          ),
          const SizedBox(height: 8),
          _permissionBody(
            context,
            hasAccess: false,
            buttonLabel: l10n.app_usage_open_settings,
          ),
        ],
      ),
      AppUsageStatus.unsupported => Text(
        l10n.app_usage_unsupported,
        style: TextStyle(color: context.tokens.muted),
      ),
      AppUsageStatus.error => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.app_usage_error,
            style: TextStyle(color: context.tokens.muted),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _usage.busy ? null : _usage.refresh,
            icon: const Icon(LucideIcons.rotateCw, size: 17),
            label: Text(l10n.app_usage_retry),
          ),
        ],
      ),
      AppUsageStatus.ready when summary == null => const SizedBox.shrink(),
      AppUsageStatus.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.app_usage_total,
                  style: TextStyle(color: context.tokens.muted),
                ),
              ),
              Text(
                _durationLabel(context, summary!.totalForeground),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (summary.apps.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                l10n.app_usage_empty,
                style: TextStyle(color: context.tokens.muted),
              ),
            )
          else ...[
            const SizedBox(height: 16),
            Text(
              l10n.app_usage_most_used,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final app in summary.apps) _appRow(context, app),
          ],
          const SizedBox(height: 12),
          Text(
            l10n.app_usage_local_only,
            style: TextStyle(
              color: context.tokens.muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    };

    return _frame(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.smartphone, color: context.colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.app_usage_title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_usage.status == AppUsageStatus.ready)
                IconButton(
                  tooltip: l10n.app_usage_retry,
                  onPressed: _usage.busy ? null : _usage.refresh,
                  icon: const Icon(LucideIcons.rotateCw, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _content(context);
  }
}
