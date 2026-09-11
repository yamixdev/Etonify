import 'dart:io';
import 'package:flutter/material.dart';
import 'package:meow_client/data/subscription/subscription_background_updates.dart';
import 'package:meow_client/data/subscription/subscription_refresh_report.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/features/subscriptions/subscription_refresh_report_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

class SubscriptionBackgroundTile extends StatefulWidget {
  const SubscriptionBackgroundTile({super.key});
  @override
  State<SubscriptionBackgroundTile> createState() => _TileState();
}

class _TileState extends State<SubscriptionBackgroundTile> {
  bool? enabled;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) return;
    SubscriptionRefreshReports.backgroundEnabled().then((value) {
      if (mounted) setState(() => enabled = value);
    });
  }

  Future<void> change(bool value) async {
    setState(() => saving = true);
    try {
      await SubscriptionRefreshReports.setBackgroundEnabled(value);
      await SubscriptionBackgroundUpdates.configure(
        await SubscriptionStore.getAllMetadataInBackground(),
      );
      if (mounted) setState(() => enabled = value);
    } catch (_) {
      await SubscriptionRefreshReports.setBackgroundEnabled(enabled ?? false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).subscriptionBackgroundSaveError,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (Platform.isAndroid) ...[
          SwitchListTile(
            secondary: SettingsLeadingIcon(
              icon: Icons.sync_rounded,
              color: cs.primary,
            ),
            title: Text(l10n.subscriptionBackgroundTitle),
            subtitle: Text(l10n.subscriptionBackgroundDescription),
            value: enabled ?? false,
            onChanged: enabled == null || saving ? null : change,
          ),
          const Divider(height: 1, indent: 74, endIndent: 16),
        ],
        ListTile(
          leading: SettingsLeadingIcon(
            icon: Icons.history_rounded,
            color: cs.primary,
          ),
          title: Text(l10n.subscriptionReportTitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SubscriptionRefreshReportPage(),
            ),
          ),
        ),
      ],
    );
  }
}
