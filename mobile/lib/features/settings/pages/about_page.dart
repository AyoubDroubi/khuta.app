import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:khuta/core/extensions/inset_extensions.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/features/settings/widgets/legal_notices.dart';

/// About: who made the app, and below it where it comes from. This is the
/// place of the Appropriate Legal Notices (the upstream attribution and the
/// open source licenses).
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = context.tokens.muted;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.about_app)),
      body: ListView(
        padding: context.pagePadding(16, 16, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.user,
                          size: 22, color: context.colors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ayoub Droubi',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: context.colors.onSurface,
                              ),
                            ),
                            Text(
                              l10n.dev_role,
                              style: TextStyle(fontSize: 13, color: muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.about_story,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: context.colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const LegalNotices(),
        ],
      ),
    );
  }
}
