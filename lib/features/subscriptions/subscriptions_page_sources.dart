part of 'subscriptions_page.dart';

class SubscriptionSourcesPage extends StatefulWidget {
  const SubscriptionSourcesPage({
    super.key,
    required this.subscriptionId,
    this.hapticEnabled = true,
    this.allowUntrustedSubscriptionCertificates = false,
  });

  final String subscriptionId;
  final bool hapticEnabled;
  final bool allowUntrustedSubscriptionCertificates;

  @override
  State<SubscriptionSourcesPage> createState() =>
      _SubscriptionSourcesPageState();
}

class _SubscriptionSourcesPageState extends State<SubscriptionSourcesPage> {
  bool _busy = false;

  Future<void> _run(Future<Subscription> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        AppNotice.show(
          context,
          subscriptionErrorMessage(error, AppLocalizations.of(context)),
          tone: AppNoticeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubscriptionsPage(
        openAddOnStart: true,
        targetProfileId: widget.subscriptionId,
        hapticEnabled: widget.hapticEnabled,
        allowUntrustedSubscriptionCertificates:
            widget.allowUntrustedSubscriptionCertificates,
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _remove(SubscriptionSource source) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sourceRemoveTitle),
        content: Text(l10n.sourceRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(
        () => SubscriptionStore.removeSource(widget.subscriptionId, source.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = SubscriptionStore.getMetadata(widget.subscriptionId);
    final sources = profile?.effectiveSources ?? const <SubscriptionSource>[];
    final enabledCount = sources.where((source) => source.enabled).length;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profileSources),
          actions: [
            IconButton(
              tooltip: l10n.addProfileSource,
              onPressed: _busy ? null : _add,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
          bottom: _busy
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: AppLinearProgressIndicator(minHeight: 2),
                )
              : null,
        ),
        body: ListView.builder(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            appBottomSafePadding(context, 24),
          ),
          itemCount: sources.length,
          itemBuilder: (context, index) {
            final source = sources[index];
            final local =
                source.url.isEmpty ||
                SubscriptionStore.isLocalFileImportUrl(source.url);
            final canRemove =
                sources.length > 1 && (!source.enabled || enabledCount > 1);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    key: ValueKey('source-toggle-${source.id}'),
                    title: Text(source.name),
                    subtitle: Text(
                      local ? l10n.sourceLocal : source.url,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: source.enabled,
                    onChanged: _busy || (source.enabled && enabledCount == 1)
                        ? null
                        : (value) => _run(
                            () => SubscriptionStore.setSourceEnabled(
                              widget.subscriptionId,
                              source.id,
                              value,
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.lastUpdated > 0
                              ? _subscriptionLastUpdatedText(
                                  context,
                                  source.lastUpdated,
                                )
                              : l10n.sourceNeverUpdated,
                        ),
                        if (source.lastAttempt > 0)
                          Text(
                            '${l10n.sourceLastAttempt}: ${DateFormat.yMd(locale).add_Hms().format(DateTime.fromMillisecondsSinceEpoch(source.lastAttempt))}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (source.lastError != null)
                          Text(
                            '${subscriptionSourceErrorMessage(source.lastError!, l10n)}\n${l10n.sourceUpdateFailed}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        if (source.enabled && enabledCount == 1)
                          Text(
                            l10n.sourceKeepOneEnabled,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!local)
                        IconButton(
                          key: ValueKey('source-refresh-${source.id}'),
                          tooltip: l10n.refresh,
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () => SubscriptionStore.refreshSource(
                                    widget.subscriptionId,
                                    source.id,
                                    allowInsecureTls: widget
                                        .allowUntrustedSubscriptionCertificates,
                                  ),
                                ),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      IconButton(
                        key: ValueKey('source-remove-${source.id}'),
                        tooltip: l10n.delete,
                        onPressed: _busy || !canRemove
                            ? null
                            : () => _remove(source),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
