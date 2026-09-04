import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meow_client/app/deep_link_import.dart';
import 'package:meow_client/app/widgets/deep_link_import_sheet.dart';
import 'package:meow_client/data/subscription/happ_crypto_link.dart';
import 'package:meow_client/data/subscription/subscription_fetcher.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/features/subscriptions/subscription_error_message.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/models/subscription.dart';

class DeepLinkImportHost {
  const DeepLinkImportHost({
    required this.isMounted,
    required this.isReady,
    required this.isOnboardingCompleted,
    required this.isLegalAccepted,
    required this.getNavigatorContext,
    required this.showSnackBar,
    required this.runSubscriptionOperationWithWarning,
    required this.getSubscriptionOperationTimeout,
    required this.getAllowUntrustedSubscriptionCertificates,
    required this.onSubscriptionRouteAttempt,
    required this.reloadSubscriptions,
    required this.offerLikelyHwidFix,
    required this.userFacingSubscriptionError,
  });

  final bool Function() isMounted;
  final bool Function() isReady;
  final bool Function() isOnboardingCompleted;
  final bool Function() isLegalAccepted;
  final BuildContext? Function() getNavigatorContext;
  final void Function(String message) showSnackBar;
  final Future<SubscriptionImportResult> Function(
    Future<SubscriptionImportResult> future, {
    required String slowMessage,
    required String timeoutMessage,
  }) runSubscriptionOperationWithWarning;
  final Duration Function() getSubscriptionOperationTimeout;
  final bool Function() getAllowUntrustedSubscriptionCertificates;
  final SubscriptionFetchRouteAttemptCallback onSubscriptionRouteAttempt;
  final Future<void> Function() reloadSubscriptions;
  final Future<void> Function(Subscription subscription) offerLikelyHwidFix;
  final String Function(Object error, AppLocalizations l10n)
      userFacingSubscriptionError;
}

class DeepLinkImportCoordinator {
  DeepLinkImportCoordinator({
    required this.host,
    Stream<DeepLinkImportRequest>? importStream,
    Future<DeepLinkImportRequest?> Function()? initialRequestProvider,
  })  : _importStream = importStream ?? DeepLinkImportBridge.stream,
        _initialRequestProvider =
            initialRequestProvider ?? DeepLinkImportBridge.getInitialRequest;

  final DeepLinkImportHost host;
  final Stream<DeepLinkImportRequest> _importStream;
  final Future<DeepLinkImportRequest?> Function() _initialRequestProvider;

  StreamSubscription<DeepLinkImportRequest>? _deepLinkImportSubscription;
  DeepLinkImportRequest? _pendingDeepLinkImport;
  bool _deepLinkImportInFlight = false;

  bool get hasPendingImport => _pendingDeepLinkImport != null;
  DeepLinkImportRequest? get pendingImport => _pendingDeepLinkImport;
  bool get isInFlight => _deepLinkImportInFlight;

  Future<void> start() async {
    _deepLinkImportSubscription = _importStream.listen(enqueue);

    final initialRequest = await _initialRequestProvider();
    if (!host.isMounted() || initialRequest == null) {
      return;
    }
    enqueue(initialRequest);
  }

  void enqueue(DeepLinkImportRequest request) {
    if (host.isReady() &&
        host.isOnboardingCompleted() &&
        !host.isLegalAccepted()) {
      host.showSnackBar(_legalImportBlockedMessage());
      return;
    }
    _pendingDeepLinkImport = request;
    if (!host.isReady() ||
        !host.isOnboardingCompleted() ||
        !host.isLegalAccepted() ||
        _deepLinkImportInFlight) {
      return;
    }
    unawaited(drainPendingImports());
  }

  Future<void> drainPendingImports() async {
    if (_deepLinkImportInFlight) {
      return;
    }

    if (_pendingDeepLinkImport != null && !host.isLegalAccepted()) {
      _pendingDeepLinkImport = null;
      host.showSnackBar(_legalImportBlockedMessage());
      return;
    }

    while (host.isMounted() &&
        host.isReady() &&
        host.isOnboardingCompleted() &&
        host.isLegalAccepted()) {
      final request = _pendingDeepLinkImport;
      if (request == null) {
        return;
      }

      final context = host.getNavigatorContext();
      if (context == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (host.isMounted() &&
              host.isReady() &&
              host.isOnboardingCompleted() &&
              host.isLegalAccepted()) {
            unawaited(drainPendingImports());
          }
        });
        return;
      }

      _pendingDeepLinkImport = null;
      _deepLinkImportInFlight = true;
      try {
        await _handleDeepLinkImport(request, context);
      } finally {
        _deepLinkImportInFlight = false;
      }
    }
  }

  Future<void> _handleDeepLinkImport(
    DeepLinkImportRequest request,
    BuildContext context,
  ) async {
    final l10n = AppLocalizations.of(context);
    final copy = DeepLinkImportCopy.fromContext(context);

    if (!HappCryptoLinkDecoder.isSupportedSubscriptionUrl(request.url)) {
      host.showSnackBar(l10n.invalidUrl);
      return;
    }

    try {
      final preview = await DeepLinkImportPreview.build(request);
      if (!context.mounted) {
        return;
      }
      final decision = await showModalBottomSheet<DeepLinkImportDecision>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => DeepLinkImportSheet(
          request: request,
          preview: preview,
          copy: copy,
          l10n: l10n,
        ),
      );
      if (decision == null) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      final requestInfo = switch (decision) {
        DeepLinkImportDecision.sendHwid => preview.requestInfo,
        DeepLinkImportDecision.importWithoutHwid =>
          preview.requestInfo?.copyWith(requireHwid: false),
        DeepLinkImportDecision.import => preview.requestInfo,
      };

      final createdResult =
          await host.runSubscriptionOperationWithWarning(
        SubscriptionStore.addFromUrl(
          preview.resolvedUrl,
          customName: request.name,
          requestInfo: requestInfo,
          operationTimeout: host.getSubscriptionOperationTimeout(),
          allowInsecureTls:
              host.getAllowUntrustedSubscriptionCertificates(),
          onRouteAttempt: host.onSubscriptionRouteAttempt,
        ),
        slowMessage: l10n.subscriptionOperationSlowWarning,
        timeoutMessage: l10n.subscriptionOperationTimeout,
      );
      final created = createdResult.subscription;
      await host.reloadSubscriptions();
      if (!host.isMounted()) {
        return;
      }
      host.showSnackBar(
        createdResult.hasWarning
            ? subscriptionSavedWarningMessage(createdResult.warning, l10n)
            : copy.imported(created.name),
      );
      await host.offerLikelyHwidFix(created);
    } catch (error) {
      if (!host.isMounted()) {
        return;
      }
      AppLogStore.warning(
        'subscription',
        'Deep-link subscription import failed: ${error.runtimeType}: $error',
      );
      host.showSnackBar(host.userFacingSubscriptionError(error, l10n));
    }
  }

  String _legalImportBlockedMessage() {
    final context = host.getNavigatorContext();
    if (context == null) {
      return 'Accept Terms and Privacy Policy before importing subscriptions.';
    }
    return AppLocalizations.of(context).legalImportBlockedMessage;
  }

  void dispose() {
    _deepLinkImportSubscription?.cancel();
    _deepLinkImportSubscription = null;
    _pendingDeepLinkImport = null;
  }
}
