import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:khuta/core/i18n/l10n.dart';
import 'package:khuta/core/routing/app_navigator.dart';
import 'package:khuta/features/settings/pages/about_page.dart';

/// Appropriate Legal Notices: the open source licenses page. The upstream
/// author waived the display of the attribution notice in writing.
/// Shown by every settings style so the notice is never style-dependent.
class LegalNotices extends StatelessWidget {
  const LegalNotices({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
