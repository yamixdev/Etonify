part of 'subscriptions_page.dart';

class _SubscriptionDetailsPage extends StatefulWidget {
  const _SubscriptionDetailsPage({
    required this.subscriptionId,
    required this.onRefresh,
    required this.onDelete,
    required this.onMoveUp,
    required this.hapticEnabled,
  });

  final String subscriptionId;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onDelete;
  final Future<void> Function()? onMoveUp;
  final bool hapticEnabled;

  @override
  State<_SubscriptionDetailsPage> createState() =>
      _SubscriptionDetailsPageState();
}

class _SubscriptionDetailsPageState extends State<_SubscriptionDetailsPage> {
  bool _busy = false;
  Subscription? _currentSubscription;
  late final TextEditingController _nameController;
  late final TextEditingController _customUserAgentController;
  late final TextEditingController _customHwidController;
  late final TextEditingController _customHeadersController;
  late bool _sendHwid;
  late bool _useCustomHwid;

  void _haptic() {
    if (widget.hapticEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  void initState() {
    super.initState();
    _currentSubscription = SubscriptionStore.get(widget.subscriptionId);
    final initialSubscription = _subscription;
    final initialInfo = initialSubscription?.info;
    _nameController = TextEditingController(
      text: initialSubscription?.name ?? '',
    );
    _customUserAgentController = TextEditingController(
      text: initialInfo?.customUserAgent ?? '',
    );
    _customHwidController = TextEditingController(
      text: initialInfo?.customHwid ?? '',
    );
    _customHeadersController = TextEditingController(
      text: initialInfo?.customRequestHeader ?? '',
    );
    _sendHwid = initialInfo?.requireHwid ?? false;
    _useCustomHwid = (initialInfo?.customHwid?.trim().isNotEmpty ?? false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customUserAgentController.dispose();
    _customHwidController.dispose();
    _customHeadersController.dispose();
    super.dispose();
  }

  Subscription? get _subscription {
    return _currentSubscription;
  }

  void _reloadCurrentSubscription() {
    _currentSubscription = SubscriptionStore.get(widget.subscriptionId);
  }

  bool _hasPendingName(Subscription subscription) {
    final trimmed = _nameController.text.trim();
    return trimmed.isNotEmpty && trimmed != subscription.name;
  }

  Future<void> _saveNameSilently(Subscription subscription) async {
    final trimmed = _nameController.text.trim();
    final nextName = trimmed.isEmpty ? subscription.name : trimmed;
    if (nextName == subscription.name) {
      return;
    }
    await SubscriptionStore.save(subscription.copyWith(name: nextName));
    _reloadCurrentSubscription();
  }

  Future<void> _saveName(Subscription subscription) async {
    final trimmed = _nameController.text.trim();
    final nextName = trimmed.isEmpty ? subscription.name : trimmed;
    if (nextName == subscription.name) {
      return;
    }
    setState(() => _busy = true);
    try {
      await SubscriptionStore.save(subscription.copyWith(name: nextName));
      _reloadCurrentSubscription();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveAutoUpdate(
    Subscription subscription, {
    required bool disabled,
  }) async {
    if (subscription.disableAutoUpdate == disabled) {
      return;
    }
    setState(() => _busy = true);
    try {
      await SubscriptionStore.save(
        subscription.copyWith(disableAutoUpdate: disabled),
      );
      _reloadCurrentSubscription();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveAutoRefreshInterval(
    Subscription subscription,
    int minutes,
  ) async {
    final disabled = minutes <= 0;
    if (subscription.disableAutoUpdate == disabled &&
        (disabled || subscription.autoRefreshMinutes == minutes)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await SubscriptionStore.save(
        subscription.copyWith(
          disableAutoUpdate: disabled,
          autoRefreshMinutes: disabled
              ? subscription.autoRefreshMinutes
              : minutes,
        ),
      );
      _reloadCurrentSubscription();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveMarkAllServersRussia(
    Subscription subscription, {
    required bool enabled,
  }) async {
    if (subscription.markAllServersRussia == enabled) {
      return;
    }
    setState(() => _busy = true);
    try {
      await SubscriptionStore.save(
        subscription.copyWith(markAllServersRussia: enabled),
      );
      _reloadCurrentSubscription();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveRequestSettings(Subscription subscription) async {
    final baseInfo = subscription.info ?? const SubscriptionInfo();
    final customHwid = _useCustomHwid ? _customHwidController.text.trim() : '';
    final customUserAgent = _customUserAgentController.text.trim();
    final customHeaders = _customHeadersController.text.trim();
    setState(() => _busy = true);
    try {
      await SubscriptionStore.save(
        subscription.copyWith(
          info: SubscriptionInfo(
            title: baseInfo.title,
            upload: baseInfo.upload,
            download: baseInfo.download,
            total: baseInfo.total,
            expire: baseInfo.expire,
            happCryptoLink: baseInfo.happCryptoLink,
            supportUrl: baseInfo.supportUrl,
            webPageUrl: baseInfo.webPageUrl,
            newUrl: baseInfo.newUrl,
            ignoreSubscriptionMoved: baseInfo.ignoreSubscriptionMoved,
            updateIntervalHours: baseInfo.updateIntervalHours,
            perAppProxyMode: baseInfo.perAppProxyMode,
            perAppProxyList: baseInfo.perAppProxyList,
            customUserAgent: customUserAgent.isEmpty ? null : customUserAgent,
            customRequestHeader: customHeaders.isEmpty ? null : customHeaders,
            requireHwid: _sendHwid,
            customHwid: customHwid.isEmpty ? null : customHwid,
          ),
        ),
      );
      _reloadCurrentSubscription();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _applyMigratedUrl(Subscription subscription) async {
    final newUrl = subscription.info?.newUrl;
    if (newUrl == null || newUrl.isEmpty || newUrl == subscription.url) {
      return;
    }
    setState(() => _busy = true);
    try {
      await SubscriptionStore.save(
        subscription.copyWith(
          url: newUrl,
          info: subscription.info?.copyWith(
            newUrl: null,
            ignoreSubscriptionMoved: false,
          ),
        ),
      );
      _reloadCurrentSubscription();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  ({String? url, String? error}) _validateEditedSubscriptionUrl(
    String input,
    AppLocalizations l10n,
  ) {
    final urls = input
        .split(RegExp(r'[\r\n]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (urls.isEmpty) {
      return (url: null, error: l10n.invalidUrl);
    }
    if (urls.length > 1) {
      return (url: null, error: l10n.subscriptionUrlSingleSourceRequired);
    }

    try {
      final uri = SubscriptionFetcher.parseRequestUri(urls.single);
      final scheme = uri.scheme.toLowerCase();
      if ((scheme != 'http' && scheme != 'https') || uri.host.isEmpty) {
        return (url: null, error: l10n.invalidUrl);
      }
      return (url: uri.toString(), error: null);
    } on FormatException {
      return (url: null, error: l10n.invalidUrl);
    }
  }

  Future<void> _editSubscriptionUrl(Subscription subscription) async {
    final l10n = AppLocalizations.of(context);
    final editedUrl = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _SubscriptionUrlEditDialog(
        initialValue: subscription.url,
        validate: (input) => _validateEditedSubscriptionUrl(input, l10n),
      ),
    );

    if (!mounted || editedUrl == null || editedUrl == subscription.url) {
      return;
    }
    setState(() => _busy = true);
    try {
      await SubscriptionStore.saveMetadata(
        subscription.copyWith(
          url: editedUrl,
          lastUpdated: 0,
          info: subscription.info?.copyWith(ignoreSubscriptionMoved: false),
        ),
      );
      _reloadCurrentSubscription();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showSubscriptionQr(
    String value, {
    required String title,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        !HappCryptoLinkDecoder.isSupportedSubscriptionUrl(trimmed)) {
      if (!mounted) return;
      AppNotice.show(
        context,
        AppLocalizations.of(context).subscriptionQrUnsupported,
        tone: AppNoticeTone.warning,
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => _SubscriptionQrPage(title: title, value: trimmed),
      ),
    );
  }

  String _qrShareValue(Subscription subscription) {
    final happCryptoLink = subscription.info?.happCryptoLink?.trim() ?? '';
    if (happCryptoLink.isEmpty) {
      return subscription.url;
    }
    if (happCryptoLink.toLowerCase().startsWith('happ://crypt5/')) {
      return subscription.url;
    }
    return happCryptoLink;
  }

  Future<void> _reparseSubscription(Subscription subscription) async {
    setState(() => _busy = true);
    try {
      await SubscriptionStore.reparseFromRaw(subscription.id);
      _reloadCurrentSubscription();
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppNotice.show(context, error.toString(), tone: AppNoticeTone.error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _formatRefreshInterval(BuildContext context, int minutes) {
    final l10n = AppLocalizations.of(context);
    if (minutes <= 0) {
      return l10n.disabledLabel;
    }
    if (minutes % (60 * 24) == 0) {
      return l10n.refreshIntervalDaysShort(minutes ~/ (60 * 24));
    }
    if (minutes % 60 == 0) {
      return l10n.refreshIntervalHoursShort(minutes ~/ 60);
    }
    return l10n.refreshIntervalMinutesShort(minutes);
  }

  String _summarizeHappCryptoLink(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 32) {
      return trimmed;
    }
    return '${trimmed.substring(0, 32)}...';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final subscription = _subscription;
    if (subscription == null) {
      return const SizedBox.shrink();
    }
    final isLocalFileImport = SubscriptionStore.isLocalFileImportUrl(
      subscription.url,
    );
    final localFileImportName = SubscriptionStore.localFileImportDisplayName(
      subscription.url,
    );

    Future<void> refresh() async {
      setState(() => _busy = true);
      try {
        await widget.onRefresh();
        _reloadCurrentSubscription();
      } finally {
        if (mounted) {
          setState(() => _busy = false);
        }
      }
    }

    Future<void> delete() async {
      final navigator = Navigator.of(context);
      var popped = false;
      setState(() => _busy = true);
      try {
        await widget.onDelete();
        if (mounted) {
          navigator.pop();
          popped = true;
        }
      } finally {
        if (mounted && !popped) {
          setState(() => _busy = false);
        }
      }
    }

    final info = subscription.info;
    final expireSeconds = info?.expire;
    final hasUnlimitedExpire =
        info != null && (expireSeconds == null || expireSeconds <= 0);
    final supportUrl = info?.supportUrl;
    final webPageUrl = info?.webPageUrl;
    final happCryptoLink = info?.happCryptoLink;
    final migratedUrl = info?.newUrl;
    final movedIgnored = info?.ignoreSubscriptionMoved == true;
    final userVisibleOutbounds = subscription.outbounds
        .where((outbound) => outbound.config['_group_only'] != true)
        .toList(growable: false);
    final visibleOutbounds = userVisibleOutbounds
        .take(_kSubscriptionProxyPreviewLimit)
        .toList(growable: false);
    final hiddenOutboundsCount =
        userVisibleOutbounds.length - visibleOutbounds.length;
    final usageText = switch ((info?.consumed, info?.total)) {
      (final consumed?, final total?) when total > 0 => l10n.trafficUsage(
        formatBytes(consumed.toDouble()),
        formatBytes(total.toDouble()),
      ),
      (final consumed?, _) => l10n.trafficUsage(
        formatBytes(consumed.toDouble()),
        l10n.unlimitedSymbol,
      ),
      (_, _) when info != null => l10n.trafficUsage(
        '0 B',
        l10n.unlimitedSymbol,
      ),
      _ => null,
    };
    final untilText = switch (expireSeconds) {
      final seconds? when seconds > 0 => MaterialLocalizations.of(
        context,
      ).formatCompactDate(DateTime.fromMillisecondsSinceEpoch(seconds * 1000)),
      _ => null,
    };
    final untilLabel = untilText != null
        ? l10n.untilDate(untilText)
        : hasUnlimitedExpire
        ? l10n.daysLeftUnlimited
        : null;

    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop || _busy || !_hasPendingName(subscription)) {
          return;
        }
        unawaited(_saveNameSilently(subscription));
      },
      child: ProgressiveBlurScaffold(
        appBar: AppBar(
          title: Text(l10n.subscriptionDetailsTitle),
          flexibleSpace: _busy
              ? Align(
                  alignment: Alignment.bottomCenter,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                  ),
                )
              : null,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  12,
                  progressiveHeaderTopPadding(context, 8),
                  12,
                  appBottomSafePadding(context, 24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (widget.onMoveUp != null)
                            FilledButton.tonal(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      _haptic();
                                      await widget.onMoveUp!();
                                    },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Icon(
                                Icons.arrow_upward_rounded,
                                size: 18,
                              ),
                            ),
                          if (!isLocalFileImport)
                            FilledButton.tonal(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      _haptic();
                                      refresh();
                                    },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text(l10n.refresh),
                            ),
                          if (!isLocalFileImport)
                            FilledButton.tonal(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      _haptic();
                                      await _reparseSubscription(subscription);
                                    },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text(l10n.reparseProxies),
                            ),
                          FilledButton.tonal(
                            onPressed: _busy
                                ? null
                                : () {
                                    _haptic();
                                    delete();
                                  },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(l10n.delete),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Stack(
                            alignment: Alignment.centerRight,
                            children: [
                              TextField(
                                controller: _nameController,
                                onTapOutside: (_) async {
                                  FocusScope.of(context).unfocus();
                                  if (_hasPendingName(subscription)) {
                                    await _saveName(subscription);
                                  }
                                },
                                onSubmitted: (_) => _saveName(subscription),
                                onEditingComplete: () async {
                                  FocusScope.of(context).unfocus();
                                  await _saveName(subscription);
                                },
                                textInputAction: TextInputAction.done,
                                inputFormatters: [_kSingleLineFormatter],
                                minLines: 1,
                                maxLines: 3,
                                keyboardType: TextInputType.text,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: InputDecoration(
                                  hintText: l10n.subscriptionName,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  isDense: true,
                                  filled: true,
                                  fillColor: theme.scaffoldBackgroundColor,
                                  contentPadding: const EdgeInsets.only(
                                    right: 16,
                                  ),
                                ),
                              ),
                              IgnorePointer(
                                child: Opacity(
                                  opacity: 0.38,
                                  child: Text(
                                    '|',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _DetailsBlock(
                      title: isLocalFileImport ? l10n.sourceLabel : 'URL',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isLocalFileImport) ...[
                            IconButton(
                              key: const ValueKey(
                                'edit_subscription_url_button',
                              ),
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      _haptic();
                                      await _editSubscriptionUrl(subscription);
                                    },
                              tooltip: l10n.editSubscriptionUrlAction,
                              icon: const Icon(Icons.edit_rounded),
                            ),
                            FilledButton.tonal(
                              onPressed: () async {
                                _haptic();
                                await _showSubscriptionQr(
                                  _qrShareValue(subscription),
                                  title: subscription.name,
                                );
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                l10n.showQrCode,
                                style: theme.textTheme.labelMedium,
                              ),
                            ),
                            const Gap(4),
                            FilledButton.tonal(
                              onPressed: () async {
                                _haptic();
                                await SensitiveClipboard.copy(subscription.url);
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                MaterialLocalizations.of(
                                  context,
                                ).copyButtonLabel,
                                style: theme.textTheme.labelMedium,
                              ),
                            ),
                          ],
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isLocalFileImport)
                            Text(
                              l10n.importedFromFileLabel(
                                localFileImportName ?? subscription.name,
                              ),
                              style: theme.textTheme.bodyMedium,
                            )
                          else
                            SelectableText(
                              subscription.url,
                              style: theme.textTheme.bodyMedium,
                            ),
                          if (happCryptoLink != null &&
                              happCryptoLink.isNotEmpty) ...[
                            Divider(
                              height: 24,
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: .45),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.happCryptoLinkImportedLabel,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                      const Gap(4),
                                      Text(
                                        _summarizeHappCryptoLink(
                                          happCryptoLink,
                                        ),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Gap(12),
                                FilledButton.tonal(
                                  onPressed: () async {
                                    _haptic();
                                    await SensitiveClipboard.copy(
                                      happCryptoLink,
                                    );
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    MaterialLocalizations.of(
                                      context,
                                    ).copyButtonLabel,
                                    style: theme.textTheme.labelMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (movedIgnored &&
                        migratedUrl != null &&
                        migratedUrl.isNotEmpty &&
                        migratedUrl != subscription.url)
                      _DetailsBlock(
                        title: l10n.newUrlTitle,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.movedSubscriptionPrompt,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const Gap(6),
                            Text(
                              migratedUrl,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Gap(10),
                            FilledButton.tonal(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      _haptic();
                                      await _applyMigratedUrl(subscription);
                                    },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text(l10n.updateUrlAction),
                            ),
                          ],
                        ),
                      ),
                    if (!isLocalFileImport)
                      _DetailsBlock(
                        title: l10n.autoUpdateTitle,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l10n.disableAutoUpdateTitle,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                Switch.adaptive(
                                  value: subscription.disableAutoUpdate,
                                  onChanged: _busy
                                      ? null
                                      : (value) async {
                                          _haptic();
                                          await _saveAutoUpdate(
                                            subscription,
                                            disabled: value,
                                          );
                                        },
                                ),
                              ],
                            ),
                            if (subscription.lastUpdated > 0) ...[
                              const Gap(6),
                              Text(
                                _subscriptionLastUpdatedText(
                                  context,
                                  subscription.lastUpdated,
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const Gap(6),
                            Text(
                              subscription.disableAutoUpdate
                                  ? l10n.refreshesEvery(l10n.disabledLabel)
                                  : l10n.refreshesEvery(
                                      _formatRefreshInterval(
                                        context,
                                        subscription.autoRefreshMinutes,
                                      ),
                                    ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Gap(10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final minutes in _kAutoRefreshOptions)
                                  ChoiceChip(
                                    label: Text(
                                      minutes <= 0
                                          ? l10n.disabledLabel
                                          : _formatRefreshInterval(
                                              context,
                                              minutes,
                                            ),
                                    ),
                                    selected: minutes <= 0
                                        ? subscription.disableAutoUpdate
                                        : !subscription.disableAutoUpdate &&
                                              subscription.autoRefreshMinutes ==
                                                  minutes,
                                    onSelected: _busy
                                        ? null
                                        : (_) async {
                                            _haptic();
                                            await _saveAutoRefreshInterval(
                                              subscription,
                                              minutes,
                                            );
                                          },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    _DetailsBlock(
                      title: 'Локация',
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Пометить все сервера как Россию'),
                        subtitle: const Text(
                          'Только для этой подписки: список прокси, lowest/open/free и mixed будут считать все outbound российскими.',
                        ),
                        secondary: const Icon(Icons.flag_rounded),
                        value: subscription.markAllServersRussia,
                        onChanged: _busy
                            ? null
                            : (value) async {
                                _haptic();
                                await _saveMarkAllServersRussia(
                                  subscription,
                                  enabled: value,
                                );
                              },
                      ),
                    ),
                    if (!isLocalFileImport)
                      _DetailsBlock(
                        title: l10n.serverRequestTitle,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(l10n.sendHwidTitle),
                              subtitle: Text(l10n.sendHwidSubtitle),
                              value: _sendHwid,
                              onChanged: _busy
                                  ? null
                                  : (value) async {
                                      _haptic();
                                      setState(() {
                                        _sendHwid = value;
                                        if (!value) {
                                          _useCustomHwid = false;
                                        }
                                      });
                                      await _saveRequestSettings(subscription);
                                    },
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(l10n.useCustomHwidTitle),
                              subtitle: Text(l10n.useCustomHwidSubtitle),
                              value: _sendHwid && _useCustomHwid,
                              onChanged: !_sendHwid || _busy
                                  ? null
                                  : (value) async {
                                      _haptic();
                                      setState(() => _useCustomHwid = value);
                                      await _saveRequestSettings(subscription);
                                    },
                            ),
                            const Gap(6),
                            if (_sendHwid && _useCustomHwid) ...[
                              TextField(
                                controller: _customHwidController,
                                onTapOutside: (_) async {
                                  FocusScope.of(context).unfocus();
                                  await _saveRequestSettings(subscription);
                                },
                                onSubmitted: (_) =>
                                    _saveRequestSettings(subscription),
                                onEditingComplete: () async {
                                  FocusScope.of(context).unfocus();
                                  await _saveRequestSettings(subscription);
                                },
                                inputFormatters: [_kSingleLineFormatter],
                                decoration: InputDecoration(
                                  labelText: l10n.customHwidTitle,
                                  helperText: l10n.customHwidSubtitle,
                                ),
                              ),
                              const Gap(6),
                            ],
                            TextField(
                              controller: _customUserAgentController,
                              onTapOutside: (_) async {
                                FocusScope.of(context).unfocus();
                                await _saveRequestSettings(subscription);
                              },
                              onSubmitted: (_) =>
                                  _saveRequestSettings(subscription),
                              onEditingComplete: () async {
                                FocusScope.of(context).unfocus();
                                await _saveRequestSettings(subscription);
                              },
                              inputFormatters: [_kSingleLineFormatter],
                              decoration: InputDecoration(
                                labelText: l10n.customUserAgentTitle,
                                helperText: l10n.customUserAgentSubtitle,
                                helperMaxLines: 3,
                                hintText: SubscriptionFetcher.defaultUserAgent,
                              ),
                            ),
                            const Gap(12),
                            TextField(
                              controller: _customHeadersController,
                              minLines: 3,
                              maxLines: 8,
                              onTapOutside: (_) async {
                                FocusScope.of(context).unfocus();
                                await _saveRequestSettings(subscription);
                              },
                              onSubmitted: (_) =>
                                  _saveRequestSettings(subscription),
                              onEditingComplete: () async {
                                FocusScope.of(context).unfocus();
                                await _saveRequestSettings(subscription);
                              },
                              decoration: InputDecoration(
                                labelText: l10n.customRequestHeadersTitle,
                                helperText: l10n.customRequestHeadersSubtitle,
                                helperMaxLines: 3,
                                hintText:
                                    'Authorization: Bearer ...\nX-Token: ...',
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (usageText != null || untilLabel != null)
                      _DetailsBlock(
                        title: l10n.usageTitle,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (usageText != null)
                              Text(
                                l10n.spentTraffic(usageText),
                                style: theme.textTheme.bodyMedium,
                              ),
                            if (untilLabel != null) ...[
                              if (usageText != null) const Gap(6),
                              Text(
                                untilLabel,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (supportUrl != null || webPageUrl != null)
                      _DetailsBlock(
                        title: l10n.infoTitle,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (supportUrl != null) ...[
                              Text(
                                l10n.supportUrlLabel,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const Gap(4),
                              _LinkText(
                                label: supportUrl,
                                onTap: () => _openUrl(supportUrl),
                              ),
                            ],
                            if (webPageUrl != null) ...[
                              if (supportUrl != null) const Gap(12),
                              Text(
                                l10n.websiteLabel,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const Gap(4),
                              _LinkText(
                                label: webPageUrl,
                                onTap: () => _openUrl(webPageUrl),
                              ),
                            ],
                          ],
                        ),
                      ),
                    _DetailsBlock(
                      title: l10n.proxiesTitle,
                      trailing: _CountBadge(
                        label: l10n.outboundsCount(userVisibleOutbounds.length),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < visibleOutbounds.length; i++) ...[
                            _OutboundRow(outbound: visibleOutbounds[i]),
                            if (i != visibleOutbounds.length - 1 ||
                                hiddenOutboundsCount > 0)
                              Divider(
                                height: 20,
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: .45),
                              ),
                          ],
                          if (hiddenOutboundsCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                l10n.moreProxies(hiddenOutboundsCount),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
