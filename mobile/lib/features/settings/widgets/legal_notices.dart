import 'package:flutter/material.dart';
import 'package:khuta/app/theme/app_tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/routing/app_navigator.dart';
import 'package:khuta/features/settings/pages/about_page.dart';

/// Appropriate Legal Notices: the upstream attribution required by
/// ADDITIONAL_TERMS.md (GPLv3 section 7(b)) and the open source licenses page.
/// Shown by every settings style so the notice is never style-dependent.
class LegalNotices extends StatelessWidget {
  const LegalNotices({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    return Column(
      children: [
        Text(
          context.l10n.legal_attribution,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: muted.withValues(alpha: 0.75),
          ),
        ),
        TextButton(
          onPressed: () => showLicensePage(context: context),
          child: Text(context.l10n.legal_licenses),
        ),
      ],
    );
  }
}

/// The only trace of the legal notices on the settings screens: a link to About.
class AboutLink extends StatelessWidget {
  const AboutLink({super.key});

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () => AppNavigator.push(const AboutPage()),
        icon: const Icon(LucideIcons.info, size: 16),
        label: Text(context.l10n.about_app),
      );
}
