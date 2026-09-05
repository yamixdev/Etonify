import 'package:meow_client/data/subscription/subscription_failure.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

String subscriptionErrorMessage(Object error, AppLocalizations l10n) {
  final failure = classifySubscriptionFailure(error);
  return switch (failure.kind) {
    SubscriptionFailureKind.invalidHwid => l10n.subscriptionErrorHwid,
    SubscriptionFailureKind.invalidUrl => l10n.subscriptionErrorInvalidUrl,
    SubscriptionFailureKind.credentialsRequireHttps =>
      l10n.subscriptionErrorHttpsRequired,
    SubscriptionFailureKind.unsafeRedirect =>
      l10n.subscriptionErrorUnsafeRedirect,
    SubscriptionFailureKind.redirect => l10n.subscriptionErrorRedirect,
    SubscriptionFailureKind.httpStatus => _httpStatusMessage(
      failure.httpStatus,
      l10n,
    ),
    SubscriptionFailureKind.timeout => l10n.subscriptionOperationTimeout,
    SubscriptionFailureKind.dns => l10n.subscriptionErrorDns,
    SubscriptionFailureKind.connection => l10n.subscriptionErrorConnection,
    SubscriptionFailureKind.tls => l10n.subscriptionErrorTls,
    SubscriptionFailureKind.emptyResponse =>
      l10n.subscriptionErrorEmptyResponse,
    SubscriptionFailureKind.htmlResponse => l10n.subscriptionErrorHtmlResponse,
    SubscriptionFailureKind.responseTooLarge =>
      l10n.subscriptionErrorResponseTooLarge,
    SubscriptionFailureKind.noUsableProxies =>
      l10n.subscriptionErrorNoUsableProxies,
    SubscriptionFailureKind.wireGuardUnsupported =>
      l10n.wireGuardUnsupportedMessage,
    SubscriptionFailureKind.invalidContent =>
      l10n.subscriptionErrorInvalidContent,
    SubscriptionFailureKind.happUnsupported => l10n.happCryptUnsupportedMessage,
    SubscriptionFailureKind.happInvalid => l10n.subscriptionErrorHappInvalid,
    SubscriptionFailureKind.unknown => l10n.subscriptionErrorUnknown,
  };
}

String subscriptionSavedWarningMessage(Object? warning, AppLocalizations l10n) {
  if (warning == null) {
    return l10n.subscriptionSavedWithFetchWarning;
  }
  if (classifySubscriptionFailure(warning).kind ==
      SubscriptionFailureKind.wireGuardUnsupported) {
    return l10n.wireGuardServersSkippedMessage;
  }
  return l10n.subscriptionSavedWithFetchWarningReason(
    subscriptionErrorMessage(warning, l10n),
  );
}

String _httpStatusMessage(int? status, AppLocalizations l10n) {
  if (status == null || status < 100 || status > 599) {
    return l10n.subscriptionErrorUnknown;
  }
  return switch (status) {
    400 => l10n.subscriptionErrorHttp400,
    401 => l10n.subscriptionErrorHttp401,
    402 => l10n.subscriptionErrorHttp402,
    403 => l10n.subscriptionErrorHttp403,
    404 => l10n.subscriptionErrorHttp404,
    408 => l10n.subscriptionErrorHttp408,
    410 => l10n.subscriptionErrorHttp410,
    429 => l10n.subscriptionErrorHttp429,
    500 => l10n.subscriptionErrorHttp500,
    502 => l10n.subscriptionErrorHttp502,
    503 => l10n.subscriptionErrorHttp503,
    504 => l10n.subscriptionErrorHttp504,
    _ => l10n.subscriptionErrorHttpStatus(status),
  };
}
