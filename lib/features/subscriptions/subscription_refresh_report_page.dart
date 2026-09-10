import 'package:flutter/material.dart';
import 'package:meow_client/data/subscription/subscription_refresh_report.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';
import 'subscription_error_message.dart';

class SubscriptionRefreshReportPage extends StatefulWidget {
  const SubscriptionRefreshReportPage({super.key, this.entries});

  @visibleForTesting
  final List<SubscriptionRefreshEntry>? entries;
  @override
  State<SubscriptionRefreshReportPage> createState() => _ReportState();
}

class _ReportState extends State<SubscriptionRefreshReportPage> {
  late final Future<List<SubscriptionRefreshEntry>> _entries =
      widget.entries == null
      ? SubscriptionRefreshReports.latest()
      : Future.value(widget.entries);
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.subscriptionReportTitle)),
      body: FutureBuilder<List<SubscriptionRefreshEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n.subscriptionErrorUnknown));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return Center(child: Text(l10n.subscriptionReportEmpty));
          }
          return ListView.builder(
            padding: EdgeInsets.only(
              top: progressiveHeaderTopPadding(context, 12),
              bottom: appBottomSafePadding(context, 24),
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final e = entries[index];
              final date = DateTime.fromMillisecondsSinceEpoch(e.time);
              final local = MaterialLocalizations.of(context);
              return ListTile(
                leading: Icon(
                  e.succeeded
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: e.succeeded
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
                title: Text(e.name),
                subtitle: Text(
                  [
                    e.succeeded
                        ? l10n.subscriptionReportSuccess
                        : subscriptionErrorMessage(e.failure!, l10n),
                    '${local.formatShortDate(date)} ${local.formatTimeOfDay(TimeOfDay.fromDateTime(date))}',
                    if (e.background) l10n.subscriptionReportBackground,
                  ].join('\n'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
