import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

/// A compact, offline reference for the parts of Etonify users interact with.
///
/// The page intentionally keeps the long explanations behind ExpansionTiles:
/// opening the documentation should not build a large wall of text or a web
/// view on every device.
class SettingsDocumentationPage extends StatelessWidget {
  const SettingsDocumentationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sections = <_DocumentationSectionData>[
      _DocumentationSectionData(
        icon: Icons.info_outline_rounded,
        title: l10n.documentationWhatTitle,
        body: l10n.documentationWhatBody,
      ),
      _DocumentationSectionData(
        icon: Icons.vpn_lock_rounded,
        title: l10n.documentationModesTitle,
        body: l10n.documentationModesBody,
      ),
      _DocumentationSectionData(
        icon: Icons.hub_rounded,
        title: l10n.documentationProtocolsTitle,
        body: l10n.documentationProtocolsBody,
      ),
      _DocumentationSectionData(
        icon: Icons.account_tree_rounded,
        title: l10n.documentationChainsTitle,
        body: l10n.documentationChainsBody,
      ),
      _DocumentationSectionData(
        icon: Icons.subscriptions_rounded,
        title: l10n.documentationSubscriptionsTitle,
        body: l10n.documentationSubscriptionsBody,
      ),
      _DocumentationSectionData(
        icon: Icons.speed_rounded,
        title: l10n.documentationChecksTitle,
        body: l10n.documentationChecksBody,
      ),
      _DocumentationSectionData(
        icon: Icons.alt_route_rounded,
        title: l10n.documentationRoutingTitle,
        body: l10n.documentationRoutingBody,
      ),
      _DocumentationSectionData(
        icon: Icons.dns_rounded,
        title: l10n.documentationDnsTitle,
        body: l10n.documentationDnsBody,
      ),
      _DocumentationSectionData(
        icon: Icons.folder_special_rounded,
        title: l10n.documentationRuleFilesTitle,
        body: l10n.documentationRuleFilesBody,
      ),
      _DocumentationSectionData(
        icon: Icons.science_rounded,
        title: l10n.documentationExperimentalTitle,
        body: l10n.documentationExperimentalBody,
      ),
      _DocumentationSectionData(
        icon: Icons.monitor_heart_rounded,
        title: l10n.documentationDiagnosticsTitle,
        body: l10n.documentationDiagnosticsBody,
      ),
      _DocumentationSectionData(
        icon: Icons.warning_amber_rounded,
        title: l10n.documentationLimitsTitle,
        body: l10n.documentationLimitsBody,
      ),
      _DocumentationSectionData(
        icon: Icons.support_agent_rounded,
        title: l10n.documentationSupportTitle,
        body: l10n.documentationSupportBody,
      ),
    ];

    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.documentationPageTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          0,
          progressiveHeaderTopPadding(context, 20),
          0,
          appBottomSafePadding(context, 24),
        ),
        children: [
          Padding(
            padding: settingsScreenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DocumentationIntro(subtitle: l10n.documentationPageSubtitle),
                const Gap(12),
                for (final section in sections)
                  _DocumentationSection(data: section),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentationSectionData {
  const _DocumentationSectionData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _DocumentationIntro extends StatelessWidget {
  const _DocumentationIntro({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.menu_book_rounded, color: colors.onPrimaryContainer),
            const Gap(14),
            Expanded(
              child: Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentationSection extends StatelessWidget {
  const _DocumentationSection({required this.data});

  final _DocumentationSectionData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        leading: Icon(data.icon, color: colors.primary),
        title: Text(
          data.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              data.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
