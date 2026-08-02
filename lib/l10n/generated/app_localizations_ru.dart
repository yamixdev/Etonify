// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get profiles => 'Профили';

  @override
  String get close => 'Закрыть';

  @override
  String get homeTab => 'Главная';

  @override
  String get proxiesTab => 'Прокси';

  @override
  String get proxiesTitle => 'Прокси';

  @override
  String get proxySwitching => 'Переключение';

  @override
  String get proxyUnavailable => 'Недоступен';

  @override
  String get proxySelectorTitle => 'Выбор';

  @override
  String get proxyLowestName => 'Lowest';

  @override
  String get proxyAutomaticSelectionLabel => 'Автовыбор';

  @override
  String get proxyChainLabel => 'Цепочка';

  @override
  String get proxyChainAddTitle => 'Добавить цепочку прокси';

  @override
  String get proxyChainAddTile => 'Добавить цепочку прокси';

  @override
  String get proxyChainChangeFirstHop => 'Изменить первый прокси';

  @override
  String get proxyChainRenameAction => 'Переименовать';

  @override
  String get proxyChainRenameTitle => 'Переименовать цепочку прокси';

  @override
  String get proxyChainRemoveAction => 'Удалить цепочку прокси';

  @override
  String get proxyChainNameLabel => 'Название';

  @override
  String get proxyChainFirstHopLabel => 'Первый прокси';

  @override
  String get proxyChainExitLabel => 'Выходной прокси';

  @override
  String get proxyChainNothingFound => 'Ничего не найдено';

  @override
  String get proxyChainSaveAction => 'Сохранить';

  @override
  String get shareProxyTitle => 'Поделиться';

  @override
  String get shareProxyLinkLabel => 'Ссылка профиля';

  @override
  String get shareSingboxOutboundLabel => 'Конфиг sing-box';

  @override
  String copiedToClipboard(String label) {
    return '$label скопирован';
  }

  @override
  String get unavailableForThisType => 'Недоступно для этого типа';

  @override
  String get sort => 'Сортировка';

  @override
  String get sortByDefault => 'Как в подписке';

  @override
  String get sortByLatency => 'По задержке';

  @override
  String get sortByWorking => 'Только рабочие';

  @override
  String get sortByName => 'По имени';

  @override
  String get sortByCountry => 'По стране';

  @override
  String subscriptionWorkingServersCount(int working, int checked) {
    return 'Работают: $working из $checked проверенных';
  }

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get generalSectionTitle => 'Общее';

  @override
  String get inboundTitle => 'Входящие соединения';

  @override
  String get dnsTitle => 'DNS';

  @override
  String get whitelistTitle => 'Белые списки';

  @override
  String get whitelistSubtitle => 'Резервные инструменты маршрутизации';

  @override
  String get experimentalTitle => 'Экспериментальные';

  @override
  String get experimentalSubtitle =>
      'Multipath, Fast Open и поведение переключения соединений';

  @override
  String get logsTitle => 'Логи';

  @override
  String get logsSubtitle => 'Конфиг sing-box и события приложения';

  @override
  String get urlTestTitle => 'Проверка серверов';

  @override
  String get urlTestSubtitle =>
      'Проверка задержки и автоматический выбор сервера';

  @override
  String get vpnInTitle => 'VPN TUN';

  @override
  String get proxyInTitle => 'Прокси-вход';

  @override
  String get dnsDirectTitle => 'Напрямую';

  @override
  String get dnsProxyTitle => 'Через прокси';

  @override
  String get dnsIpPreferenceTitle => 'Версия IP';

  @override
  String get aboutSectionTitle => 'О клиенте';

  @override
  String get aboutSectionSubtitle =>
      'Версия клиента, ядро, команда и служебная информация.';

  @override
  String get aboutHeroSubtitle =>
      'VPN-клиент для Android, который мы делаем быстрым, понятным и надёжным для повседневного использования.';

  @override
  String get aboutDevelopedBy =>
      'Etonify разрабатывает небольшая независимая команда MeowTeam.';

  @override
  String get aboutContactLabel => 'Написать разработчикам';

  @override
  String get aboutCoreSourceLabel => 'исходный код ядра';

  @override
  String get telegramChannelLabel => 'Telegram Etonify';

  @override
  String get legalTermsTitle => 'Пользовательское соглашение';

  @override
  String get legalPrivacyTitle => 'Политика конфиденциальности';

  @override
  String get legalTermsSummary =>
      'Правила ответственного использования и ограничения ответственности.';

  @override
  String get legalPrivacySummary =>
      'Что Etonify хранит локально и какие данные не собирает.';

  @override
  String get legalGateTitle => 'Перед использованием Etonify';

  @override
  String legalGateSubtitle(String version) {
    return 'Начиная с версии $version, нужно прочитать и принять соглашение и политику конфиденциальности.';
  }

  @override
  String get legalAcceptAction => 'Принять и продолжить';

  @override
  String get legalAcceptHint => 'Откройте оба документа, чтобы продолжить.';

  @override
  String get legalDocumentReadAction => 'Прочитал';

  @override
  String get legalContactAction => 'Задать вопрос';

  @override
  String get legalImportBlockedMessage =>
      'Примите соглашение и политику конфиденциальности перед импортом подписок.';

  @override
  String get legalTermsBody =>
      '# Пользовательское соглашение Etonify\n\n## Что делает приложение\n\nEtonify — VPN-клиент для Android. **Приложение не продаёт и не выдаёт VPN-серверы:** пользователь самостоятельно добавляет подписки, профили и серверы сторонних поставщиков.\n\n## Ответственность пользователя\n\nИспользуйте Etonify в соответствии с законами вашей страны и правилами сервисов, к которым подключаетесь. Запрещено использовать клиент для атак, мошенничества, распространения вредоносного ПО, травли и других незаконных действий.\n\n- Вы отвечаете за добавленные профили и сохранность ключей.\n- Условия работы сторонних VPN-провайдеров определяют сами провайдеры.\n- MeowTeam не контролирует содержимое подписок и трафик сторонних серверов.\n\n## Работа и обновления\n\nEtonify предоставляется **как есть**. Мы исправляем ошибки и улучшаем безопасность, но не можем гарантировать работу каждого сервера, маршрута, DNS-резолвера, оператора связи или модифицированной прошивки Android. Обновления устанавливаются только после действия пользователя и системного подтверждения Android.\n\n## Обратная связь\n\nВопросы по клиенту и документам, сообщения об ошибках и пожелания можно отправить разработчикам: **https://t.me/etonify?direct**.\n\nПродолжая, вы подтверждаете, что прочитали эти условия и принимаете ответственность за использование клиента.';

  @override
  String get legalPrivacyBody =>
      '# Политика конфиденциальности Etonify\n\n## Коротко\n\nВ Etonify **нет рекламы, аналитических SDK и скрытого трекинга**. MeowTeam не продаёт пользовательские данные и не получает ваши VPN-ключи автоматически.\n\n## Что хранится на устройстве\n\nЛокально сохраняются подписки, профили, выбранные серверы, настройки, диагностические логи и скачанные пользователем файлы правил. Резервная копия или экспорт могут содержать ключи доступа — храните такие файлы приватно.\n\n## Когда приложение обращается в сеть\n\n- При импорте и обновлении подписки запрос отправляется по указанному пользователем адресу. Владелец этого сервера видит обычные данные сетевого запроса, включая IP-адрес.\n- Проверка обновлений клиента и правил обращается к GitHub и указанным в интерфейсе источникам.\n- HWID отправляется подписочному сервису только для профилей, где пользователь разрешил эту функцию.\n\n## Разрешения Android\n\n- **VPN service** создаёт системный VPN-туннель.\n- **QUERY_ALL_PACKAGES** используется только для показа установленных приложений в раздельной маршрутизации. Список приложений не отправляется MeowTeam.\n- **Камера** используется только для сканирования QR-кодов.\n- **Уведомления** показывают состояние VPN-сервиса.\n- **Установка APK** используется только для обновления, которое подтвердил пользователь. Android отдельно показывает системное окно установки.\n\n## Логи и обращения\n\nЛоги создаются для диагностики и хранятся локально, пока пользователь сам их не экспортирует или не отправит. Перед публичной отправкой проверьте содержимое файла. Данные, добровольно отправленные в Telegram, обрабатываются по правилам Telegram.\n\nВопросы о конфиденциальности можно отправить напрямую разработчикам: **https://t.me/etonify?direct**.';

  @override
  String get coreVersionLabel => 'Версия ядра';

  @override
  String get debugMenuTitle => 'Отладка';

  @override
  String get debugMenuSubtitle =>
      'Скрытый раздел для отладки и служебных действий.';

  @override
  String get debugNetworkHeartbeatTitle => 'Проверка сети';

  @override
  String debugNetworkHeartbeatSubtitle(int seconds) {
    return 'Повторно закрепляет сеть по умолчанию, если Android пропустил callback. Текущий интервал: $seconds с. Применится при следующем запуске VPN.';
  }

  @override
  String get debugWakeLockTitle => 'Частичный wake lock';

  @override
  String get debugWakeLockSubtitle =>
      'Держит CPU активным во время VPN. По умолчанию выключен, потому что на агрессивных прошивках может греть телефон.';

  @override
  String get debugRecordSnapshot => 'Записать снимок производительности';

  @override
  String get debugSnapshotDone => 'Снимок производительности добавлен в логи';

  @override
  String get debugRuntimeMeasurementTitle => 'Измерение работы в фоне';

  @override
  String get debugRuntimeMeasurementSubtitle =>
      'Раз в 5 секунд измеряет CPU, память, задачи ядра, соединения и трафик VPN. Работает только после запуска и не меняет маршрутизацию VPN.';

  @override
  String debugRuntimeMeasurementDuration(String duration) {
    return 'Длительность: $duration';
  }

  @override
  String debugRuntimeMeasurementProgress(String elapsed, String duration) {
    return 'Идёт: $elapsed из $duration';
  }

  @override
  String get debugRuntimeMeasurementStart => 'Запустить измерение';

  @override
  String get debugRuntimeMeasurementStop => 'Остановить измерение';

  @override
  String get debugRuntimeMeasurementSave => 'Сохранить отчёт';

  @override
  String get debugRuntimeMeasurementIdle => 'Готово к измерению';

  @override
  String get debugRuntimeMeasurementCompleted => 'Измерение завершено';

  @override
  String get debugRuntimeMeasurementStopped => 'Измерение остановлено';

  @override
  String get debugRuntimeMeasurementCollecting => 'Собираем данные…';

  @override
  String get debugRuntimeMeasurementHealthy =>
      'За время измерения аномального роста ресурсов не найдено.';

  @override
  String get debugRuntimeMeasurementHighCpu =>
      'Высокий CPU при низком трафике VPN. Вероятна фоновая работа native-части или ядра, а не обычная передача данных.';

  @override
  String get debugRuntimeMeasurementGoroutineGrowth =>
      'Количество задач ядра выросло во время измерения.';

  @override
  String get debugRuntimeMeasurementMemoryGrowth =>
      'Память процесса заметно выросла во время измерения.';

  @override
  String get debugRuntimeMeasurementConnectionChurn =>
      'При низком трафике было много соединений ядра.';

  @override
  String get debugRuntimeMeasurementUnavailable =>
      'Пока недостаточно данных для оценки.';

  @override
  String get debugRuntimeMeasurementSaved =>
      'Отчёт измерения готов к сохранению';

  @override
  String get teamPageTitle => 'MeowTeam';

  @override
  String get teamIntroTitle => 'Команда Etonify';

  @override
  String get teamIntroBody =>
      'MeowTeam — два разработчика, которые вместе развивают Etonify, ядро и сетевые компоненты как независимый открытый проект.';

  @override
  String get teamTimelineForkTitle => 'Ранняя разработка клиента';

  @override
  String get teamTimelineForkBody =>
      'Первые тестовые версии помогли определить Android runtime, работу с подписками, диагностику и интерфейс, которые теперь поддерживает Etonify.';

  @override
  String get teamTimelineRefactorTitle => 'Большой рефактор';

  @override
  String get teamTimelineRefactorBody =>
      'Мы постепенно разделили большой старый код на отдельные части, упростили управление VPN и добавили проверки критических сценариев.';

  @override
  String get teamTimelineCoreTitle => 'Переход на etonify-core';

  @override
  String get teamTimelineCoreBody =>
      'После MeowSingBox клиент перешёл на более стабильную базу sing-box с изменениями, необходимыми Etonify. Собственное ядро упрощает обновления и тестирование, а доработки URLTest, переключения серверов и очистки ресурсов улучшают повседневную работу клиента.';

  @override
  String get teamTimelineNowTitle => 'Etonify сейчас';

  @override
  String get teamTimelineNowBody =>
      'Etonify продолжает развиваться: мы упрощаем UX, улучшаем стабильность Android и убираем технический долг, сохраняя быстрый VPN-опыт.';

  @override
  String get teamDeveloperDdosxdRole => 'Ядро, сеть и собственные протоколы';

  @override
  String get teamDeveloperYamixdevRole =>
      'Android-клиент, интерфейс, ядро и релизы';

  @override
  String get teamTelegramRole => 'Официальный канал и новости релизов';

  @override
  String get languageSettingTitle => 'Язык';

  @override
  String get themeSettingTitle => 'Тема';

  @override
  String get accentColorTitle => 'Акцент';

  @override
  String get appearanceTitle => 'Оформление';

  @override
  String get languageSystem => 'Системный';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeAmoled => 'AMOLED';

  @override
  String get aboutResourcesTitle => 'Ресурсы';

  @override
  String get aboutResourcesSubtitle =>
      'Снимок Android и ядра по запросу. CPU появится после второго обновления.';

  @override
  String get aboutResourcePss => 'Память';

  @override
  String get aboutResourceNativeHeap => 'Native heap';

  @override
  String get aboutResourceJavaHeap => 'Java heap';

  @override
  String get aboutResourceCoreMemory => 'Память ядра';

  @override
  String get aboutResourceCoreGoroutines => 'Горутины ядра';

  @override
  String get aboutResourceCoreConnections => 'Соединения ядра (вход. / исход.)';

  @override
  String get aboutResourceProcessCpu => 'CPU процесса с прошлого обновления';

  @override
  String get aboutResourceSystemMemory => 'Свободная RAM системы';

  @override
  String get aboutResourceBatteryTemp => 'Температура батареи';

  @override
  String get updatesTitle => 'Обновления';

  @override
  String get updatesSubtitle =>
      'Проверка GitHub Releases и скачивание APK под устройство.';

  @override
  String get updatesChecking => 'Проверка обновлений…';

  @override
  String get updatesCheckAction => 'Проверить';

  @override
  String get updatesRetryAction => 'Повторить';

  @override
  String get updatesUnsupportedAndroidTitle => 'Обновление не поддерживается';

  @override
  String updatesUnsupportedAndroidSubtitle(String version, int minSdk) {
    return 'Версия $version требует Android SDK $minSdk или новее. Для этого устройства останется доступна последняя совместимая версия.';
  }

  @override
  String get updatesDownloadAction => 'Скачать обновление';

  @override
  String get updatesInstallAction => 'Установить APK';

  @override
  String get updatesDownloadWarning =>
      'Не закрывайте Etonify до завершения загрузки.';

  @override
  String get updatesOpeningInstaller => 'Открываем системный установщик…';

  @override
  String get updatesInstallPermissionHint =>
      'Разрешите установку APK для Etonify, затем нажмите «Установить APK» ещё раз.';

  @override
  String get updatesInstallPermissionTitle => 'Нужно разрешение';

  @override
  String get updatesInstallPermissionMessage =>
      'Чтобы Etonify мог открыть установку скачанного APK, разрешите установку неизвестных приложений для клиента. Без этого можно только скачать файл вручную.';

  @override
  String get updatesInstallPermissionOpen => 'Открыть настройки';

  @override
  String get updatesInstallPermissionGranted =>
      'Разрешение на установку APK включено.';

  @override
  String get updatesInstallModeTitle => 'Установка обновлений';

  @override
  String get updatesInstallModeAsk => 'Спрашивать каждый раз';

  @override
  String get updatesInstallModeAskSubtitle =>
      'Перед скачиванием Etonify предложит ручную или автоматическую установку.';

  @override
  String get updatesInstallModeManual => 'Вручную';

  @override
  String get updatesInstallModeManualSubtitle =>
      'Клиент скачает APK и покажет кнопку установки.';

  @override
  String get updatesInstallModeAuto => 'Автоматически';

  @override
  String get updatesInstallModeAutoSubtitle =>
      'Клиент скачает APK и сразу откроет системный установщик.';

  @override
  String get updatesInstallMethodTitle => 'Как установить обновление?';

  @override
  String get updatesInstallMethodManualTitle => 'Скачать вручную';

  @override
  String get updatesInstallMethodManualSubtitle =>
      'APK сохранится в кэше обновлений. Установку можно запустить позже.';

  @override
  String get updatesInstallMethodAutoTitle => 'Скачать и установить';

  @override
  String get updatesInstallMethodAutoSubtitle =>
      'После загрузки Etonify сразу откроет системный установщик Android.';

  @override
  String get updatesInstallMethodRemember => 'Запомнить выбор';

  @override
  String get updatesApkVerificationTitle => 'Проверка APK';

  @override
  String get updatesApkVerificationVerified => 'SHA-256 совпадает';

  @override
  String get updatesApkVerificationUnavailable => 'SHA-256 не указан в релизе';

  @override
  String get updatesApkVerificationFailed => 'SHA-256 не совпадает';

  @override
  String get updatesDownloadedFileMissing =>
      'Файл обновления не найден. Скачайте APK заново.';

  @override
  String get updatesDeleteCachedApkAction => 'Удалить установочный APK';

  @override
  String get updatesDeleteCachedApkTitle => 'Удалить установочный APK?';

  @override
  String updatesDeleteCachedApkMessage(Object version) {
    return 'Будет удалён скачанный APK обновления $version и старые временные APK-файлы Etonify из кэша приложения.';
  }

  @override
  String updatesDeleteCachedApkDone(int count) {
    return 'Кэш обновлений очищен. Удалено файлов: $count.';
  }

  @override
  String get updatesUpToDateTitle => 'Etonify обновлён';

  @override
  String updatesUpToDateSubtitle(String version) {
    return 'Установленная версия: $version';
  }

  @override
  String get updatesAvailableTitle => 'Доступно обновление';

  @override
  String updatesAvailableSubtitle(String version, String size) {
    return '$version · $size';
  }

  @override
  String get updatesAvailableSnack => 'Доступно обновление клиента';

  @override
  String updatesAvailableSnackVersion(Object version) {
    return 'Доступно обновление клиента $version';
  }

  @override
  String get updatesOpenAction => 'Открыть';

  @override
  String get updatesDownloadingTitle => 'Скачиваем обновление';

  @override
  String get updatesStageCleaning => 'Очищаем старые файлы…';

  @override
  String get updatesStageVerifying => 'Проверяем APK и подпись…';

  @override
  String get updatesDownloadedTitle => 'Обновление скачано';

  @override
  String updatesDownloadedSubtitle(String fileName) {
    return 'Сохранено в кэше обновлений: $fileName';
  }

  @override
  String get updatesErrorTitle => 'Не удалось проверить обновления';

  @override
  String get updatesErrorSubtitle =>
      'Если GitHub заблокирован в этой сети, Etonify попробует снова завтра.';

  @override
  String get updatesCurrentVersion => 'Текущая версия';

  @override
  String get updatesLatestVersion => 'Новая версия';

  @override
  String get updatesAsset => 'APK';

  @override
  String updatesLastChecked(String time) {
    return 'Проверено: $time';
  }

  @override
  String get updatesReleaseNotesTitle => 'Что нового';

  @override
  String get updatesNoReleaseNotes => 'В релизе нет описания изменений.';

  @override
  String updatesProgressBytes(String downloaded, String total) {
    return '$downloaded / $total';
  }

  @override
  String updatesProgressSpeedEta(String speed, String eta) {
    return '$speed/с · осталось $eta';
  }

  @override
  String updatesEtaSeconds(int seconds) {
    return '$seconds с';
  }

  @override
  String updatesEtaMinutes(int minutes, int seconds) {
    return '$minutes мин $seconds с';
  }

  @override
  String get updatesUnknownSize => 'Размер неизвестен';

  @override
  String get appVersionLabel => 'Версия клиента';

  @override
  String get currentProfileLabel => 'Текущий профиль';

  @override
  String get selectedProxyLabel => 'Выбранный прокси';

  @override
  String get onboardingStatusLabel => 'Стартовый экран';

  @override
  String get onboardingSeen => 'Завершён';

  @override
  String get showOnboardingAgain => 'Показать стартовый экран снова';

  @override
  String get settingsFootnote =>
      'Эти настройки локальны для этого устройства и хранятся в Hive.';

  @override
  String get connected => 'Подключено';

  @override
  String get tapToConnect => 'Нажмите для подключения';

  @override
  String get resolvingIp => 'Определяем IP…';

  @override
  String get millisecondsUnit => ' мс';

  @override
  String get refreshLatency => 'Обновить задержку';

  @override
  String get checkingLatency => 'Проверка задержки';

  @override
  String get checkingLatencyShort => 'Проверка…';

  @override
  String get openTrafficDashboard => 'Открыть мониторинг трафика';

  @override
  String get refreshActiveSubscription => 'Обновить текущую подписку';

  @override
  String get refreshActiveSubscriptionUnavailable =>
      'Ручной импорт нельзя обновить';

  @override
  String activeSubscriptionRefreshComplete(String name) {
    return '$name обновлена';
  }

  @override
  String get trafficDashboardTitle => 'Мониторинг трафика';

  @override
  String get trafficDashboardSubtitle =>
      'Скорость, трафик за сессию и данные подключения';

  @override
  String get trafficDashboardDownload => 'Загрузка';

  @override
  String get trafficDashboardUpload => 'Отдача';

  @override
  String get trafficDashboardSessionTraffic => 'Трафик сессии';

  @override
  String get trafficDashboardConnectedFor => 'Время работы';

  @override
  String get trafficDashboardGraphTitle => 'Трафик в реальном времени';

  @override
  String trafficDashboardGraphMax(String speed) {
    return 'Пик $speed';
  }

  @override
  String get trafficDashboardNoSamples => 'Ждём данные трафика';

  @override
  String get trafficDashboardConnectionState => 'Подключение';

  @override
  String get trafficDashboardCurrentProfile => 'Профиль';

  @override
  String get trafficDashboardActiveProxy => 'Прокси';

  @override
  String get trafficDashboardServerIp => 'IP сервера';

  @override
  String get trafficDashboardDownloadTotal => 'Скачано';

  @override
  String get trafficDashboardUploadTotal => 'Отдано';

  @override
  String get trafficDashboardStateConnected => 'Подключено';

  @override
  String get trafficDashboardStateConnecting => 'Подключаемся';

  @override
  String get trafficDashboardStateDisconnected => 'Отключено';

  @override
  String trafficDashboardUptimeHours(int hours, int minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String trafficDashboardUptimeMinutes(int minutes, int seconds) {
    return '$minutes мин $seconds с';
  }

  @override
  String trafficDashboardUptimeSeconds(int seconds) {
    return '$seconds с';
  }

  @override
  String get notAvailableShort => 'н/д';

  @override
  String daysLeft(int days) {
    return 'Осталось $days дн.';
  }

  @override
  String get daysLeftUnlimited => 'Осталось ∞ дн.';

  @override
  String get unlimitedTraffic => 'Безлимит';

  @override
  String get unlimitedSymbol => '∞';

  @override
  String get welcomeGreeting => 'Привет';

  @override
  String get welcomeTitlePrefix => 'Добро пожаловать в';

  @override
  String get welcomeSubtitle => 'Быстрый Android VPN-клиент';

  @override
  String get welcomeTapHint => 'нажмите, чтобы продолжить';

  @override
  String get hapticTitle => 'Вибрация';

  @override
  String get hapticSubtitle => 'Лёгкая вибрация для важных действий';

  @override
  String get statusNotificationTitle => 'Статус в уведомлении';

  @override
  String get statusNotificationSubtitle =>
      'Показывает выбранный сервер, скорость и пинг при активном VPN.';

  @override
  String get notificationTrafficDisplayTitle => 'Что показывать в уведомлении';

  @override
  String get notificationTrafficDisplaySubtitle =>
      'Скорость, общий объём или оба значения.';

  @override
  String get notificationTrafficDisplaySpeed => 'Текущая скорость';

  @override
  String get notificationTrafficDisplayTotal => 'Всего передано';

  @override
  String get notificationTrafficDisplayBoth => 'Скорость и общий объём';

  @override
  String get notificationTrafficRefreshTitle => 'Обновление трафика';

  @override
  String get notificationTrafficRefreshSubtitle =>
      'Как часто обновлять данные в уведомлении.';

  @override
  String notificationTrafficRefreshSeconds(int seconds) {
    return '$seconds с';
  }

  @override
  String get notificationConnected => 'VPN подключён';

  @override
  String get notificationPingChecking => '...';

  @override
  String get notificationPingUnavailable => 'Пинг недоступен';

  @override
  String get notificationRefreshPingAction => 'Проверить пинг';

  @override
  String get notificationStopAction => 'Остановить';

  @override
  String get hideServerIpTitle => 'Скрывать IP сервера';

  @override
  String get hideServerIpSubtitle => 'Маскирует последние два октета IP-адреса';

  @override
  String get performanceModeTitle => 'Режим производительности';

  @override
  String get performanceModeCool => 'Cool';

  @override
  String get performanceModeStandard => 'Стандартный';

  @override
  String get performanceModeEconomy => 'Эконом';

  @override
  String get performanceModeBalanced => 'Balanced';

  @override
  String get performanceModePerformance => 'Performance';

  @override
  String get performanceModeCoolSubtitle =>
      'Минимальный нагрев и фоновая нагрузка для ежедневного Android-режима.';

  @override
  String get performanceModeStandardSubtitle =>
      'Стабильный ежедневный режим: авто-пинг раз в 5 минут, умеренная параллельность и меньше фоновой нагрузки.';

  @override
  String get performanceModeEconomySubtitle =>
      'Минимум лишних фоновых задач: авто-пинг раз в 5 минут, меньше параллельных проверок и без авто-геолокации серверов.';

  @override
  String get performanceModeBalancedSubtitle =>
      'Умеренные проверки и расход батареи.';

  @override
  String get performanceModePerformanceSubtitle =>
      'Более быстрые проверки, но выше CPU, трафик и нагрев.';

  @override
  String get performanceModeRecommendation =>
      'Рекомендуем оставлять стандартный режим. Эконом стоит включать, когда важнее батарея, чем быстрые фоновые проверки.';

  @override
  String get memoryLimitTitle => 'Ограничение памяти';

  @override
  String get memoryLimitEnabledSubtitle =>
      'Рекомендуется. sing-box остановится раньше, чем нехватка памяти начнёт ломать работу приложения. Изменение вступит в силу после перезапуска приложения.';

  @override
  String get memoryLimitDisabledSubtitle =>
      'Выключено. Может помочь при ложной ошибке лимита памяти, но повышает расход RAM и риск вылета. Вступит в силу после перезапуска приложения.';

  @override
  String get memoryLimitDisableWarningTitle => 'Выключить ограничение памяти?';

  @override
  String get memoryLimitDisableWarningMessage =>
      'Используйте это только если VPN не запускается с ошибкой лимита памяти. Без лимита может вырасти расход RAM, нагрев и шанс, что Android закроет приложение. Изменение вступит в силу после перезапуска Etonify.';

  @override
  String get memoryLimitDisableConfirm => 'Выключить';

  @override
  String get enableInboundTitle => 'Включить';

  @override
  String get vpnInDescription =>
      'VPN TUN — системный Android VPN для трафика телефона. Приложения могут видеть Android VPN, а правила решают, что идёт через прокси или напрямую.';

  @override
  String get vpnInboundEnabledSubtitle =>
      'Создаёт VPN TUN-вход и маршрутизирует трафик через него';

  @override
  String get inboundNoneEnabled =>
      'Включите VPN TUN или Proxy In перед запуском.';

  @override
  String get mtuTitle => 'MTU';

  @override
  String get mtuSubtitle => 'Размер пакета TUN-интерфейса';

  @override
  String get strictRouteTitle => 'Не допускать обход VPN';

  @override
  String get strictRouteSubtitle =>
      'Жёстко направляет трафик через VPN и снижает шанс утечек мимо туннеля';

  @override
  String get tunImplementationTitle => 'Реализация TUN';

  @override
  String get tunImplementationSubtitle => 'Способ обработки TUN внутри клиента';

  @override
  String get tunImplementationMixed => 'Mixed';

  @override
  String get tunImplementationMixedSubtitle =>
      'Автоматический режим. Выбирает более безопасный стек для текущего устройства и конфига.';

  @override
  String get tunImplementationSystem => 'System';

  @override
  String get tunImplementationSystemSubtitle =>
      'Системный Android-стек. Обычно легче, но зависит от прошивки устройства.';

  @override
  String get tunImplementationGvisor => 'gVisor';

  @override
  String get tunImplementationGvisorSubtitle =>
      'Пользовательский сетевой стек. Может быть совместимее, но иногда сильнее грузит CPU.';

  @override
  String get proxyInDescription =>
      'Proxy In / mixed — локальный HTTP/SOCKS вход для приложений или устройств, которые настроены вручную. Это не системный Android VPN.';

  @override
  String get proxyInboundEnabledSubtitle =>
      'Поднимает локальный mixed-inbound для приложений и устройств';

  @override
  String get allowLanConnectionsTitle =>
      'Разрешить соединения из локальной сети';

  @override
  String get allowLanConnectionsSubtitle =>
      'Если включено, слушать на 0.0.0.0, иначе на 127.0.0.1';

  @override
  String get portTitle => 'Порт';

  @override
  String get proxyPortSubtitle => 'Порт локального mixed-inbound';

  @override
  String get connectionModeTitle => 'Режим подключения';

  @override
  String get connectionModeSubtitle =>
      'VPN работает для всего телефона. Локальный прокси используется только приложениями и устройствами, где адрес прокси указан вручную.';

  @override
  String get connectionModeVpn => 'VPN';

  @override
  String get connectionModeVpnSubtitle =>
      'Системный Android VPN для всего трафика телефона';

  @override
  String get connectionModeProxy => 'Прокси';

  @override
  String get connectionModeProxySubtitle =>
      'Локальный HTTP/SOCKS без системного VPN';

  @override
  String connectionModeActiveStatus(String mode) {
    return 'Активно: $mode';
  }

  @override
  String get connectionModeVpnStatusName => 'VPN TUN';

  @override
  String get connectionModeProxyStatusName => 'Прокси';

  @override
  String get advancedTunTitle => 'Расширенные параметры TUN';

  @override
  String get advancedTunSubtitle =>
      'MTU, защита маршрутов и реализация сетевого стека';

  @override
  String get localProxyTitle => 'Локальный прокси';

  @override
  String get localProxySubtitle =>
      'Дополнительный HTTP/SOCKS-вход для ручной настройки приложений';

  @override
  String get lanProxySecurityTitle => 'Доступ защищён';

  @override
  String get lanProxySecuritySubtitle =>
      'Устройства в локальной сети должны указать логин и пароль. Авторизация запрещает постороннее использование, но сама по себе не шифрует локальную сеть.';

  @override
  String get proxyUsernameTitle => 'Логин';

  @override
  String get proxyUsernameSubtitle =>
      'От 1 до 64 символов, без пробелов и двоеточия';

  @override
  String get proxyPasswordTitle => 'Пароль';

  @override
  String get regenerateProxyPasswordTitle => 'Сменить пароль';

  @override
  String get copyProxyCredentialsTitle => 'Копировать данные подключения';

  @override
  String get proxyCredentialsCopied => 'Данные прокси скопированы';

  @override
  String get proxyEndpointTitle => 'Адрес';

  @override
  String get proxyLanAddressHint => 'IP телефона';

  @override
  String get dnsUsePresetTitle => 'Использовать пресет';

  @override
  String get dnsResolverTitle => 'Резолвер';

  @override
  String get dnsDirectPresetSubtitle => 'Рекомендуется udp://1.1.1.1';

  @override
  String get dnsDirectResolverSubtitle => 'DNS для прямых запросов без прокси';

  @override
  String get dnsProxyPresetSubtitle =>
      'Рекомендуется https://dns.cloudflare.com/dns-query';

  @override
  String get dnsProxyResolverSubtitle => 'DNS для запросов через прокси';

  @override
  String get dnsResolverTypeTitle => 'Вариант резолвера';

  @override
  String get dnsPresetDevice => 'Сеть устройства';

  @override
  String get dnsPresetCustom => 'Свой';

  @override
  String get dnsPresetDeviceSubtitle =>
      'Использовать DNS текущей Android-сети.';

  @override
  String get dnsPresetCustomSubtitle =>
      'Введите IP/хост (по умолчанию UDP) либо используйте udp://, tcp://, tls:// или https://.';

  @override
  String get dnsPresetUdpSubtitle =>
      'Обычный UDP DNS. Быстрый, но без шифрования.';

  @override
  String get dnsPresetTcpSubtitle =>
      'Обычный TCP DNS. На некоторых сетях стабильнее, но без шифрования.';

  @override
  String get dnsPresetTlsSubtitle =>
      'DNS over TLS. Шифрованный DNS на порту 853.';

  @override
  String get dnsPresetHttpsSubtitle =>
      'DNS over HTTPS. Шифрованный DNS через HTTPS, часто лучше через прокси.';

  @override
  String get dnsPreferIpv6Title => 'Предпочитать IPv6';

  @override
  String get dnsPreferIpv6Subtitle =>
      'Приоритет IPv6, если доступны обе версии адреса';

  @override
  String get urlTestUrlTitle => 'URL проверки';

  @override
  String get urlTestUrlSubtitle =>
      'Если в подписке задано своё значение, используется оно';

  @override
  String get urlTestIntervalTitle => 'Интервал, сек.';

  @override
  String get urlTestIntervalSubtitle =>
      'Частота проверки прокси для автоматического выбора';

  @override
  String get urlTestTimeoutTitle => 'Таймаут проверки, сек.';

  @override
  String get urlTestTimeoutSubtitle =>
      'Сколько ждать ответа от одного прокси перед ошибкой';

  @override
  String get urlTestConcurrencyTitle => 'Поточность проверки';

  @override
  String get urlTestConcurrencySubtitle =>
      'Сколько прокси URLTest проверяет одновременно';

  @override
  String get urlTestSingleRetestTitle => 'Быстрая перепроверка, сек.';

  @override
  String get urlTestSingleRetestSubtitle =>
      'Через сколько сделать одну быструю перепроверку после сбоя прокси';

  @override
  String get locationLookupTitle => 'Локации';

  @override
  String get locationLookupSubtitle => 'IP и страна через сами прокси';

  @override
  String get locationLookupLimitTitle => 'Проверять лучших прокси';

  @override
  String get locationLookupLimitSubtitle =>
      'После URLTest приложение определит внешний IP и страну у этого количества самых быстрых аутбаундов';

  @override
  String get locationLookupTimeoutTitle => 'Таймаут запроса';

  @override
  String get locationLookupTimeoutSubtitle =>
      'Сколько ждать внешний IP и страну для одного сервера';

  @override
  String get locationLookupConcurrencyTitle => 'Параллельные запросы';

  @override
  String get locationLookupConcurrencySubtitle =>
      'Сколько запросов локации можно выполнять одновременно';

  @override
  String settingsSecondsShort(int seconds) {
    return '$seconds сек.';
  }

  @override
  String get serverRequestTitle => 'Запрос к серверу';

  @override
  String get sendHwidTitle => 'Отправлять HWID';

  @override
  String get sendHwidSubtitle => 'Нужно некоторым Happ-подпискам';

  @override
  String get useCustomHwidTitle => 'Задать свой HWID';

  @override
  String get useCustomHwidSubtitle => 'Вместо HWID этого устройства';

  @override
  String get customUserAgentTitle => 'Свой User-Agent';

  @override
  String get customUserAgentSubtitle =>
      'Переопределяет стандартный Etonify user-agent для этой подписки';

  @override
  String get customHwidTitle => 'Свой HWID';

  @override
  String get customHwidSubtitle =>
      'Оставьте пустым, чтобы использовать HWID устройства';

  @override
  String get customRequestHeadersTitle => 'Свои заголовки';

  @override
  String get customRequestHeadersSubtitle =>
      'По одному заголовку на строку в формате Header: value';

  @override
  String get hwidTitle => 'HWID';

  @override
  String get hwidSubtitle =>
      'Идентификатор устройства, который используют некоторые провайдеры подписок';

  @override
  String get hwidValueTitle => 'Ваш HWID';

  @override
  String get coreStartFailedTitle => 'Не удалось запустить ядро';

  @override
  String coreStartFailedMessage(String message) {
    return 'Не удалось запустить sing-box.\n\n$message';
  }

  @override
  String get vpnStopFailed =>
      'VPN не удалось полностью выключить. Открой логи и попробуй ещё раз.';

  @override
  String get clearLogsTitle => 'Очистить логи';

  @override
  String get logsFilterTitle => 'Фильтр';

  @override
  String get logsFilterAll => 'Все';

  @override
  String get singBoxLogLevelTitle => 'Уровень логов sing-box';

  @override
  String get logLevelTrace => 'Trace';

  @override
  String get logLevelDebug => 'Debug';

  @override
  String get logLevelInfo => 'Info';

  @override
  String get logLevelWarning => 'Warning';

  @override
  String get logLevelError => 'Error';

  @override
  String get noLogsTitle => 'Логов пока нет';

  @override
  String get continueLabel => 'Начать';

  @override
  String get subscriptionsTab => 'Подписки';

  @override
  String get subscriptionsTitle => 'Подписки';

  @override
  String get settingsProfilesChecksTitle => 'Профили и проверка';

  @override
  String get settingsProfilesChecksSubtitle =>
      'Проверка серверов · HWID · параметры профилей';

  @override
  String get addSubscription => 'Добавить подписку';

  @override
  String get addSubscriptionQuickTitle => 'Добавить профиль';

  @override
  String get addSubscriptionQuickSubtitle =>
      'Выберите способ импорта подписки.';

  @override
  String get addSubscriptionFromClipboard => 'Буфер обмена';

  @override
  String get addSubscriptionManual => 'Вручную';

  @override
  String get addSubscriptionReadingClipboard => 'Читаем буфер обмена…';

  @override
  String get addSubscriptionReadingFile => 'Читаем файл…';

  @override
  String get addSubscriptionImporting => 'Импортируем подписку…';

  @override
  String get addSubscriptionSaving => 'Сохраняем профиль…';

  @override
  String get addSubscriptionDone => 'Подписка добавлена';

  @override
  String get clipboardEmpty => 'Буфер обмена пуст';

  @override
  String get scanQrCode => 'Сканировать QR';

  @override
  String get showQrCode => 'Показать QR';

  @override
  String get subscriptionQrTitle => 'QR подписки';

  @override
  String get subscriptionQrHint =>
      'Отсканируйте этот код на другом устройстве, чтобы импортировать подписку.';

  @override
  String get subscriptionQrUnsupported =>
      'Эту подписку пока нельзя показать как QR.';

  @override
  String get invalidQrSubscription =>
      'В QR-коде нет поддерживаемой ссылки подписки.';

  @override
  String get subscriptionUrl => 'URL подписки';

  @override
  String get editSubscriptionUrlAction => 'Изменить URL';

  @override
  String get saveAction => 'Сохранить';

  @override
  String get subscriptionUrlEditHint =>
      'Профиль обновляется по одному URL. Если старый импорт склеил несколько ссылок, оставьте нужную строку, а остальные источники добавьте отдельными профилями. После сохранения обновите подписку.';

  @override
  String get subscriptionUrlSingleSourceRequired =>
      'Оставьте один URL. Остальные источники добавьте отдельными профилями.';

  @override
  String get subscriptionUrlOrContent => 'URL или содержимое';

  @override
  String get subscriptionUrlOrContentHint =>
      'Вставьте URL, vless://, пачку ссылок или конфиг';

  @override
  String get importFromFile => 'Из файла';

  @override
  String get invalidSubscriptionFile => 'Не удалось прочитать файл подписки';

  @override
  String get backupUseSettingsImport =>
      'Это резервная копия Etonify. Импортируйте её через Настройки → Импорт.';

  @override
  String get subscriptionName => 'Название (необязательно)';

  @override
  String get add => 'Добавить';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get refresh => 'Обновить';

  @override
  String get reparseProxies => 'Перепарсить прокси';

  @override
  String get subscriptionLocalImportBadge => 'Локальный импорт';

  @override
  String get refreshAll => 'Обновить все';

  @override
  String get refreshSubscriptions => 'Обновить подписки';

  @override
  String get subscriptionSortTitle => 'Сортировка подписок';

  @override
  String get subscriptionSortManual => 'Текущий порядок';

  @override
  String get subscriptionSortByName => 'По названию';

  @override
  String get subscriptionSortByUpdated => 'По обновлению';

  @override
  String get subscriptionSortByServers => 'По количеству прокси';

  @override
  String get subscriptionActionsTitle => 'Действия подписки';

  @override
  String get subscriptionCopyUrl => 'URL в буфер обмена';

  @override
  String get subscriptionShowUrlQr => 'Показать QR-код URL';

  @override
  String get subscriptionCopyJson => 'JSON в буфер обмена';

  @override
  String get subscriptionUrlCopied => 'URL подписки скопирован';

  @override
  String get subscriptionJsonCopied => 'JSON подписки скопирован';

  @override
  String get subscriptionImportHelpTitle => 'Как добавить подписку';

  @override
  String get subscriptionImportHelpBody =>
      'Скопируйте ссылку подписки у своего провайдера и нажмите «Буфер обмена» либо отсканируйте QR-код. Если ссылка не распознаётся, откройте «Вручную» и вставьте URL, vless:// ссылку, список ключей или sing-box/Xray конфиг. Для Happ-подписок при необходимости включите User-Agent или HWID в ручном добавлении.';

  @override
  String subscriptionsRefreshAllComplete(int updated, int failed) {
    return 'Обновлено подписок: $updated, ошибок: $failed';
  }

  @override
  String subscriptionsRefreshAllProgress(int completed, int total) {
    return 'Обновляем: $completed из $total';
  }

  @override
  String get deleteSubscription => 'Удалить подписку?';

  @override
  String get deleteSubscriptionConfirm =>
      'Все прокси из этой подписки будут удалены.';

  @override
  String get subscriptionDetailsTitle => 'Подписка';

  @override
  String get subscriptionMovedTitle => 'Подписка переехала';

  @override
  String get ignoreAction => 'Игнорировать';

  @override
  String get updateUrlAction => 'Обновить URL';

  @override
  String get autoUpdateTitle => 'Автообновление';

  @override
  String get disableAutoUpdateTitle => 'Отключить автообновление';

  @override
  String get disabledLabel => 'Отключено';

  @override
  String refreshesEvery(String interval) {
    return 'Обновляется через: $interval';
  }

  @override
  String get usageTitle => 'Использование';

  @override
  String spentTraffic(String usage) {
    return 'Потрачено $usage';
  }

  @override
  String untilDate(String date) {
    return 'До $date';
  }

  @override
  String get infoTitle => 'Информация';

  @override
  String get supportUrlLabel => 'Поддержка';

  @override
  String get websiteLabel => 'Сайт';

  @override
  String get newUrlTitle => 'NewURL';

  @override
  String get movedSubscriptionMessage =>
      'Сервер сообщил, что подписка переехала на новый URL.';

  @override
  String get movedSubscriptionPrompt =>
      'Сервер сообщает новый URL подписки. Обновить его сейчас или оставить текущий?';

  @override
  String get noSubscriptions => 'Подписок пока нет';

  @override
  String get noProxies => 'Нет прокси';

  @override
  String get noSubscriptionsHint => 'Нажмите + чтобы добавить URL подписки';

  @override
  String outboundsCount(int count) {
    return '$count прокси';
  }

  @override
  String subscriptionServersCount(int count) {
    return '$count прокси';
  }

  @override
  String get subscriptionReparseRecommended => 'Нужно перепарсить';

  @override
  String get subscriptionProxyTypeLabel => 'Прокси';

  @override
  String moreProxies(int count) {
    return '…ещё $count прокси';
  }

  @override
  String lastUpdated(String time) {
    return 'Обновлено $time';
  }

  @override
  String trafficUsage(String used, String total) {
    return '$used / $total';
  }

  @override
  String get expired => 'Истекла';

  @override
  String get loading => 'Загрузка…';

  @override
  String get error => 'Ошибка';

  @override
  String get invalidUrl => 'Введите корректный URL';

  @override
  String get fetchFailed => 'Не удалось загрузить подписку';

  @override
  String get subscriptionSavedWithFetchWarning =>
      'Подписка сохранена, но сервер не ответил. Можно поменять HWID или заголовки и обновить её позже.';

  @override
  String subscriptionSavedWithFetchWarningReason(String reason) {
    return 'Подписка сохранена без серверов. Причина: $reason Исправь ссылку, HWID или заголовки и обнови её.';
  }

  @override
  String get subscriptionErrorInvalidUrl =>
      'Ссылка подписки некорректна. Скопируй её заново и проверь, что она начинается с http:// или https://.';

  @override
  String get subscriptionErrorHttpsRequired =>
      'Эта подписка отправляет HWID или секретные данные, поэтому её можно загружать только по HTTPS.';

  @override
  String get subscriptionErrorUnsafeRedirect =>
      'Сервер попытался перенаправить подписку с HTTPS на небезопасный HTTP. Etonify заблокировал переход.';

  @override
  String get subscriptionErrorRedirect =>
      'Ссылка перенаправляет неправильно или слишком много раз. Запроси у провайдера прямую ссылку.';

  @override
  String get subscriptionErrorHttp400 =>
      'Сервер отклонил запрос (HTTP 400). Проверь ссылку и её параметры.';

  @override
  String get subscriptionErrorHttp401 =>
      'Авторизация не пройдена (HTTP 401). Токен, логин или HWID могут быть неверными.';

  @override
  String get subscriptionErrorHttp402 =>
      'Требуется оплата (HTTP 402). Продли подписку или обратись к провайдеру.';

  @override
  String get subscriptionErrorHttp403 =>
      'Доступ запрещён (HTTP 403). Подписка могла истечь, быть заблокирована или требовать правильный HWID.';

  @override
  String get subscriptionErrorHttp404 =>
      'Подписка не найдена (HTTP 404). Ссылку могли удалить или скопировать неправильно.';

  @override
  String get subscriptionErrorHttp408 =>
      'Сервер подписки не ответил вовремя (HTTP 408). Попробуй позже.';

  @override
  String get subscriptionErrorHttp410 =>
      'Подписка истекла или удалена (HTTP 410). Запроси у провайдера новую ссылку.';

  @override
  String get subscriptionErrorHttp429 =>
      'Слишком много запросов (HTTP 429). Немного подожди перед повторной попыткой.';

  @override
  String get subscriptionErrorHttp500 =>
      'Внутренняя ошибка сервера подписки (HTTP 500). Это проблема на стороне провайдера.';

  @override
  String get subscriptionErrorHttp502 =>
      'Шлюз подписки недоступен (HTTP 502). Сейчас провайдер не может связаться со своим сервером.';

  @override
  String get subscriptionErrorHttp503 =>
      'Сервис подписки временно недоступен (HTTP 503), возможно из-за технических работ.';

  @override
  String get subscriptionErrorHttp504 =>
      'Сервер провайдера не ответил вовремя (HTTP 504). Попробуй позже.';

  @override
  String subscriptionErrorHttpStatus(int status) {
    return 'Сервер подписки вернул HTTP $status. Проверь статус провайдера или запроси новую ссылку.';
  }

  @override
  String get subscriptionErrorDns =>
      'Не удалось найти сервер подписки. Проверь домен, DNS и подключение к интернету.';

  @override
  String get subscriptionErrorConnection =>
      'Не удалось подключиться к серверу подписки. Проверь интернет или попробуй позже.';

  @override
  String get subscriptionErrorTls =>
      'Не удалось установить защищённое соединение с сервером подписки. Его TLS-сертификат может быть неверным или просроченным.';

  @override
  String get subscriptionErrorEmptyResponse =>
      'Сервер вернул пустой ответ. Ссылка могла истечь либо у провайдера возникли проблемы.';

  @override
  String get subscriptionErrorHtmlResponse =>
      'Сервер вернул веб-страницу вместо подписки. Возможно, ссылка открывает страницу входа или ошибку.';

  @override
  String get subscriptionErrorResponseTooLarge =>
      'Ответ подписки слишком большой и заблокирован для защиты приложения.';

  @override
  String get subscriptionErrorNoUsableProxies =>
      'В подписке не найдено поддерживаемых прокси-серверов. Она может быть пустой, просроченной или иметь неподдерживаемый формат.';

  @override
  String get subscriptionErrorInvalidContent =>
      'Ответ сервера не является корректной подпиской. Проверь, что ссылка ведёт прямо на файл подписки.';

  @override
  String get subscriptionErrorHappInvalid =>
      'Не удалось расшифровать ссылку Happ либо внутри неё некорректный URL подписки. Скопируй свежую ссылку и попробуй снова.';

  @override
  String get subscriptionErrorUnknown =>
      'Не удалось обработать подписку. Проверь ссылку и открой диагностику — там сохранена техническая причина.';

  @override
  String get sourceLabel => 'Источник';

  @override
  String importedFromFileLabel(String name) {
    return 'Импортировано из файла: $name';
  }

  @override
  String get deepLinkImportTitle => 'Импорт подписки';

  @override
  String get deepLinkImportMessage =>
      'Вы действительно хотите импортировать эту подписку?';

  @override
  String get deepLinkImportNameLabel => 'Название';

  @override
  String get deepLinkImportAction => 'Импортировать';

  @override
  String get deepLinkImportSourceLabel => 'Исходная ссылка';

  @override
  String get deepLinkImportResolvedUrlLabel => 'Расшифрованный URL подписки';

  @override
  String get deepLinkImportHappBadge => 'Подписка Happ';

  @override
  String get deepLinkImportHappNotice =>
      'Некоторым Happ-подпискам нужен HWID. Etonify отправит его только после вашего подтверждения.';

  @override
  String get deepLinkImportHappSendHwidAction =>
      'Отправить HWID и импортировать';

  @override
  String get deepLinkImportHappWithoutHwidAction => 'Импортировать без HWID';

  @override
  String get deepLinkImportHappCancelAction => 'Не импортировать';

  @override
  String get deepLinkImportUserAgentLabel => 'User-Agent';

  @override
  String get deepLinkImportHwidLabel => 'HWID';

  @override
  String get deepLinkImportHwidValue =>
      'Будет отправлен только после подтверждения';

  @override
  String deepLinkImportSuccess(String name) {
    return 'Подписка \"$name\" импортирована';
  }

  @override
  String get happCryptoLinkImportedLabel => 'Импортировано из ссылки Happ';

  @override
  String get happCryptoLinkTitle => 'Ссылка Happ';

  @override
  String get happCryptUnsupportedTitle => 'Happ crypt5';

  @override
  String get happCryptUnsupportedMessage =>
      'Эта ссылка Happ пока не поддерживается.';

  @override
  String get happImportTitle => 'Подписка Happ';

  @override
  String get happImportMessage =>
      'Для этой Happ-подписки может понадобиться HWID. Отправьте его сейчас или попробуйте импорт без HWID.';

  @override
  String get subscriptionOperationSlowWarning =>
      'Сервер подписки отвечает дольше обычного. Если это повторяется, проверь ссылку или сеть.';

  @override
  String get subscriptionOperationTimeout =>
      'Сервер подписки не ответил вовремя. Проверь ссылку или сеть и попробуй снова.';

  @override
  String get continueAction => 'Продолжить';

  @override
  String get routingTitle => 'Маршрутизация';

  @override
  String get routingSubtitle => 'Правила маршрутизации трафика';

  @override
  String get bypassLocalNetworkTitle => 'Обход локальной сети';

  @override
  String get bypassLocalNetworkSubtitle =>
      'Направляет приватные и LAN-адреса напрямую';

  @override
  String get russiaRoutesTitle => 'Умная маршрутизация';

  @override
  String get russiaRoutesRunetFreedomBadge => 'runetfreedom';

  @override
  String get russiaRoutesDomainListBadge => 'domain-list-community';

  @override
  String get russiaRoutesSubtitle =>
      'Российские сервисы напрямую, заблокированные ресурсы — через VPN.';

  @override
  String get russiaRoutesInstallAction => 'Скачать правила';

  @override
  String get russiaRoutesReinstallAction => 'Обновить';

  @override
  String get russiaRoutesUpdateAction => 'Проверить';

  @override
  String russiaRoutesUpdateAvailable(String version) {
    return 'Доступна новая версия правил: $version';
  }

  @override
  String get russiaRoutesLatest => 'Установлена последняя версия правил.';

  @override
  String get russiaRoutesEnableTitle => 'Включить умную маршрутизацию';

  @override
  String get russiaRoutesEnabledSubtitle =>
      'Применять подготовленные правила к VPN-подключению.';

  @override
  String get russiaRoutesMissingSubtitle =>
      'Встроенная база доступна без интернета и подключится при включении.';

  @override
  String get russiaRoutesPreparingStatus => 'Обновляем правила...';

  @override
  String get russiaRoutesPreparingHint =>
      'Скачиваем свежую базу, проверяем SRS и безопасно заменяем локальные правила.';

  @override
  String get russiaRoutesStageChecking => 'Проверяем версию правил…';

  @override
  String get russiaRoutesStageDownloading => 'Скачиваем архив правил…';

  @override
  String get russiaRoutesStageVerifying => 'Проверяем целостность архива…';

  @override
  String get russiaRoutesStageExtracting => 'Распаковываем SRS-файлы…';

  @override
  String get russiaRoutesStageCategories => 'Обновляем списки сервисов…';

  @override
  String get russiaRoutesStageCompiling => 'Собираем локальные правила…';

  @override
  String get russiaRoutesStageActivating => 'Безопасно заменяем правила…';

  @override
  String get russiaRoutesStageComplete => 'Правила обновлены';

  @override
  String russiaRoutesDownloadProgress(String completed, String total) {
    return 'Загружено $completed из $total.';
  }

  @override
  String russiaRoutesItemsProgress(int completed, int total) {
    return 'Обработано списков: $completed из $total.';
  }

  @override
  String get russiaRoutesMissingStatus => 'Правила ещё не установлены';

  @override
  String get russiaRoutesMissingHint =>
      'Сначала подключим встроенную базу, затем в фоне проверим и загрузим свежую версию.';

  @override
  String get russiaRoutesReadyHint =>
      'Правила сохранены локально. Новые версии проверяются при запуске, не чаще раза в сутки.';

  @override
  String russiaRoutesReadyStatus(String versionTag) {
    return 'Готово · $versionTag';
  }

  @override
  String get russiaRoutesLiveSource => 'runetfreedom';

  @override
  String get russiaRoutesBundledSource => 'встроенная база';

  @override
  String russiaRoutesSourceMeta(
    String source,
    String verifiedAt,
    int fileCount,
  ) {
    return 'Источник: $source · $verifiedAt · файлов: $fileCount';
  }

  @override
  String russiaRoutesMeta(
    String installedAt,
    String domainListUpdatedAt,
    int categoryCount,
    int domainCount,
  ) {
    return 'runetfreedom: $installedAt · domain-list-community: $domainListUpdatedAt · категорий: $categoryCount · доменов: $domainCount';
  }

  @override
  String get adBlockTitle => 'Блокировка рекламы';

  @override
  String get adBlockSubtitle =>
      'Клиент сам скачивает локальный rule set и подключает его в routing.';

  @override
  String get adBlockDownloadAction => 'Скачать';

  @override
  String get adBlockUpdateAction => 'Обновить';

  @override
  String get adBlockEnableTitle => 'Включить локальную блокировку';

  @override
  String get adBlockEnabledSubtitle =>
      'Использовать скачанный локальный rule set для DNS и route reject.';

  @override
  String get adBlockMissingSubtitle =>
      'Сначала скачай пакет фильтра, чтобы его можно было включить.';

  @override
  String get adBlockDownloadingStatus =>
      'Скачиваем и собираем локальный фильтр...';

  @override
  String get adBlockStageConnecting => 'Подключаемся к AdGuard…';

  @override
  String get adBlockStageDownloading => 'Скачиваем список фильтра…';

  @override
  String get adBlockStageCompiling => 'Собираем локальные правила…';

  @override
  String get adBlockStageActivating => 'Безопасно заменяем правила…';

  @override
  String get adBlockStageComplete => 'Фильтр обновлён';

  @override
  String get adBlockPreparingHint => 'Подготавливаем загрузку…';

  @override
  String adBlockDownloadedProgress(String completed) {
    return 'Скачано $completed';
  }

  @override
  String adBlockDownloadProgress(String completed, String total) {
    return '$completed из $total';
  }

  @override
  String adBlockDownloadProgressEta(
    String completed,
    String total,
    int seconds,
  ) {
    return '$completed из $total · осталось около $seconds с';
  }

  @override
  String get adBlockMissingStatus => 'Фильтр ещё не скачан';

  @override
  String get adBlockMissingHint =>
      'Скачиваем список с AdGuard и сохраняем его локально для sing-box.';

  @override
  String adBlockReadyStatus(int blockedCount) {
    return 'Фильтр готов, доменов: $blockedCount';
  }

  @override
  String adBlockMeta(String updatedAt, int allowedCount) {
    return 'Обновлено: $updatedAt · исключений: $allowedCount';
  }

  @override
  String get splitRoutingTitle => 'Раздельная маршрутизация';

  @override
  String get splitRoutingSubtitle =>
      'Выберите, какие приложения работают через VPN, а какие — напрямую.';

  @override
  String get splitRoutingUnavailableTitle => 'Временно недоступно';

  @override
  String get splitRoutingUnavailableMessage =>
      'Split tunneling сейчас не работает должным образом. Мы работаем над исправлением. Следите за обновлениями!';

  @override
  String get splitRoutingTunOnly =>
      'Работает только в режиме VPN. Локальный прокси не управляет приложениями.';

  @override
  String get splitRoutingModeTitle => 'Режим';

  @override
  String get splitRoutingModeDisabled => 'Выкл';

  @override
  String get splitRoutingModeDisabledSubtitle =>
      'Раздельная маршрутизация не используется';

  @override
  String get splitRoutingModeProxySelected => 'Через VPN';

  @override
  String get splitRoutingModeProxySelectedSubtitle =>
      'Только выбранные приложения работают через VPN';

  @override
  String get splitRoutingModeBypassSelected => 'Вне VPN';

  @override
  String get splitRoutingModeBypassSelectedSubtitle =>
      'Выбранные приложения работают напрямую';

  @override
  String get splitRoutingLockdownWarning =>
      'Android Always-on VPN с опцией «Блокировать соединения без VPN» может отключить сеть у приложений, выбранных для работы вне VPN.';

  @override
  String get splitRoutingAppsTitle => 'Приложения';

  @override
  String get splitRoutingAppVisibilityNotice =>
      'Android открывает Etonify список установленных приложений только для выбора. Список остаётся на устройстве.';

  @override
  String get splitRoutingPackagesTitle => 'Имена пакетов';

  @override
  String get splitRoutingPackagesHint => 'com.termux\norg.mozilla.firefox';

  @override
  String get splitRoutingPackagesHelper =>
      'Имя пакета, например org.telegram.messenger';

  @override
  String get splitRoutingPickAppsAction => 'Выбрать приложения';

  @override
  String get splitRoutingPickAppsTitle => 'Выбор приложений';

  @override
  String get splitRoutingSearchHint => 'Поиск по приложению или имени пакета';

  @override
  String get splitRoutingAndroidOnly =>
      'Выбор приложений доступен только на Android';

  @override
  String get splitRoutingLoadAppsFailed =>
      'Не удалось загрузить список приложений';

  @override
  String splitRoutingSelectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get splitRoutingNoAppsTitle => 'Приложения ещё не выбраны';

  @override
  String get splitRoutingNoAppsSubtitle =>
      'Выберите приложения для этого режима';

  @override
  String get splitRoutingManualEditorTitle => 'Ручной список пакетов';

  @override
  String get splitRoutingManualEditorSubtitle => 'Ручной ввод имён пакетов';

  @override
  String refreshIntervalDaysShort(int count) {
    return '$count дн.';
  }

  @override
  String refreshIntervalHoursShort(int count) {
    return '$count ч.';
  }

  @override
  String refreshIntervalMinutesShort(int count) {
    return '$count мин.';
  }

  @override
  String get happCrypt5Supported => 'Доступно';

  @override
  String get happCrypt5Unsupported => 'Недоступно';

  @override
  String get happCrypt5Checking => 'Проверяем Happ crypt5...';

  @override
  String get happCrypt5SupportedDescription =>
      'Эта сборка открывает ссылки Happ crypt5.';

  @override
  String get happCrypt5UnsupportedDescription =>
      'В этой сборке нет файлов Happ crypt5. Обычные подписки работают.';

  @override
  String get subscriptionLikelyRequiresHwidTitle => 'Похоже, нужен HWID';

  @override
  String get subscriptionLikelyRequiresHwidWarning =>
      'Похоже, эта подписка требует HWID. Сервер вернул только один outbound с app/HWID в названии. Открой настройки подписки и включи отправку HWID.';

  @override
  String get subscriptionLikelyRequiresHwidMessage =>
      'Сервер вернул только один outbound, и его название похоже на заглушку про app или HWID.\n\nОбычно это значит, что подписка ожидает HWID устройства в запросе.\n\nВключить отправку HWID сейчас и сразу обновить подписку?';

  @override
  String get subscriptionLikelyRequiresHwidAction => 'Включить HWID';

  @override
  String get subscriptionHwidEnabledAndUpdated =>
      'Отправка HWID включена. Подписка обновлена.';

  @override
  String get noValidOutboundsTitle => 'Нет рабочих узлов';

  @override
  String get noValidOutboundsWarning =>
      'В этой подписке не осталось ни одного рабочего outbound. Они были отфильтрованы во время валидации. Проверь подписку или обнови её.';

  @override
  String get noValidOutboundsMessage =>
      'В этой подписке не осталось ни одного рабочего outbound.\n\nВсе узлы были отфильтрованы во время валидации ещё до запуска, поэтому клиент не будет пытаться стартовать sing-box с пустым набором прокси.\n\nПроверь подписку, обнови её или импортируй корректную.';

  @override
  String get noValidOutboundsAfterDropInvalidWarning =>
      'В выбранной подписке не осталось ни одного рабочего outbound после drop invalid. Проверь подписку, похоже с ней что-то не так.';

  @override
  String get noValidOutboundsAfterDropInvalidMessage =>
      'Все оставшиеся узлы в выбранной подписке были отброшены как невалидные во время запуска.\n\nКлиент остановился до того, как передать сломанный конфиг в sing-box.\n\nПроверь содержимое подписки и обнови или замени её.';

  @override
  String get experimentalTcpFastOpenTitle => 'TCP Fast Open';

  @override
  String get experimentalTcpFastOpenSubtitle =>
      'Может ускорить TCP handshake, но зависит от сети и поддержки сервера.';

  @override
  String get experimentalTcpMultiPathTitle => 'TCP Multipath';

  @override
  String get experimentalTcpMultiPathSubtitle =>
      'Пробует несколько сетевых путей. Может помочь при смене сети, но иногда греет телефон или работает нестабильно.';

  @override
  String get experimentalInterruptConnectionsTitle =>
      'Рвать активные соединения при смене узла';

  @override
  String get experimentalInterruptConnectionsSubtitle =>
      'Быстрее применяет смену прокси, но старые соединения приложений могут оборваться.';

  @override
  String get experimentalUrlTestStrictToleranceTitle =>
      'URLTest tolerance 1 мс';

  @override
  String get experimentalUrlTestStrictToleranceSubtitle =>
      'Строже выбирает самый быстрый прокси, но может чаще переключать сервер.';

  @override
  String get experimentalFakeIpTitle => 'Подменять DNS-ответы (FakeIP)';

  @override
  String get experimentalFakeIpSubtitle =>
      'Ускоряет обработку доменов внутри VPN TUN. Некоторые приложения могут быть несовместимы.';

  @override
  String get experimentalFakeIpUnavailableSubtitle =>
      'Доступно только в VPN TUN без раздельной маршрутизации.';

  @override
  String get tlsFragmentationTitle => 'TLS fragmentation';

  @override
  String get tlsFragmentationSubtitle =>
      'Фрагментирует TLS handshake у прокси-аутбаундов. Может помочь при DPI, но иногда замедляет подключение.';

  @override
  String get tlsFragmentationModeDisabled => 'Выключено';

  @override
  String get tlsFragmentationModeDisabledSubtitle =>
      'Не меняет TLS настройки серверов.';

  @override
  String get tlsFragmentationModeRecord => 'TLS record fragment';

  @override
  String get tlsFragmentationModeRecordSubtitle =>
      'Более мягкий режим. Сначала пробуй его.';

  @override
  String get tlsFragmentationModeFragment => 'TLS fragment';

  @override
  String get tlsFragmentationModeFragmentSubtitle =>
      'Более агрессивный режим с fallback delay 300 мс.';

  @override
  String get blockLeaksTitle => 'Исправить некоторые утечки';

  @override
  String get blockLeaksSubtitle =>
      'Блокирует только STUN/WebRTC-трафик, который может обходить прокси';

  @override
  String get addSubscriptionCaption => 'Добавьте подписку по ссылке или файлу';

  @override
  String get pasteSubscriptionLink => 'Вставьте ссылку подписки';

  @override
  String get orManually => 'Или вручную';

  @override
  String get pasteAction => 'Вставить';

  @override
  String get cancelAction => 'Отмена';

  @override
  String get settingsMenuImport => 'Импорт';

  @override
  String get settingsMenuExport => 'Экспорт';

  @override
  String get settingsResetAction => 'Сбросить настройки';

  @override
  String get settingsResetTitle => 'Сбросить настройки?';

  @override
  String get settingsResetMessage =>
      'Все настройки клиента вернутся к значениям по умолчанию. Подписки и выбранный сервер сохранятся.';

  @override
  String get settingsResetSuccess => 'Настройки сброшены';

  @override
  String get backupExportSettings => 'Экспортировать настройки';

  @override
  String get backupExportProfileEncrypted =>
      'Экспортировать подписки с паролем';

  @override
  String get backupExportProfilePlain =>
      'Экспортировать подписки без шифрования';

  @override
  String get backupPlainWarningTitle => 'Файл будет содержать VPN-ключи';

  @override
  String get backupPlainWarningMessage =>
      'Незашифрованный экспорт сможет прочитать любой, кто получит файл. Используйте шифрование, если не полностью доверяете месту хранения и передаче.';

  @override
  String get backupPlainImportTitle => 'Незашифрованный профиль';

  @override
  String get backupPlainImportMessage =>
      'Этот файл содержит подписки и VPN-ключи без шифрования. Импортируйте только если доверяете источнику.';

  @override
  String get backupPasswordCreateTitle => 'Создайте пароль для экспорта';

  @override
  String get backupPasswordEnterTitle => 'Введите пароль профиля';

  @override
  String get backupPasswordHint => 'Пароль';

  @override
  String get backupSaved => 'Файл резервной копии сохранён';

  @override
  String get backupImported => 'Импорт завершён';

  @override
  String get backupUnsupportedVersion =>
      'Этот формат резервной копии не поддерживается этой версией клиента.';

  @override
  String get backupNewerVersionTitle => 'Файл из более новой версии клиента';

  @override
  String backupNewerVersionMessage(String version) {
    return 'Этот файл создан в Etonify $version. Некоторые настройки могут примениться не полностью. Продолжить?';
  }

  @override
  String get splitRoutingEmptyWhitelist =>
      'Выберите хотя бы одно приложение или отключите раздельную маршрутизацию перед запуском VPN.';

  @override
  String get splitRoutingUnknownAppLabel => 'Приложение не найдено';

  @override
  String get splitRoutingLoadingAppLabel => 'Ищем приложение…';

  @override
  String get connectionStagePreparing => 'Подготовка VPN';

  @override
  String get connectionStageConfiguring => 'Сборка конфига';

  @override
  String get connectionStageStarting => 'Запуск ядра';

  @override
  String get connectionStageStopping => 'Остановка VPN';

  @override
  String get connectionStageRecovering => 'Восстановление';

  @override
  String get connectionStageSelectingProxy => 'Выбор сервера';

  @override
  String get vpnStartTimedOut =>
      'VPN не запустился за 15 секунд. Запуск остановлен.';

  @override
  String get vpnStartFailed => 'Не удалось запустить VPN.';

  @override
  String get trafficRulesTitle => 'Правила трафика';

  @override
  String get trafficRulesSettingsTitle => 'Правила трафика';

  @override
  String get trafficRulesSettingsSubtitle =>
      'Выберите одно проверенное правило для доменов и IP-маршрутов.';

  @override
  String get trafficRulesCurrentLabel => 'Активное правило';

  @override
  String get trafficRulesNone => 'Не выбрано';

  @override
  String get trafficRulesUsePresetTitle => 'Использовать правила трафика';

  @override
  String get trafficRulesUsePresetSubtitle =>
      'Выберите готовый пресет для маршрутизации доменов и IP-адресов.';

  @override
  String get trafficRulesUsePresetAction => 'Использовать пресет';

  @override
  String get trafficRulesDisablePreset => 'Отключить пресет';

  @override
  String get trafficRulesQuickSelection => 'Быстрый выбор';

  @override
  String get trafficRulesDeveloperSection => 'Правила от разработчика';

  @override
  String get trafficRulesDeveloperSubtitle =>
      'Проверенные пресеты с подробным составом.';

  @override
  String get trafficRulesVerified => 'Проверено';

  @override
  String get trafficRulesVerifiedInfo =>
      'Проверено MeowTeam. Создано официальным разработчиком.';

  @override
  String get trafficRulesOnlyOne =>
      'Одновременно можно включить только одно правило трафика — так правила не конфликтуют между собой.';

  @override
  String get trafficRulesAvailableOffline =>
      'После подготовки правило работает без подключения к интернету.';

  @override
  String get trafficRulesDataReady => 'Данные правила готовы';

  @override
  String get trafficRulesDataMissing => 'Данные правила ещё не подготовлены';

  @override
  String get trafficRulesUpdateData => 'Обновить данные правил';

  @override
  String get trafficRulesDeleteData => 'Удалить данные правил';

  @override
  String get trafficRulesRussianTitle => '.RU без VPN';

  @override
  String get trafficRulesRussianSubtitle =>
      'Российские сервисы и локальные адреса работают в обход VPN.';

  @override
  String get trafficRulesAiTitle => 'Нейросети через VPN';

  @override
  String get trafficRulesAiSubtitle =>
      'Популярные нейросети идут через VPN, остальной трафик — напрямую.';

  @override
  String get trafficRulesSocialTitle => 'Социальные сети через VPN';

  @override
  String get trafficRulesSocialSubtitle =>
      'Популярные соцсети и мессенджеры идут через VPN, остальной трафик — напрямую.';

  @override
  String get trafficRulesDetails => 'Состав правила';

  @override
  String get trafficRulesDescription => 'Описание';

  @override
  String get trafficRulesAuthor => 'Автор';

  @override
  String get trafficRulesRoutingDomains => 'Маршрутизация доменов';

  @override
  String get trafficRulesSettings => 'Настройки';

  @override
  String get trafficRulesRuDnsTitle => 'DNS для .RU без VPN';

  @override
  String get trafficRulesRuDnsSubtitle =>
      'Используется только для российских доменов, которые правило отправляет напрямую. По умолчанию: udp://77.88.8.8.';

  @override
  String get trafficRulesDefaultRoute => 'Всё остальное';

  @override
  String get trafficRulesDirect => 'Напрямую';

  @override
  String get trafficRulesVpn => 'Через VPN';

  @override
  String get trafficRulesIncludes => 'Включает';

  @override
  String get trafficRulesLocalNetwork =>
      'Локальная сеть всегда работает напрямую';

  @override
  String get trafficRulesChoose => 'Выбрать правило';

  @override
  String get trafficRulesChosen => 'Выбрано';

  @override
  String get trafficRulesDisabled => 'Отключено';

  @override
  String get trafficRulesPreparing => 'Подготавливаем данные правила…';

  @override
  String get trafficRulesPrepareFailed =>
      'Не удалось подготовить данные правила. Проверьте интернет и повторите попытку.';

  @override
  String get remoteDownloadConnectTimeout =>
      'Не удалось подключиться к серверу за 7 секунд. Проверьте интернет или активный VPN и повторите попытку.';

  @override
  String get remoteDownloadResponseTimeout =>
      'Сервер не начал отвечать за 7 секунд. Проверьте интернет или активный VPN и повторите попытку.';

  @override
  String get remoteDownloadIdleTimeout =>
      'Загрузка остановлена: сервер не передавал данные 7 секунд. Попробуйте ещё раз.';

  @override
  String get routingRuleFilesTitle => 'Файлы правил';

  @override
  String get routingRuleFilesSettingsTitle => 'Файлы правил';

  @override
  String routingRuleFilesSettingsReady(int count) {
    return 'Готово файлов: $count';
  }

  @override
  String get routingRuleFilesSettingsPreparing =>
      'Встроенные файлы будут подготовлены при открытии';

  @override
  String get routingRuleFilesReadyTitle => 'Файлы правил готовы';

  @override
  String get routingRuleFilesReadySubtitle =>
      'Локальные SRS-файлы используются правилами трафика и работают без интернета.';

  @override
  String get routingRuleFilesPreparingTitle => 'Готовим встроенные файлы';

  @override
  String get routingRuleFilesPreparingSubtitle =>
      'Подготавливаем локальные SRS-файлы для правил трафика.';

  @override
  String get routingRuleFilesSourceTitle => 'Источник и состояние';

  @override
  String routingRuleFilesSourceMeta(String source, String version, int count) {
    return 'Источник: $source · версия: $version · файлов: $count';
  }

  @override
  String get routingRuleFilesUpdateAction => 'Обновить файлы';

  @override
  String get routingRuleFilesUpdatingAction => 'Обновляем файлы…';

  @override
  String routingRuleFilesEta(String duration) {
    return 'Осталось примерно: $duration';
  }

  @override
  String routingRuleFilesSecondsShort(int seconds) {
    return '$seconds с';
  }

  @override
  String routingRuleFilesMinutesShort(int minutes) {
    return '$minutes мин';
  }

  @override
  String get routingRuleFilesListTitle => 'Файлы правил';

  @override
  String get routingRuleFilesEmptyTitle => 'Файлы ещё не готовы';

  @override
  String get routingRuleFilesEmptySubtitle =>
      'Откройте экран ещё раз или нажмите «Обновить файлы».';

  @override
  String trafficRulesRuleCount(int count) {
    return 'Категорий: $count';
  }
}
