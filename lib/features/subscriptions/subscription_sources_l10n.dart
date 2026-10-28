import 'package:meow_client/l10n/generated/app_localizations.dart';

extension SubscriptionSourcesL10n on AppLocalizations {
  bool get _ru => localeName.startsWith('ru');
  String get profileSources => _ru ? 'Источники профиля' : 'Profile sources';
  String get addProfileSource => _ru ? 'Добавить источник' : 'Add source';
  String get sourceAdded => _ru ? 'Источник добавлен' : 'Source added';
  String sourcesRefreshSummary(int updated, int total) => _ru
      ? 'Источники обновлены: $updated из $total.'
      : 'Sources updated: $updated of $total.';
  String get sourceScanQr => _ru ? 'QR-код' : 'Scan QR';
  String get sourceLocal => _ru ? 'Локальный импорт' : 'Local import';
  String get sourceNeverUpdated =>
      _ru ? 'Ещё не обновлялся' : 'Not updated yet';
  String get sourceUpdateFailed => _ru
      ? 'Не удалось обновить. Сохранены прежние серверы.'
      : 'Update failed. Previous servers are preserved.';
  String get sourceLastAttempt => _ru ? 'Последняя попытка' : 'Last attempt';
  String get sourceRemoveTitle => _ru ? 'Удалить источник?' : 'Remove source?';
  String get sourceBackupUnsupported => _ru
      ? 'Резервная копия создаёт профиль целиком. Добавьте её с главного экрана.'
      : 'A backup imports a complete profile. Import it from the home screen.';
  String get sourceRemoveBody => _ru
      ? 'Серверы этого источника будут удалены из профиля.'
      : 'Servers from this source will be removed from the profile.';
  String get sourceKeepOneEnabled => _ru
      ? 'В профиле должен оставаться хотя бы один включённый источник.'
      : 'Keep at least one enabled source in the profile.';
}
