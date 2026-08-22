import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:meow_client/app/bounded_task_runner.dart';
import 'package:meow_client/core/demo_utils.dart';
import 'package:meow_client/core/security/sensitive_clipboard.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/data/backup/etonify_backup_service.dart';
import 'package:meow_client/data/subscription/happ_crypto_link.dart';
import 'package:meow_client/data/subscription/subscription_failure.dart';
import 'package:meow_client/data/subscription/subscription_fetcher.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/features/subscriptions/subscription_error_message.dart';
import 'package:meow_client/features/subscriptions/subscription_file_reader.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

part 'subscriptions_page_add.dart';
part 'subscriptions_page_detail_widgets.dart';
part 'subscriptions_page_details.dart';
part 'subscriptions_page_list.dart';
part 'subscriptions_page_qr.dart';

const _kSubscriptionProxyPreviewLimit = 50;
const _kSubscriptionOperationSoftWarningDelay = Duration(seconds: 15);
const _kSubscriptionOperationTimeout = Duration(seconds: 30);
const _kSubscriptionSheetMinExtent = .28;
const _kSubscriptionSheetListExtent = .38;
const _kSubscriptionSheetAddQuickExtent = .44;
const _kSubscriptionSheetAddManualExtent = .92;
const _kSubscriptionSheetMaxExtent = .92;
const _kSubscriptionSheetHeaderHeight = 104.0;
const _kAddSubscriptionSheetHeaderHeight = 132.0;
const _kSubscriptionSheetAnimationDuration = Duration(milliseconds: 260);
const _kSubscriptionSummaryHydrationDelay = Duration(milliseconds: 420);
const _kAutoRefreshOptions = <int>[0, 60, 180, 360, 720, 1440];
final _kSingleLineFormatter = FilteringTextInputFormatter.deny(
  RegExp(r'[\r\n]'),
);

String _subscriptionLastUpdatedText(BuildContext context, int milliseconds) {
  final locale = Localizations.localeOf(context);
  final localeName = locale.toLanguageTag();
  final updatedAt = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final datePattern = locale.languageCode == 'ru'
      ? "d MMMM y 'года'"
      : 'MMMM d, y';
  final date = DateFormat(datePattern, localeName).format(updatedAt);
  final time = DateFormat('HH:mm:ss', localeName).format(updatedAt);
  return AppLocalizations.of(context).lastUpdatedDateTime(date, time);
}

int _visibleProxyCount(Iterable<Outbound> outbounds) {
  return outbounds
      .where((outbound) => !outbound.info.deleted)
      .where((outbound) => outbound.config['_group_only'] != true)
      .length;
}

enum _HappImportDecision { sendHwid, withoutHwid }

enum _SubscriptionSortMode { manual, name, updated, servers }

enum _SubscriptionsSheetMode { list, add }

class _LocalizedSubscriptionPageError implements Exception {
  const _LocalizedSubscriptionPageError(this.message);

  final String message;

  @override
  String toString() => message;
}

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({
    super.key,
    this.activeSubscriptionId,
    this.openAddOnStart = false,
    this.hapticEnabled = true,
    this.allowUntrustedSubscriptionCertificates = false,
  });

  final String? activeSubscriptionId;
  final bool openAddOnStart;
  final bool hapticEnabled;
  final bool allowUntrustedSubscriptionCertificates;

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  ScrollController? _sheetScrollController;
  List<Subscription> _subscriptions = [];
  final Set<String> _selectedIds = <String>{};
  final Set<String> _refreshingIds = <String>{};
  final Map<String, int> _subscriptionServerCounts = <String, int>{};
  final Set<String> _subscriptionsWithRawPayload = <String>{};
  int _countHydrationGeneration = 0;
  Timer? _countHydrationTimer;
  late _SubscriptionsSheetMode _sheetMode;
  _AddSubscriptionSheetMode _addSheetMode = _AddSubscriptionSheetMode.quick;
  int _addModeTransitionGeneration = 0;
  bool _closingFromMinExtent = false;
  bool _loading = false;
  int _refreshAllCompleted = 0;
  int _refreshAllTotal = 0;
  int _lastPhysicalFallbackNoticeAt = 0;
  String? _error;

  bool get _addOnly => widget.openAddOnStart;
  bool get _selectionMode => _selectedIds.isNotEmpty;
  double get _sheetMaxExtent =>
      _sheetMode == _SubscriptionsSheetMode.add &&
          _addSheetMode == _AddSubscriptionSheetMode.quick
      ? _kSubscriptionSheetAddQuickExtent
      : _kSubscriptionSheetMaxExtent;

  void _haptic() {
    if (widget.hapticEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleSubscriptionRouteAttempt(
    SubscriptionFetchRoute route,
    bool isFallback,
  ) {
    if (!mounted || !isFallback || route != SubscriptionFetchRoute.underlying) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPhysicalFallbackNoticeAt < 2000) {
      return;
    }
    _lastPhysicalFallbackNoticeAt = now;
    AppNotice.show(
      context,
      AppLocalizations.of(context).remoteDownloadRetryWithoutVpnHint,
    );
  }

  @override
  void initState() {
    super.initState();
    _sheetMode = _addOnly
        ? _SubscriptionsSheetMode.add
        : _SubscriptionsSheetMode.list;
    if (!_addOnly) {
      _reload();
    }
  }

  @override
  void dispose() {
    _countHydrationTimer?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  void _reload() {
    final generation = ++_countHydrationGeneration;
    unawaited(_reloadMetadataInBackground(generation));
  }

  Future<void> _reloadMetadataInBackground(int generation) async {
    final subscriptions = await SubscriptionStore.getAllMetadataInBackground();
    if (!mounted || generation != _countHydrationGeneration) {
      return;
    }
    setState(() {
      _subscriptions = subscriptions;
      for (final subscription in _subscriptions) {
        if (subscription.cachedVisibleProxyCount >= 0) {
          _subscriptionServerCounts[subscription.id] =
              subscription.cachedVisibleProxyCount;
          if (subscription.hasRawPayload) {
            _subscriptionsWithRawPayload.add(subscription.id);
          } else {
            _subscriptionsWithRawPayload.remove(subscription.id);
          }
        } else {
          _subscriptionServerCounts.remove(subscription.id);
          _subscriptionsWithRawPayload.remove(subscription.id);
        }
      }
      final ids = _subscriptions.map((subscription) => subscription.id).toSet();
      _subscriptionServerCounts.removeWhere((id, _) => !ids.contains(id));
      _subscriptionsWithRawPayload.removeWhere((id) => !ids.contains(id));
      _selectedIds.removeWhere(
        (id) => !_subscriptions.any((subscription) => subscription.id == id),
      );
      _refreshingIds.removeWhere(
        (id) => !_subscriptions.any((subscription) => subscription.id == id),
      );
    });
    _countHydrationTimer?.cancel();
    if (_subscriptions.any((sub) => sub.cachedVisibleProxyCount < 0)) {
      _countHydrationTimer = Timer(
        _kSubscriptionSummaryHydrationDelay,
        () => unawaited(_hydrateSubscriptionCounts(generation)),
      );
    }
  }

  Future<void> _hydrateSubscriptionCounts(int generation) async {
    final snapshot = _subscriptions
        .where((subscription) => subscription.cachedVisibleProxyCount < 0)
        .toList(growable: false);
    final counts = <String, int>{};
    final rawPayloadIds = <String>{};
    final summaries = <String, ({int visibleProxyCount, bool hasRawPayload})>{};
    for (final subscription in snapshot) {
      if (generation != _countHydrationGeneration) {
        return;
      }
      var hydrated = subscription;
      if (subscription.outbounds.isEmpty) {
        hydrated = await SubscriptionStore.withPayloadInBackground(
          subscription,
        );
      }
      final visibleProxyCount = _visibleProxyCount(hydrated.outbounds);
      final hasRawPayload = hydrated.rawContent.trim().length > 16;
      counts[subscription.id] = visibleProxyCount;
      summaries[subscription.id] = (
        visibleProxyCount: visibleProxyCount,
        hasRawPayload: hasRawPayload,
      );
      if (hasRawPayload) {
        rawPayloadIds.add(subscription.id);
      }
    }
    if (!mounted || generation != _countHydrationGeneration) {
      return;
    }
    setState(() {
      _subscriptionServerCounts.addAll(counts);
      _subscriptionsWithRawPayload.addAll(rawPayloadIds);
    });
    unawaited(SubscriptionStore.cachePayloadSummaries(summaries));
  }

  Future<T> _runSubscriptionOperationWithWarning<T>(Future<T> operation) async {
    var completed = false;
    final timer = Timer(_kSubscriptionOperationSoftWarningDelay, () {
      if (!completed && mounted) {
        AppNotice.show(
          context,
          AppLocalizations.of(context).subscriptionOperationSlowWarning,
          tone: AppNoticeTone.warning,
        );
      }
    });
    try {
      return await operation;
    } on TimeoutException {
      throw _LocalizedSubscriptionPageError(
        AppLocalizations.of(context).subscriptionOperationTimeout,
      );
    } finally {
      completed = true;
      timer.cancel();
    }
  }

  String _userFacingSubscriptionError(Object error) {
    if (error is _LocalizedSubscriptionPageError) {
      return error.message;
    }
    return subscriptionErrorMessage(error, AppLocalizations.of(context));
  }

  Future<Subscription> _maybeHandleMovedSubscription(Subscription sub) async {
    final info = sub.info;
    final movedUrl = info?.newUrl;
    final l10n = AppLocalizations.of(context);
    if (!mounted ||
        info == null ||
        info.ignoreSubscriptionMoved ||
        movedUrl == null ||
        movedUrl.isEmpty ||
        movedUrl == sub.url) {
      return sub;
    }

    final decision = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.subscriptionMovedTitle),
        content: Text('${l10n.movedSubscriptionMessage}\n\n$movedUrl'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.ignoreAction),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.updateUrlAction),
          ),
        ],
      ),
    );

    if (decision == true) {
      final updated = sub.copyWith(
        url: movedUrl,
        info: info.copyWith(newUrl: null, ignoreSubscriptionMoved: false),
      );
      await SubscriptionStore.save(updated);
      return updated;
    }

    final ignored = sub.copyWith(
      info: info.copyWith(ignoreSubscriptionMoved: true),
    );
    await SubscriptionStore.save(ignored);
    return ignored;
  }

  void _addSubscription() {
    if (_sheetMode == _SubscriptionsSheetMode.add) {
      return;
    }
    _haptic();
    _countHydrationTimer?.cancel();
    _countHydrationGeneration++;
    _addModeTransitionGeneration++;
    setState(() {
      _sheetMode = _SubscriptionsSheetMode.add;
      _addSheetMode = _AddSubscriptionSheetMode.quick;
    });
    unawaited(
      _animateSheetTo(_kSubscriptionSheetAddQuickExtent, resetScroll: true),
    );
  }

  void _closeAddSubscription({required bool changed}) {
    if (_addOnly) {
      Navigator.of(context).pop(changed);
      return;
    }
    _addModeTransitionGeneration++;
    setState(() => _sheetMode = _SubscriptionsSheetMode.list);
    unawaited(
      _animateSheetTo(
        _kSubscriptionSheetListExtent,
        resetScroll: true,
      ).whenComplete(() {
        if (changed && mounted && _sheetMode == _SubscriptionsSheetMode.list) {
          _reload();
        }
      }),
    );
  }

  void _handleAddModeChanged(_AddSubscriptionSheetMode mode) {
    final generation = ++_addModeTransitionGeneration;
    if (mode == _AddSubscriptionSheetMode.manual) {
      setState(() => _addSheetMode = mode);
    }
    unawaited(
      _animateSheetTo(
        mode == _AddSubscriptionSheetMode.manual
            ? _kSubscriptionSheetAddManualExtent
            : _kSubscriptionSheetAddQuickExtent,
        resetScroll: true,
      ).whenComplete(() {
        if (!mounted ||
            generation != _addModeTransitionGeneration ||
            _sheetMode != _SubscriptionsSheetMode.add ||
            mode != _AddSubscriptionSheetMode.quick) {
          return;
        }
        setState(() => _addSheetMode = mode);
      }),
    );
  }

  Future<void> _animateSheetTo(
    double extent, {
    bool resetScroll = false,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_sheetController.isAttached) {
      return;
    }
    if (resetScroll) {
      final scrollController = _sheetScrollController;
      if (scrollController != null && scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.minScrollExtent);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || !_sheetController.isAttached) {
          return;
        }
      }
    }
    await _sheetController.animateTo(
      extent.clamp(_kSubscriptionSheetMinExtent, _sheetMaxExtent),
      duration: _kSubscriptionSheetAnimationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _handleSheetHeaderDragUpdate(DragUpdateDetails details) {
    if (!_sheetController.isAttached) {
      return;
    }
    final availableHeight = MediaQuery.sizeOf(context).height;
    if (availableHeight <= 0) {
      return;
    }
    final nextExtent =
        (_sheetController.size - details.delta.dy / availableHeight).clamp(
          _kSubscriptionSheetMinExtent,
          _sheetMaxExtent,
        );
    _sheetController.jumpTo(nextExtent);
  }

  void _handleSheetHeaderDragEnd(DragEndDetails details) {
    if (!_sheetController.isAttached) {
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    final current = _sheetController.size;
    final addMode = _sheetMode == _SubscriptionsSheetMode.add;
    final compactExtent = addMode
        ? _kSubscriptionSheetAddQuickExtent
        : _kSubscriptionSheetListExtent;
    if (current <= _kSubscriptionSheetMinExtent + .015 ||
        (velocity > 900 && current <= compactExtent + .08)) {
      if (addMode && !_addOnly) {
        _closeAddSubscription(changed: false);
      } else {
        Navigator.of(context).maybePop();
      }
      return;
    }
    final target = velocity < -650 || current > (compactExtent + .18)
        ? _sheetMaxExtent
        : compactExtent;
    unawaited(_animateSheetTo(target));
  }

  bool _handleSheetNotification(DraggableScrollableNotification notification) {
    if (notification.extent > _kSubscriptionSheetMinExtent + .002 ||
        _closingFromMinExtent) {
      return false;
    }
    _closingFromMinExtent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _closingFromMinExtent = false;
      if (_sheetMode == _SubscriptionsSheetMode.add && !_addOnly) {
        _closeAddSubscription(changed: false);
      } else {
        Navigator.of(context).maybePop();
      }
    });
    return false;
  }

  Future<bool> _importAddResult(_AddResult result) async {
    try {
      final prepared = await _prepareSubscriptionImport(result);
      if (prepared == null) {
        return false;
      }

      final createdResult = await _runSubscriptionOperationWithWarning(
        prepared.fileContent != null
            ? SubscriptionStore.addFromContent(
                prepared.fileContent!,
                customName: result.name.isNotEmpty ? result.name : null,
                sourceName: prepared.sourceName,
                operationTimeout: _kSubscriptionOperationTimeout,
                isCancelled: result.isCancelled,
              )
            : SubscriptionStore.addFromUrl(
                prepared.url!,
                customName: result.name.isNotEmpty ? result.name : null,
                autoRefreshMinutes: result.autoRefreshMinutes,
                requestInfo: prepared.requestInfo,
                operationTimeout: _kSubscriptionOperationTimeout,
                isCancelled: result.isCancelled,
                allowInsecureTls: widget.allowUntrustedSubscriptionCertificates,
                onRouteAttempt: _handleSubscriptionRouteAttempt,
              ),
      );
      final created = createdResult.subscription;
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        if (createdResult.hasWarning) {
          AppNotice.show(
            context,
            subscriptionSavedWarningMessage(createdResult.warning, l10n),
            tone: AppNoticeTone.warning,
          );
        }
        if (prepared.fileContent == null) {
          await _offerLikelyHwidFix(created);
        }
      }
      await _maybeHandleMovedSubscription(created);
      if (mounted) {
        setState(() {
          _subscriptionServerCounts[created.id] = _visibleProxyCount(
            created.outbounds,
          );
          if (created.rawContent.trim().length > 16) {
            _subscriptionsWithRawPayload.add(created.id);
          }
        });
      }
      return true;
    } on SubscriptionImportCancelledException {
      rethrow;
    } catch (e) {
      AppLogStore.warning(
        'subscription',
        'Subscription import failed: ${e.runtimeType}: $e',
      );
      throw _LocalizedSubscriptionPageError(_userFacingSubscriptionError(e));
    }
  }

  Future<_PreparedSubscriptionImport?> _prepareSubscriptionImport(
    _AddResult result,
  ) async {
    if (result.fileContent != null) {
      return _PreparedSubscriptionImport(
        fileContent: result.fileContent,
        sourceName: result.sourceName,
      );
    }

    final rawUrl = result.url.trim();
    if (!HappCryptoLinkDecoder.isSupportedLink(rawUrl)) {
      return _PreparedSubscriptionImport(
        url: rawUrl,
        requestInfo: result.requestInfo,
      );
    }

    final decision = await _showHappImportDialog();
    if (decision == null) {
      return null;
    }

    final prepared = await HappCryptoLinkDecoder.prepare(rawUrl);
    final requestInfo = switch (decision) {
      _HappImportDecision.sendHwid => prepared.requestInfo,
      _HappImportDecision.withoutHwid => prepared.requestInfo?.copyWith(
        requireHwid: false,
      ),
    };
    return _PreparedSubscriptionImport(
      url: prepared.resolvedUrl,
      requestInfo: _mergeSubscriptionRequestInfo(
        requestInfo,
        result.requestInfo,
      ),
    );
  }

  SubscriptionInfo? _mergeSubscriptionRequestInfo(
    SubscriptionInfo? base,
    SubscriptionInfo? override,
  ) {
    if (base == null) {
      return override;
    }
    if (override == null) {
      return base;
    }
    return SubscriptionInfo(
      title: base.title,
      upload: base.upload,
      download: base.download,
      total: base.total,
      expire: base.expire,
      happCryptoLink: base.happCryptoLink,
      supportUrl: base.supportUrl,
      webPageUrl: base.webPageUrl,
      newUrl: base.newUrl,
      ignoreSubscriptionMoved: base.ignoreSubscriptionMoved,
      updateIntervalHours: base.updateIntervalHours,
      perAppProxyMode: base.perAppProxyMode,
      perAppProxyList: base.perAppProxyList,
      customUserAgent: override.customUserAgent ?? base.customUserAgent,
      customRequestHeader:
          override.customRequestHeader ?? base.customRequestHeader,
      requireHwid: base.requireHwid || override.requireHwid,
      customHwid: override.customHwid ?? base.customHwid,
    );
  }

  Future<_HappImportDecision?> _showHappImportDialog() {
    final l10n = AppLocalizations.of(context);
    return showDialog<_HappImportDecision>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.happImportTitle),
        content: Text(l10n.happImportMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.of(dialogContext).cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(_HappImportDecision.withoutHwid),
            child: Text(l10n.deepLinkImportHappWithoutHwidAction),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_HappImportDecision.sendHwid),
            child: Text(
              AppLocalizations.of(
                dialogContext,
              ).deepLinkImportHappSendHwidAction,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshSubscription(String id) async {
    if (_refreshingIds.contains(id)) {
      return;
    }
    final subscription = await SubscriptionStore.getInBackground(id);
    if (subscription != null &&
        SubscriptionStore.isLocalFileImportUrl(subscription.url)) {
      setState(() {
        _error = AppLocalizations.of(
          context,
        ).refreshActiveSubscriptionUnavailable;
      });
      return;
    }
    _haptic();
    setState(() {
      _refreshingIds.add(id);
      _error = null;
    });
    try {
      final updated = await _runSubscriptionOperationWithWarning(
        SubscriptionStore.refresh(
          id,
          operationTimeout: _kSubscriptionOperationTimeout,
          allowInsecureTls: widget.allowUntrustedSubscriptionCertificates,
          onRouteAttempt: _handleSubscriptionRouteAttempt,
        ),
      );
      if (mounted) {
        if (!SubscriptionStore.isLocalFileImportUrl(updated.url)) {
          await _offerLikelyHwidFix(updated);
        }
      }
      await _maybeHandleMovedSubscription(updated);
      _reload();
    } catch (e) {
      setState(() => _error = _userFacingSubscriptionError(e));
    } finally {
      if (mounted) {
        setState(() {
          _refreshingIds.remove(id);
        });
      }
    }
  }

  Future<void> _offerLikelyHwidFix(Subscription subscription) async {
    if (!SubscriptionStore.likelyRequiresHwidEnable(subscription) || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.subscriptionLikelyRequiresHwidTitle),
        content: Text(l10n.subscriptionLikelyRequiresHwidMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.of(dialogContext).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.subscriptionLikelyRequiresHwidAction),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _enableHwidAndRefreshSubscription(subscription.id);
  }

  Future<void> _enableHwidAndRefreshSubscription(String id) async {
    final current = await SubscriptionStore.getInBackground(id);
    if (current == null) {
      return;
    }
    final info = current.info ?? const SubscriptionInfo();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SubscriptionStore.save(
        current.copyWith(info: info.copyWith(requireHwid: true)),
      );
      final updated = await _runSubscriptionOperationWithWarning(
        SubscriptionStore.refresh(
          id,
          operationTimeout: _kSubscriptionOperationTimeout,
          allowInsecureTls: widget.allowUntrustedSubscriptionCertificates,
          onRouteAttempt: _handleSubscriptionRouteAttempt,
        ),
      );
      if (!mounted) {
        return;
      }
      AppNotice.show(
        context,
        AppLocalizations.of(context).subscriptionHwidEnabledAndUpdated,
        tone: AppNoticeTone.success,
      );
      await _maybeHandleMovedSubscription(updated);
      _reload();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = _userFacingSubscriptionError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshAll() async {
    if (_loading) {
      return;
    }
    _haptic();
    final refreshable = _subscriptions
        .where((sub) => !SubscriptionStore.isLocalFileImportUrl(sub.url))
        .toList(growable: false);
    setState(() {
      _loading = true;
      _refreshAllCompleted = 0;
      _refreshAllTotal = refreshable.length;
      _error = null;
    });
    try {
      final results = await _runSubscriptionOperationWithWarning(
        runBoundedTasks<Subscription>(
          refreshable
              .map<Future<Subscription> Function()>(
                (sub) =>
                    () => SubscriptionStore.refresh(
                      sub.id,
                      operationTimeout: _kSubscriptionOperationTimeout,
                      allowInsecureTls:
                          widget.allowUntrustedSubscriptionCertificates,
                      onRouteAttempt: _handleSubscriptionRouteAttempt,
                    ),
              )
              .toList(growable: false),
          concurrency: 2,
          onSettled: (completed, total) {
            if (mounted) {
              setState(() {
                _refreshAllCompleted = completed;
                _refreshAllTotal = total;
              });
            }
          },
        ),
      );
      final updated = results
          .whereType<BoundedTaskSuccess<Subscription>>()
          .length;
      final failed = results.length - updated;
      _reload();
      if (!mounted) {
        return;
      }
      AppNotice.show(
        context,
        AppLocalizations.of(
          context,
        ).subscriptionsRefreshAllComplete(updated, failed),
        tone: failed > 0 ? AppNoticeTone.warning : AppNoticeTone.success,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshAllCompleted = 0;
          _refreshAllTotal = 0;
        });
      }
    }
  }

  Future<void> _deleteSubscription(String id) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteSubscription),
        content: Text(l10n.deleteSubscriptionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _haptic();
      await SubscriptionStore.delete(id);
      _reload();
    }
  }

  void _toggleSelection(String id) {
    _haptic();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteSubscription),
        content: Text(l10n.deleteSubscriptionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    _haptic();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SubscriptionStore.deleteMany(_selectedIds);
      _clearSelection();
      _reload();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _moveSubscriptionUp(String id) async {
    _haptic();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SubscriptionStore.moveUp(id);
      _reload();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sortSubscriptions(_SubscriptionSortMode mode) async {
    if (_subscriptions.length < 2) {
      return;
    }
    _haptic();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final next = _subscriptions.toList(growable: false);
      switch (mode) {
        case _SubscriptionSortMode.manual:
          break;
        case _SubscriptionSortMode.name:
          next.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        case _SubscriptionSortMode.updated:
          next.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        case _SubscriptionSortMode.servers:
          next.sort((a, b) {
            final left = _subscriptionServerCounts[a.id] ?? 0;
            final right = _subscriptionServerCounts[b.id] ?? 0;
            return right.compareTo(left);
          });
      }
      if (mounted) {
        setState(() => _subscriptions = next);
      }
      await SubscriptionStore.reorder(next);
      _reload();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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

  Future<void> _showSubscriptionQr(
    Subscription subscription, {
    required String title,
  }) async {
    final value = _qrShareValue(subscription).trim();
    if (value.isEmpty ||
        !HappCryptoLinkDecoder.isSupportedSubscriptionUrl(value)) {
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
        builder: (context) => _SubscriptionQrPage(title: title, value: value),
      ),
    );
  }

  Future<void> _copySubscriptionUrl(Subscription subscription) async {
    await SensitiveClipboard.copy(subscription.url);
    if (!mounted) {
      return;
    }
    AppNotice.show(
      context,
      AppLocalizations.of(context).subscriptionUrlCopied,
      tone: AppNoticeTone.success,
    );
  }

  Future<void> _copySubscriptionJson(Subscription subscription) async {
    final hydrated =
        await SubscriptionStore.getInBackground(subscription.id) ??
        subscription;
    const encoder = JsonEncoder.withIndent('  ');
    await SensitiveClipboard.copy(encoder.convert(hydrated.toMap()));
    if (!mounted) {
      return;
    }
    AppNotice.show(
      context,
      AppLocalizations.of(context).subscriptionJsonCopied,
      tone: AppNoticeTone.success,
    );
  }

  Future<void> _openSubscriptionDetails(
    Subscription subscription, {
    required int index,
  }) async {
    _haptic();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SubscriptionDetailsPage(
          subscriptionId: subscription.id,
          onRefresh: () => _refreshSubscription(subscription.id),
          onDelete: () => _deleteSubscription(subscription.id),
          onMoveUp: index > 0
              ? () => _moveSubscriptionUp(subscription.id)
              : null,
          hapticEnabled: widget.hapticEnabled,
        ),
      ),
    );
    if (mounted) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final initialExtent = _addOnly
        ? _kSubscriptionSheetAddQuickExtent
        : _subscriptions.isEmpty
        ? .40
        : _kSubscriptionSheetListExtent;

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: _handleSheetNotification,
      child: DraggableScrollableSheet(
        controller: _sheetController,
        expand: false,
        initialChildSize: initialExtent,
        minChildSize: _kSubscriptionSheetMinExtent,
        maxChildSize: _sheetMaxExtent,
        builder: (context, scrollController) {
          _sheetScrollController = scrollController;
          return Theme(
            data: settingsTileTheme(context),
            child: RepaintBoundary(
              child: Material(
                key: const ValueKey('subscriptions_sheet_clip'),
                color: cs.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                clipBehavior: Clip.hardEdge,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: cs.outlineVariant)),
                  ),
                  child: _sheetMode == _SubscriptionsSheetMode.add
                      ? _AddSubscriptionSheet(
                          onAdd: _importAddResult,
                          scrollController: scrollController,
                          onClose: (changed) =>
                              _closeAddSubscription(changed: changed),
                          onModeChanged: _handleAddModeChanged,
                          onHeaderDragUpdate: _handleSheetHeaderDragUpdate,
                          onHeaderDragEnd: _handleSheetHeaderDragEnd,
                        )
                      : Stack(
                          children: [
                            CustomScrollView(
                              controller: scrollController,
                              slivers: [
                                const SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: _kSubscriptionSheetHeaderHeight,
                                  ),
                                ),
                                if (_error != null)
                                  SliverToBoxAdapter(
                                    child: Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.fromLTRB(
                                        18,
                                        8,
                                        18,
                                        2,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.errorContainer,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        _error!,
                                        style: TextStyle(
                                          color: cs.onErrorContainer,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_subscriptions.isEmpty)
                                  SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: _EmptySubscriptionsPanel(
                                      onAdd: _addSubscription,
                                    ),
                                  )
                                else
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      8,
                                      14,
                                      0,
                                    ),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, itemIndex) {
                                          if (itemIndex.isOdd) {
                                            return const Gap(10);
                                          }
                                          final index = itemIndex ~/ 2;
                                          final sub = _subscriptions[index];
                                          final hydratedServerCount =
                                              _subscriptionServerCounts[sub.id];
                                          final serverCount =
                                              hydratedServerCount ??
                                              _visibleProxyCount(sub.outbounds);
                                          final rawLooksNonEmpty =
                                              _subscriptionsWithRawPayload
                                                  .contains(sub.id) ||
                                              (sub.rawContent
                                                      .trim()
                                                      .isNotEmpty &&
                                                  sub.rawContent.trim().length >
                                                      16);
                                          return _SubscriptionCard(
                                            subscription: sub,
                                            serverCount: serverCount,
                                            rawLooksNonEmpty: rawLooksNonEmpty,
                                            active:
                                                sub.id ==
                                                widget.activeSubscriptionId,
                                            multiSelected: _selectedIds
                                                .contains(sub.id),
                                            selectionMode: _selectionMode,
                                            loading:
                                                _loading ||
                                                _refreshingIds.contains(sub.id),
                                            onSelect: () {
                                              if (_selectionMode) {
                                                _toggleSelection(sub.id);
                                              } else {
                                                Navigator.of(
                                                  context,
                                                ).pop(sub.id);
                                              }
                                            },
                                            onLongPress: () =>
                                                _toggleSelection(sub.id),
                                            onRefresh: () =>
                                                _refreshSubscription(sub.id),
                                            onCopyUrl: () =>
                                                _copySubscriptionUrl(sub),
                                            onShowQr: () => _showSubscriptionQr(
                                              sub,
                                              title: sub.name,
                                            ),
                                            onCopyJson: () =>
                                                _copySubscriptionJson(sub),
                                            onEdit: () =>
                                                _openSubscriptionDetails(
                                                  sub,
                                                  index: index,
                                                ),
                                            onDelete: () =>
                                                _deleteSubscription(sub.id),
                                          );
                                        },
                                        childCount:
                                            _subscriptions.length * 2 - 1,
                                      ),
                                    ),
                                  ),
                                SliverToBoxAdapter(
                                  child: SizedBox(height: bottomPadding + 14),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.topCenter,
                              child: _SubscriptionsSheetHeader(
                                title: _selectionMode
                                    ? '${_selectedIds.length}'
                                    : _loading && _refreshAllTotal > 0
                                    ? l10n.subscriptionsRefreshAllProgress(
                                        _refreshAllCompleted,
                                        _refreshAllTotal,
                                      )
                                    : l10n.subscriptionsTitle,
                                selectionMode: _selectionMode,
                                loading: _loading,
                                canSort: _subscriptions.length > 1,
                                canRefreshAll: _subscriptions.isNotEmpty,
                                onSortSelected: (mode) {
                                  _haptic();
                                  unawaited(_sortSubscriptions(mode));
                                },
                                onRefreshAll: _refreshAll,
                                onAdd: _addSubscription,
                                onDeleteSelected: _deleteSelected,
                                onClearSelection: _clearSelection,
                                onClose: () => Navigator.of(context).pop(),
                                onVerticalDragUpdate:
                                    _handleSheetHeaderDragUpdate,
                                onVerticalDragEnd: _handleSheetHeaderDragEnd,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
