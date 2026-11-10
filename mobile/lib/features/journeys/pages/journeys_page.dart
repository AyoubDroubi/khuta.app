import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/extensions/inset_extensions.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/routing/app_navigator.dart';
import 'package:khuta/core/widgets/app_empty_state.dart';
import 'package:khuta/features/journeys/data/journey.dart';
import 'package:khuta/features/journeys/pages/journey_detail_page.dart';
import 'package:khuta/features/journeys/pages/journey_form_page.dart';
import 'package:khuta/features/journeys/state/journeys_controller.dart';
import 'package:khuta/features/settings/state/settings_controller.dart';

class JourneysPage extends StatelessWidget {
  const JourneysPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final controller = context.watch<JourneysController>();
    final minimal = settings.isMinimalStyle;
    final express = settings.isExpressStyle;
    final journeys = controller.all;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: minimal ? 52 : null,
        automaticallyImplyLeading: !embedded,
        leading: embedded
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(LucideIcons.arrowLeftDir),
                onPressed: AppNavigator.pop,
              ),
        title: minimal || express ? null : Text(context.l10n.journeys),
        actions: [
          IconButton(
            tooltip: context.l10n.journey_new,
            icon: const Icon(LucideIcons.plus),
            onPressed: () => AppNavigator.push(
              const JourneyFormPage(),
              fullscreenDialog: true,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: journeys.isEmpty
          ? AppEmptyState(
              icon: LucideIcons.route,
              title: context.l10n.journey_no_items,
              message: context.l10n.journey_no_items_sub,
              action: FilledButton.icon(
                onPressed: () => AppNavigator.push(
                  const JourneyFormPage(),
                  fullscreenDialog: true,
                ),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: Text(context.l10n.journey_new),
              ),
            )
          : ListView.separated(
              padding: context.pagePadding(
                minimal ? 20 : 16,
                10,
                minimal ? 20 : 16,
                36,
              ),
              itemCount: journeys.length + (minimal || express ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if ((minimal || express) && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      context.l10n.journeys,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: context.colors.onSurface,
                      ),
                    ),
                  );
                }

                final offset = minimal || express ? 1 : 0;
                final journey = journeys[index - offset];
                return _JourneyCard(
                  journey: journey,
                  onTap: () => AppNavigator.push(
                    JourneyDetailPage(journeyId: journey.id),
                  ),
                );
              },
            ),
      floatingActionButton: journeys.isEmpty || embedded
          ? null
          : FloatingActionButton(
              onPressed: () => AppNavigator.push(
                const JourneyFormPage(),
                fullscreenDialog: true,
              ),
              child: const Icon(LucideIcons.plus),
            ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.journey,
    required this.onTap,
  });

  final Journey journey;
  final VoidCallback onTap;

  String _status(BuildContext context) => switch (journey.status) {
        JourneyStatus.planned => context.l10n.journey_planned,
        JourneyStatus.active => context.l10n.journey_active,
        JourneyStatus.completed => context.l10n.journey_completed,
        JourneyStatus.archived => context.l10n.journey_archived,
      };

  @override
  Widget build(BuildContext context) {
    final completed =
        journey.milestones.where((item) => item.completed).length;
    final total = journey.milestones.length;
    final hasCover =
        journey.coverPath.isNotEmpty && File(journey.coverPath).existsSync();

    return Material(
      color: context.colors.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasCover)
              SizedBox(
                height: 118,
                width: double.infinity,
                child: Image.file(
                  File(journey.coverPath),
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          LucideIcons.route,
                          size: 19,
                          color: context.colors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          journey.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusChip(label: _status(context)),
                    ],
                  ),
                  if (journey.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      journey.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        height: 1.35,
                        color: context.tokens.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: journey.progress,
                      minHeight: 7,
                      backgroundColor:
                          context.colors.surface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        context.l10n.journey_progress(completed, total),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.tokens.muted,
                        ),
                      ),
                      const Spacer(),
                      if (journey.habitIds.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.repeat2,
                              size: 14,
                              color: context.tokens.muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${journey.habitIds.length}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.tokens.muted,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: context.colors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: context.colors.primary,
          ),
        ),
      );
}
