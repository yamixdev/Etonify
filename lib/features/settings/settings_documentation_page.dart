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
    final groups = <_DocumentationGroupData>[
      _DocumentationGroupData(
        title: l10n.documentationGroupGettingStarted,
        sections: [
          _DocumentationSectionData(
            icon: Icons.rocket_launch_rounded,
            title: l10n.documentationQuickStartTitle,
            body: l10n.documentationQuickStartBody,
          ),
          _DocumentationSectionData(
            icon: Icons.info_outline_rounded,
            title: l10n.documentationWhatTitle,
            body: l10n.documentationWhatBody,
          ),
          _DocumentationSectionData(
            icon: Icons.subscriptions_rounded,
            title: l10n.documentationSubscriptionsTitle,
            body: l10n.documentationSubscriptionsBody,
          ),
          _DocumentationSectionData(
            icon: Icons.hub_rounded,
            title: l10n.documentationProtocolsTitle,
            body: l10n.documentationProtocolsBody,
          ),
        ],
      ),
      _DocumentationGroupData(
        title: l10n.documentationGroupConnection,
        sections: [
          _DocumentationSectionData(
            icon: Icons.vpn_lock_rounded,
            title: l10n.documentationModesTitle,
            body: l10n.documentationModesBody,
          ),
          _DocumentationSectionData(
            icon: Icons.speed_rounded,
            title: l10n.documentationChecksTitle,
            body: l10n.documentationChecksBody,
          ),
          _DocumentationSectionData(
            icon: Icons.notifications_active_rounded,
            title: l10n.documentationBackgroundTitle,
            body: l10n.documentationBackgroundBody,
          ),
          _DocumentationSectionData(
            icon: Icons.account_tree_rounded,
            title: l10n.documentationChainsTitle,
            body: l10n.documentationChainsBody,
          ),
        ],
      ),
      _DocumentationGroupData(
        title: l10n.documentationGroupRouting,
        sections: [
          _DocumentationSectionData(
            icon: Icons.alt_route_rounded,
            title: l10n.documentationRoutingTitle,
            body: l10n.documentationRoutingBody,
          ),
          _DocumentationSectionData(
            icon: Icons.route_rounded,
            title: l10n.documentationTrafficRulesTitle,
            body: l10n.documentationTrafficRulesBody,
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
            icon: Icons.security_rounded,
            title: l10n.documentationSecurityTitle,
            body: l10n.documentationSecurityBody,
          ),
        ],
      ),
      _DocumentationGroupData(
        title: l10n.documentationGroupMaintenance,
        sections: [
          _DocumentationSectionData(
            icon: Icons.system_update_rounded,
            title: l10n.documentationUpdatesTitle,
            body: l10n.documentationUpdatesBody,
          ),
          _DocumentationSectionData(
            icon: Icons.lock_clock_rounded,
            title: l10n.documentationBackupTitle,
            body: l10n.documentationBackupBody,
          ),
          _DocumentationSectionData(
            icon: Icons.science_rounded,
            title: l10n.documentationExperimentalTitle,
            body: l10n.documentationExperimentalBody,
          ),
        ],
      ),
      _DocumentationGroupData(
        title: l10n.documentationGroupHelp,
        sections: [
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
        ],
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
                for (final group in groups) ...[
                  const Gap(20),
                  _DocumentationGroupTitle(title: group.title),
                  const Gap(8),
                  for (final section in group.sections)
                    _DocumentationSection(data: section),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentationGroupData {
  const _DocumentationGroupData({required this.title, required this.sections});

  final String title;
  final List<_DocumentationSectionData> sections;
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

class _DocumentationGroupTitle extends StatelessWidget {
  const _DocumentationGroupTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
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
        key: PageStorageKey<String>(data.title),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
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
