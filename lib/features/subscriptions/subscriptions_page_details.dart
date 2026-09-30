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
  Subscription? _hydratedSubscription;
  List<Outbound> _visibleOutbounds = const [];
  Future<Subscription?>? _payloadFuture;
  Timer? _payloadStartTimer;
  bool _payloadLoading = true;
  bool _payloadFailed = false;
  bool _advancedExpanded = false;
  bool _sharing = false;

  Future<Subscription?> _readCurrentPayload() {
    return SubscriptionStore.loadProfileSnapshotInBackground(
      widget.subscriptionId,
      cachedPayload: _hydratedSubscription,
    );
  }

  Future<Subscription?> _loadPayload() {
    final pending = _payloadFuture;
    if (pending != null) return pending;
    _payloadStartTimer?.cancel();
    final future = _hydratePayload();
    _payloadFuture = future;
    return future;
  }

  Future<Subscription?> _hydratePayload() async {
    try {
      Subscription? full;
      Subscription? latest;
      for (var attempt = 0; attempt < 3; attempt++) {
        full = await _readCurrentPayload();
        if (!mounted) return null;
        latest = SubscriptionStore.getMetadata(widget.subscriptionId);
        if (full == null || latest == null) {
          full = null;
          break;
        }
        if (full.payloadRevision == latest.payloadRevision) {
          full = latest.copyWith(
            rawContent: full.rawContent,
            outbounds: full.outbounds,
            groups: full.groups,
          );
          break;
        }
        _hydratedSubscription = null;
        if (attempt == 2) throw StateError('Profile changed during loading');
      }
      setState(() {
        _currentSubscription = latest;
        if (!identical(full?.outbounds, _hydratedSubscription?.outbounds)) {
          _visibleOutbounds = full == null
              ? const []
              : [
                  for (final outbound in full.outbounds)
                    if (!outbound.info.deleted &&
                        outbound.config['_group_only'] != true &&
                        isSupportedOutboundConfig(outbound.config))
                      outbound,
                ];
        }
        _hydratedSubscription = full;
        _payloadLoading = false;
        _payloadFailed = false;
      });
      return full;
    } catch (error) {
      AppLogStore.warning(
        'subscription',
        'Profile details could not load: ${error.runtimeType}',
      );
      if (mounted) {
        setState(() {
          _payloadLoading = false;
          _payloadFailed = true;
        });
      }
      return null;
    } finally {
      _payloadFuture = null;
    }
  }

  Future<void> _shareOutbound(String tag) async {
    if (_sharing || _busy) return;
    _sharing = true;
    _haptic();
    try {
      final full = await _loadPayload();
      if (!mounted || full == null) return;
      final matching = full.outbounds.where(
        (outbound) => outbound.tag == tag && !outbound.info.deleted,
      );
      if (matching.isEmpty) {
        AppNotice.show(
          context,
          AppLocalizations.of(context).subscriptionServersChanged,
        );
        return;
      }
      final outbound = matching.first;
      final summary = AppProxySummary(
        tag: outbound.tag,
        displayName: outbound.name,
        countryCode: outboundDisplayCountryCode(
          outbound,
          markAllServersRussia: false,
        ),
        type: outbound.type,
        server: outbound.server,
        port: outbound.port,
        detailText: '',
        ip: outbound.server,
        latency: null,
        latencyFresh: false,
        latencyChecking: false,
        latencyUnavailable: false,
        latencyError: null,
        protocolLabel: outbound.type.toUpperCase(),
        endpointLabel: _endpointWithPath(outbound),
      );
      Map<String, dynamic>? groupConfig;
      if (outbound.type == 'selector' || outbound.type == 'urltest') {
        final byTag = {for (final node in full.outbounds) node.tag: node};
        final included = <String>{};
        final configs = <Map<String, dynamic>>[];
        void include(Outbound node) {
          if (!included.add(node.tag)) return;
          final config = Map<String, dynamic>.from(node.config)
            ..removeWhere((key, _) => key.startsWith('_'));
          config['tag'] = node.tag;
          configs.add(config);
          final children = config['outbounds'];
          if (children is List) {
            for (final child in children) {
              final member = byTag[child];
              if (member != null) include(member);
            }
          }
        }

        include(outbound);
        groupConfig = {'outbounds': configs};
      }
      await showProxyShareSheet(
        context,
        proxy: summary,
        outbound: outbound,
        singboxConfig: groupConfig,
      );
    } finally {
      _sharing = false;
    }
  }

  Future<void> _exportProfile() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.backupPlainWarningTitle),
          content: Text(l10n.backupPlainWarningMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.continueAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final full = await _loadPayload();
      if (!mounted || full == null) return;
      final bytes = await const EtonifyBackupService()
          .buildProfileExportBytesInBackground(
            subscriptions: [full],
            clientVersion: SubscriptionFetcher.currentAppVersion,
            encryption: EtonifyProfileEncryption.plain,
          );
      if (!mounted) return;
      final filename = full.name.replaceAll(
        RegExp(r'[^\p{L}\p{N}._-]+', unicode: true),
        '-',
      );
      final result = await FilePicker.saveFile(
        dialogTitle: AppLocalizations.of(context).subscriptionExportJson,
        fileName:
            '${filename.isEmpty ? 'etonify-profile' : filename}.etonify-profile.json',
        bytes: bytes,
        mimeType: 'application/json',
      );
      if (result != null && mounted) {
        AppNotice.show(
          context,
          AppLocalizations.of(context).backupSaved,
          tone: AppNoticeTone.success,
        );
      }
    } catch (error) {
      AppLogStore.warning(
        'subscription',
        'Profile export failed: ${error.runtimeType}',
      );
      if (mounted) {
        AppNotice.show(
          context,
          AppLocalizations.of(context).subscriptionExportFailed,
          tone: AppNoticeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseRefreshInterval(Subscription subscription) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in _kAutoRefreshOptions.where(
              (value) => value > 0,
            ))
              ListTile(
                title: Text(_formatRefreshInterval(sheetContext, value)),
                trailing: subscription.autoRefreshMinutes == value
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(sheetContext, value),
              ),
          ],
        ),
      ),
    );
    if (!mounted || minutes == null) return;
    await _saveAutoRefreshInterval(_subscription ?? subscription, minutes);
  }

  Subscription? _currentSubscription;
  late final TextEditingController _nameController;
  late final TextEditingController _customUserAgentController;
  late final TextEditingController _customHwidController;
  late final TextEditingController _customHeadersController;
  late bool _sendHwid;
  late bool _useCustomHwid;
  late SubscriptionInfo _requestSettingsBaseline;

  void _haptic() {
    if (widget.hapticEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  void initState() {
    super.initState();
    _currentSubscription = SubscriptionStore.getMetadata(widget.subscriptionId);
    final initialSubscription = _subscription;
    final initialInfo = initialSubscription?.info;
    _requestSettingsBaseline = initialInfo ?? const SubscriptionInfo();
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
    // Keep the route transition free of payload decoding and flag preparation.
    _payloadStartTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) unawaited(_loadPayload());
    });
  }

  @override
  void dispose() {
    _payloadStartTimer?.cancel();
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
    _currentSubscription = SubscriptionStore.getMetadata(widget.subscriptionId);
    if (mounted &&
        _currentSubscription?.payloadRevision !=
            _hydratedSubscription?.payloadRevision) {
      _hydratedSubscription = null;
      _visibleOutbounds = const [];
      _payloadLoading = true;
      unawaited(_loadPayload());
    }
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
    await SubscriptionStore.updateMetadata(
      subscription.id,
      (current) => current.copyWith(name: nextName),
    );
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
      await SubscriptionStore.updateMetadata(
        subscription.id,
        (current) => current.copyWith(name: nextName),
      );
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
      await SubscriptionStore.updateMetadata(
        subscription.id,
        (current) => current.copyWith(disableAutoUpdate: disabled),
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
      await SubscriptionStore.updateMetadata(
        subscription.id,
        (current) => current.copyWith(
          disableAutoUpdate: disabled,
          autoRefreshMinutes: disabled ? current.autoRefreshMinutes : minutes,
        ),
      );
      _reloadCurrentSubscription();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveRequestSettings(Subscription subscription) async {
    if (_busy) return;
    final customHwid = _useCustomHwid ? _customHwidController.text.trim() : '';
    final customUserAgent = _customUserAgentController.text.trim();
    final customHeaders = _customHeadersController.text.trim();
    // Only fields edited in this form may overwrite the latest stored Info.
    // Toggling HWID must not restore stale headers/UA from the other controls.
    final edits = <String, dynamic>{
      if (_requestSettingsBaseline.customHwid !=
          (customHwid.isEmpty ? null : customHwid))
        'custom_hwid': customHwid.isEmpty ? null : customHwid,
      if (_requestSettingsBaseline.customUserAgent !=
          (customUserAgent.isEmpty ? null : customUserAgent))
        'custom_user_agent': customUserAgent.isEmpty ? null : customUserAgent,
      if (_requestSettingsBaseline.customRequestHeader !=
          (customHeaders.isEmpty ? null : customHeaders))
        'custom_request_header': customHeaders.isEmpty ? null : customHeaders,
      if (_requestSettingsBaseline.requireHwid != _sendHwid)
        'require_hwid': _sendHwid,
    };
    if (edits.isEmpty) return;
    setState(() => _busy = true);
    try {
      await SubscriptionStore.updateMetadata(
        subscription.id,
        (current) => current.copyWith(
          info: SubscriptionInfo.fromMap({...?current.info?.toMap(), ...edits}),
        ),
      );
      _requestSettingsBaseline = SubscriptionInfo.fromMap({
        ..._requestSettingsBaseline.toMap(),
        ...edits,
      });
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
      await SubscriptionStore.updateMetadata(
        subscription.id,
        (current) => current.info?.newUrl != newUrl
            ? current
            : current.copyWith(
                url: newUrl,
                info: SubscriptionInfo.fromMap({
                  ...?current.info?.toMap(),
                  'new_url': null,
                  'ignore_subscription_moved': false,
                }),
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
      await SubscriptionStore.updateMetadata(
        subscription.id,
        (current) => current.copyWith(
          url: editedUrl,
          lastUpdated: 0,
          info: current.info?.copyWith(ignoreSubscriptionMoved: false),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final subscription = _subscription;
    if (subscription == null) return const SizedBox.shrink();
    final local = SubscriptionStore.isLocalFileImportUrl(subscription.url);
    final info = subscription.info;
    final count = _hydratedSubscription != null
        ? _visibleOutbounds.length
        : subscription.cachedVisibleProxyCount;
    final usage = switch ((info?.consumed, info?.total)) {
      (final consumed?, final total?) when total > 0 => l10n.trafficUsage(
        formatBytes(consumed.toDouble()),
        formatBytes(total.toDouble()),
      ),
      (final consumed?, _) => l10n.trafficUsage(
        formatBytes(consumed.toDouble()),
        l10n.unlimitedSymbol,
      ),
      _ => null,
    };
    final expire = info?.expire;
    final until = expire != null && expire > 0
        ? l10n.untilDate(
            MaterialLocalizations.of(context).formatCompactDate(
              DateTime.fromMillisecondsSinceEpoch(expire * 1000),
            ),
          )
        : info != null
        ? l10n.daysLeftUnlimited
        : null;
    final movedUrl = info?.newUrl;
    Future<void> refresh() async {
      setState(() => _busy = true);
      try {
        await widget.onRefresh();
        _reloadCurrentSubscription();
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_busy && _hasPendingName(subscription)) {
          unawaited(
            _saveNameSilently(subscription).catchError((Object error) {
              AppLogStore.warning(
                'subscription',
                'Profile name save failed: ${error.runtimeType}',
              );
            }),
          );
        }
      },
      child: ProgressiveBlurScaffold(
        appBar: AppBar(
          title: Text(l10n.subscriptionDetailsTitle),
          actions: [
            PopupMenuButton<String>(
              enabled: !_busy,
              onSelected: (value) async {
                _haptic();
                if (value == 'reparse') {
                  await _reparseSubscription(subscription);
                } else if (value == 'move') {
                  await widget.onMoveUp?.call();
                } else if (value == 'delete') {
                  setState(() => _busy = true);
                  try {
                    await widget.onDelete();
                    if (mounted) Navigator.of(this.context).pop();
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                }
              },
              itemBuilder: (_) => [
                if (subscription.hasRawPayload)
                  PopupMenuItem(
                    value: 'reparse',
                    child: Text(l10n.reparseProxies),
                  ),
                if (widget.onMoveUp != null)
                  PopupMenuItem(
                    value: 'move',
                    child: Text(l10n.subscriptionMoveUp),
                  ),
                PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
              ],
            ),
          ],
          flexibleSpace: _busy
              ? const Align(
                  alignment: Alignment.bottomCenter,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                  ),
                )
              : null,
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              key: const PageStorageKey('subscription_details_scroll'),
              padding: EdgeInsets.fromLTRB(
                16,
                progressiveHeaderTopPadding(context, 12),
                16,
                appBottomSafePadding(context, 24),
              ),
              children: [
                TextField(
                  controller: _nameController,
                  enabled: !_busy,
                  inputFormatters: [noNewlineInputFormatter],
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.subscriptionName,
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (_) => _saveName(subscription),
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                    if (!_busy) unawaited(_saveName(subscription));
                  },
                ),
                if (usage != null)
                  Text(
                    l10n.spentTraffic(usage),
                    style: theme.textTheme.bodyMedium,
                  ),
                if (until != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      until,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (subscription.lastUpdated > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _subscriptionLastUpdatedText(
                        context,
                        subscription.lastUpdated,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const Gap(12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!local)
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : refresh,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(l10n.refresh),
                      ),
                    OutlinedButton.icon(
                      key: const ValueKey('subscription_export_json'),
                      onPressed: _busy ? null : _exportProfile,
                      icon: const Icon(Icons.file_upload_outlined, size: 18),
                      label: Text(l10n.subscriptionExportJson),
                    ),
                  ],
                ),
                const Gap(20),
                _DetailsBlock(
                  title: local
                      ? l10n.subscriptionLocalFile
                      : l10n.subscriptionUrl,
                  trailing: local
                      ? null
                      : IconButton(
                          key: const ValueKey('edit_subscription_url_button'),
                          tooltip: l10n.editSubscriptionUrlAction,
                          onPressed: _busy
                              ? null
                              : () => _editSubscriptionUrl(subscription),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        local
                            ? SubscriptionStore.localFileImportDisplayName(
                                    subscription.url,
                                  ) ??
                                  l10n.subscriptionLocalFile
                            : subscription.url,
                        maxLines: 3,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (!local) ...[
                        const Gap(8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            TextButton.icon(
                              onPressed: () =>
                                  SensitiveClipboard.copy(subscription.url),
                              icon: const Icon(Icons.copy_outlined, size: 18),
                              label: Text(l10n.subscriptionCopy),
                            ),
                            TextButton.icon(
                              onPressed: () => _showSubscriptionQr(
                                _qrShareValue(subscription),
                                title: subscription.name,
                              ),
                              icon: const Icon(Icons.qr_code_rounded, size: 18),
                              label: Text(l10n.showQrCode),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (movedUrl != null &&
                    movedUrl.isNotEmpty &&
                    movedUrl != subscription.url &&
                    info?.ignoreSubscriptionMoved != true)
                  _DetailsBlock(
                    title: l10n.infoTitle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.movedSubscriptionPrompt),
                        const Gap(8),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _applyMigratedUrl(subscription),
                          child: Text(l10n.updateUrlAction),
                        ),
                      ],
                    ),
                  ),
                _DetailsBlock(
                  key: const ValueKey('subscription_details_proxies'),
                  title: l10n.proxiesTitle,
                  trailing: _CountBadge(
                    label: count >= 0
                        ? l10n.outboundsCount(count)
                        : l10n.loading,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_payloadLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (_payloadFailed) ...[
                        Text(l10n.subscriptionServersLoadFailed),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _payloadLoading = true;
                              _payloadFailed = false;
                            });
                            unawaited(_loadPayload());
                          },
                          child: Text(l10n.refresh),
                        ),
                      ],
                      for (final outbound in _visibleOutbounds.take(
                        _kSubscriptionProxyPreviewLimit,
                      ))
                        _OutboundRow(
                          key: ValueKey('subscription_preview_${outbound.tag}'),
                          outbound: outbound,
                          onTap: () => _shareOutbound(outbound.tag),
                        ),
                      if (_visibleOutbounds.isNotEmpty)
                        TextButton.icon(
                          key: const ValueKey('subscription_all_servers'),
                          onPressed: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => _SubscriptionServersPage(
                                subscriptionName: subscription.name,
                                outbounds: _visibleOutbounds,
                                onShare: _shareOutbound,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.list_rounded, size: 18),
                          label: Text(l10n.subscriptionAllServers),
                        ),
                    ],
                  ),
                ),
                if (!local)
                  _DetailsBlock(
                    title: l10n.autoUpdateTitle,
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.autoUpdateTitle),
                          subtitle: Text(
                            subscription.disableAutoUpdate
                                ? l10n.disabledLabel
                                : l10n.refreshesEvery(
                                    _formatRefreshInterval(
                                      context,
                                      subscription.autoRefreshMinutes,
                                    ),
                                  ),
                          ),
                          value: !subscription.disableAutoUpdate,
                          onChanged: _busy
                              ? null
                              : (value) => _saveAutoUpdate(
                                  subscription,
                                  disabled: !value,
                                ),
                        ),
                        if (!subscription.disableAutoUpdate)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.subscriptionRefreshInterval),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: _busy
                                ? null
                                : () => _chooseRefreshInterval(subscription),
                          ),
                      ],
                    ),
                  ),
                if (!local)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      key: PageStorageKey(
                        'subscription_request_settings_${widget.subscriptionId}',
                      ),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      collapsedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(l10n.subscriptionAdvancedSettings),
                      subtitle: Text(
                        l10n.serverRequestTitle,
                        style: theme.textTheme.bodySmall,
                      ),
                      onExpansionChanged: (value) =>
                          setState(() => _advancedExpanded = value),
                      children: _advancedExpanded
                          ? [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.sendHwidTitle),
                                subtitle: Text(l10n.sendHwidSubtitle),
                                value:
                                    _sendHwid ||
                                    SubscriptionFetcher.sendHwidToProviders,
                                onChanged:
                                    _busy ||
                                        SubscriptionFetcher.sendHwidToProviders
                                    ? null
                                    : (value) {
                                        setState(() => _sendHwid = value);
                                        unawaited(
                                          _saveRequestSettings(subscription),
                                        );
                                      },
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.useCustomHwidTitle),
                                value: _useCustomHwid,
                                onChanged: _busy
                                    ? null
                                    : (value) {
                                        setState(() => _useCustomHwid = value);
                                        unawaited(
                                          _saveRequestSettings(subscription),
                                        );
                                      },
                              ),
                              if (_useCustomHwid)
                                TextField(
                                  key: const PageStorageKey(
                                    'subscription_custom_hwid',
                                  ),
                                  controller: _customHwidController,
                                  enabled: !_busy,
                                  decoration: InputDecoration(
                                    labelText: l10n.useCustomHwidTitle,
                                  ),
                                  inputFormatters: [noNewlineInputFormatter],
                                  onSubmitted: (_) =>
                                      _saveRequestSettings(subscription),
                                ),
                              const Gap(12),
                              TextField(
                                key: const PageStorageKey(
                                  'subscription_custom_user_agent',
                                ),
                                controller: _customUserAgentController,
                                enabled: !_busy,
                                decoration: InputDecoration(
                                  labelText: l10n.customUserAgentTitle,
                                  hintText:
                                      SubscriptionFetcher.defaultUserAgent,
                                ),
                                inputFormatters: [noNewlineInputFormatter],
                                onSubmitted: (_) =>
                                    _saveRequestSettings(subscription),
                              ),
                              const Gap(12),
                              TextField(
                                key: const PageStorageKey(
                                  'subscription_custom_headers',
                                ),
                                controller: _customHeadersController,
                                enabled: !_busy,
                                minLines: 2,
                                maxLines: 6,
                                decoration: InputDecoration(
                                  labelText: l10n.customRequestHeadersTitle,
                                  helperText: l10n.customRequestHeadersSubtitle,
                                  helperMaxLines: 3,
                                ),
                              ),
                              const Gap(12),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () =>
                                            _saveRequestSettings(subscription),
                                  child: Text(l10n.saveAction),
                                ),
                              ),
                            ]
                          : const [],
                    ),
                  ),
                if (info?.supportUrl != null || info?.webPageUrl != null)
                  _DetailsBlock(
                    title: l10n.infoTitle,
                    child: Column(
                      children: [
                        if (info?.supportUrl case final url?)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.support_agent_rounded),
                            title: Text(l10n.supportUrlLabel),
                            trailing: const Icon(
                              Icons.open_in_new_rounded,
                              size: 18,
                            ),
                            onTap: () => _openUrl(url),
                          ),
                        if (info?.webPageUrl case final url?)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.language_rounded),
                            title: Text(l10n.websiteLabel),
                            trailing: const Icon(
                              Icons.open_in_new_rounded,
                              size: 18,
                            ),
                            onTap: () => _openUrl(url),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
