import 'package:meow_client/core/network/remote_download_timeout.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

String? remoteDownloadErrorMessage(AppLocalizations l10n, Object error) {
  if (error is! RemoteDownloadTimeoutException) {
    return null;
  }
  return switch (error.phase) {
    RemoteDownloadTimeoutPhase.connecting => l10n.remoteDownloadConnectTimeout,
    RemoteDownloadTimeoutPhase.awaitingResponse =>
      l10n.remoteDownloadResponseTimeout,
    RemoteDownloadTimeoutPhase.receiving => l10n.remoteDownloadIdleTimeout,
  };
}
