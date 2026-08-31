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
  String get proxyLatencyNoResult => 'Нет данных';

  @override
  String get proxyLatencyNoResultDescription =>
      'Результат проверки для этого сервера ещё не получен.';

  @override
  String get proxySelectorTitle => 'Выбор';

  @override
  String get proxyLowestName => 'Самый быстрый';

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
  String get shareSingboxOutboundLabel => 'Конфигурация sing-box';

  @override
  String copiedToClipboard(String label) {
    return 'Скопировано: $label';
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
  String get securityTitle => 'Безопасность';

  @override
  String get securitySubtitle =>
      'Проверка TLS-сертификатов для серверов и подписок';

  @override
  String get securityTlsSectionTitle => 'TLS-сертификаты';

  @override
  String get securityUntrustedProxyCertificatesTitle =>
      'Разрешать недоверенные сертификаты прокси';

  @override
  String get securityUntrustedProxyCertificatesSubtitle =>
      'Подключаться к прокси-серверам с самоподписанными, просроченными или недоверенными сертификатами. Это снижает защиту от перехвата соединения.';

  @override
  String get securityUntrustedSubscriptionCertificatesTitle =>
      'Разрешать недоверенные сертификаты подписок';

  @override
  String get securityUntrustedSubscriptionCertificatesSubtitle =>
      'Обновлять HTTPS-подписки, даже если сертификат сайта невозможно проверить. Ссылку и содержимое подписки могут перехватить или подменить.';

  @override
  String get securityConfirmProxyTitle =>
      'Разрешить недоверенные сертификаты прокси?';

  @override
  String get securityConfirmProxyMessage =>
      'Проверка TLS-сертификатов будет отключена для всех прокси-соединений. Включайте это только для конфигураций, которым доверяете.';

  @override
  String get securityConfirmSubscriptionTitle =>
      'Разрешить недоверенные сертификаты подписок?';

  @override
  String get securityConfirmSubscriptionMessage =>
      'Проверка TLS-сертификатов будет отключена при обновлении HTTPS-подписок. Ссылку и содержимое подписки могут перехватить или подменить.';

  @override
  String get securityAllowAction => 'Разрешить';

  @override
  String get experimentalSubtitle =>
      'Сетевые эксперименты и переключение соединений';

  @override
  String get logsTitle => 'Логи';

  @override
  String get logsSubtitle => 'Конфигурация sing-box и события приложения';

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
  String get aboutSectionTitle => 'О приложении';

  @override
  String get aboutSectionSubtitle =>
      'Версия приложения, ядро, команда и служебная информация.';

  @override
  String get aboutHeroSubtitle =>
      'VPN-клиент для Android: быстрый, понятный и надёжный для повседневного использования.';

  @override
  String get aboutDevelopedBy =>
      'Etonify разрабатывает небольшая независимая команда MeowTeam.';

  @override
  String get aboutTeamLabel => 'Команда';

  @override
  String get aboutContactLabel => 'Написать разработчикам';

  @override
  String get aboutCoreSourceLabel => 'исходный код ядра';

  @override
  String get aboutDocumentationTitle => 'Документация Etonify';

  @override
  String get aboutDocumentationSubtitle => 'Настройка и использование Etonify.';

  @override
  String get documentationPageTitle => 'Документация';

  @override
  String get documentationPageSubtitle =>
      'Краткие инструкции по настройке и работе с Etonify.';

  @override
  String get documentationGroupGettingStarted => 'Начало работы';

  @override
  String get documentationGroupConnection => 'Подключение';

  @override
  String get documentationGroupRouting => 'Маршрутизация и DNS';

  @override
  String get documentationGroupMaintenance => 'Обслуживание';

  @override
  String get documentationGroupHelp => 'Диагностика';

  @override
  String get documentationGroupDocuments => 'Документы';

  @override
  String get documentationQuickStartTitle => 'Быстрый старт';

  @override
  String get documentationQuickStartBody =>
      '1. Добавьте подписку или отдельный сервер.\n2. Запустите проверку серверов.\n3. Выберите сервер или режим Lowest.\n4. Нажмите кнопку подключения и разрешите создание VPN.\n5. Если соединения нет, проверьте другой сервер и откройте логи.';

  @override
  String get documentationWhatTitle => 'О Etonify';

  @override
  String get documentationWhatBody =>
      'Etonify работает на Android 8.0 и новее. Это клиент на базе sing-box, а не VPN-сервис. Добавьте подписку или сервер от своего провайдера. Настройки, подписки и логи хранятся на устройстве.';

  @override
  String get documentationModesTitle => 'VPN и локальный прокси';

  @override
  String get documentationModesBody =>
      'VPN TUN направляет трафик приложений через системный VPN Android.\n\nЛокальный HTTP/SOCKS-прокси работает только в приложениях, где его адрес указан вручную. VPN и локальный прокси можно использовать одновременно. Для других устройств в сети включите доступ из локальной сети.';

  @override
  String get documentationProtocolsTitle => 'Форматы и протоколы';

  @override
  String get documentationProtocolsBody =>
      'Можно импортировать ссылки, QR-коды и конфигурации sing-box, Xray и Happ.\n\nПоддерживаются VLESS, VMess, Trojan, Shadowsocks, ShadowsocksR, Hysteria, Hysteria2, TUIC, AnyTLS, Naive, HTTP и SOCKS. Импорт подтверждает формат, но не доступность сервера.';

  @override
  String get documentationChainsTitle => 'Цепочки прокси';

  @override
  String get documentationChainsBody =>
      'Цепочка направляет трафик через первый и выходной прокси. Оба сервера должны работать. Задержка обычно выше. Автоматического резервирования нет.';

  @override
  String get documentationSubscriptionsTitle => 'Подписки и профили';

  @override
  String get documentationSubscriptionsBody =>
      'Профиль хранит источники подписки, серверы и последний выбор. Добавить данные можно из буфера обмена, файла, QR-кода или вручную. Автообновление меняет подписку по расписанию. При ошибке предыдущие данные сохраняются.';

  @override
  String get documentationChecksTitle => 'Проверка серверов';

  @override
  String get documentationChecksBody =>
      'URLTest отправляет HTTP-запрос через сервер. Это не ICMP-пинг. Результат зависит от сервера, TLS, тестового сайта и сети.\n\nПрочерк означает, что результата нет или он сброшен после смены сети. Красный треугольник означает ошибку. Lowest выбирает доступный сервер с наименьшей задержкой.';

  @override
  String get documentationBackgroundTitle => 'Работа в фоне и уведомление';

  @override
  String get documentationBackgroundBody =>
      'При включённом VPN Android показывает уведомление с сервером, задержкой, трафиком и кнопкой остановки.\n\nЗакрытие интерфейса не останавливает VPN. Принудительная остановка приложения отключает сервис до следующего запуска Etonify. На некоторых устройствах нужно разрешить фоновую работу и автозапуск.';

  @override
  String get documentationRoutingTitle => 'Раздельная маршрутизация и стек TUN';

  @override
  String get documentationRoutingBody =>
      'Раздельная маршрутизация работает в режиме VPN TUN. «Через VPN» направляет в туннель выбранные приложения. «Вне VPN» оставляет их на прямом подключении.\n\nMixed использует Android для TCP и gVisor для UDP. System использует Android для TCP и UDP. gVisor обрабатывает оба протокола внутри клиента. Оставьте Mixed, если нет проблем совместимости.';

  @override
  String get documentationTrafficRulesTitle => 'Правила трафика';

  @override
  String get documentationTrafficRulesBody =>
      'Пресет выбирает прямой маршрут или прокси для доменов и IP-адресов. Одновременно работает один пресет.\n\nРаздельная маршрутизация сначала определяет приложения для VPN. Затем правила трафика выбирают маршрут их соединений.';

  @override
  String get documentationDnsTitle => 'DNS';

  @override
  String get documentationDnsBody =>
      'Поддерживаются DNS устройства, UDP, TCP, DoT и DoH. «Напрямую» использует обычное подключение, «Через прокси» использует выбранный сервер.\n\nFakeIP находится в экспериментальных настройках и может не работать с отдельными приложениями.';

  @override
  String get documentationRuleFilesTitle => 'Файлы георесурсов';

  @override
  String get documentationRuleFilesBody =>
      'Пресеты используют локальные файлы .srs и работают без интернета. Новая версия заменяет старую только после успешной загрузки.\n\nБлокировка рекламы использует отдельный фильтр AdGuard. Файлы и фильтр обновляются в разделе маршрутизации.';

  @override
  String get documentationSecurityTitle => 'Безопасность TLS';

  @override
  String get documentationSecurityBody =>
      'По умолчанию Etonify проверяет TLS-сертификаты серверов и HTTPS-подписок. Проверку можно отключить отдельно для серверов и подписок. Делайте это только для доверенного источника. Иначе возможен перехват ключей и трафика.';

  @override
  String get documentationUpdatesTitle => 'Загрузки и обновления';

  @override
  String get documentationUpdatesBody =>
      'Подписки, георесурсы, фильтр рекламы и обновления клиента сначала загружаются через активный VPN. При ошибке Etonify пробует Wi-Fi или мобильную сеть. Если включён другой VPN, действуют его правила.\n\nЗагрузки имеют ограничение времени и размера. APK проверяется перед установкой.';

  @override
  String get documentationBackupTitle => 'Импорт, экспорт и резервная копия';

  @override
  String get documentationBackupBody =>
      'Экспорт настроек не содержит подписки и ключи. Экспорт подписок содержит профили и серверы.\n\nЗащищайте резервную копию паролем. Незашифрованный файл хранит ключи открытым текстом. Восстановить забытый пароль нельзя.';

  @override
  String get documentationExperimentalTitle => 'Экспериментальные настройки';

  @override
  String get documentationExperimentalBody =>
      'FakeIP, фрагментация TLS, TCP Fast Open, TCP MultiPath и мультиплексирование меняют работу сети. Для обычного подключения они не нужны.\n\nМеняйте по одной настройке. Если соединение стало хуже, верните значение по умолчанию.';

  @override
  String get documentationDiagnosticsTitle => 'Логи и ресурсы';

  @override
  String get documentationDiagnosticsBody =>
      '«Ресурсы и диагностика» показывает состояние VPN, версии и память процесса. PSS, RSS, Private Dirty, Swap, heap, code и graphics нельзя складывать между собой.\n\nПосле ошибки сразу экспортируйте логи. Перед отправкой проверьте, что в файле нет приватных данных.';

  @override
  String get documentationLimitsTitle => 'Важные ограничения';

  @override
  String get documentationLimitsBody =>
      'Etonify работает только на Android и не содержит VPN-серверов. Доступность зависит от сервера, подписки, DNS, оператора и устройства.\n\nURLTest проверяет один адрес и не гарантирует доступ ко всем сайтам. Большие подписки и массовая проверка временно увеличивают расход памяти, процессора, батареи и трафика.';

  @override
  String get telegramChannelLabel => 'Телеграм-канал';

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
  String get legalDocumentReadAction => 'Прочитано';

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
    return 'Повторно выбирает сеть по умолчанию, если Android пропустил событие смены сети. Текущий интервал: $seconds с. Применится при следующем запуске VPN.';
  }

  @override
  String get debugWakeLockTitle => 'Не давать процессору засыпать';

  @override
  String get debugWakeLockSubtitle =>
      'Не даёт Android переводить процессор в сон во время работы VPN. Может увеличить расход батареи и нагрев, поэтому по умолчанию выключено.';

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
      'Высокая нагрузка на процессор при небольшом трафике VPN. Вероятна фоновая работа системной части или ядра.';

  @override
  String get debugRuntimeMeasurementGoroutineGrowth =>
      'Во время измерения выросло количество задач ядра.';

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
      'Первые тестовые версии помогли определить системную часть Android, работу с подписками, диагностику и интерфейс, которые теперь поддерживает Etonify.';

  @override
  String get teamTimelineRefactorTitle => 'Переработка архитектуры';

  @override
  String get teamTimelineRefactorBody =>
      'Мы постепенно разделили старый код на отдельные части, упростили управление VPN и добавили проверки критических сценариев.';

  @override
  String get teamTimelineCoreTitle => 'Переход на etonify-core';

  @override
  String get teamTimelineCoreBody =>
      'После MeowSingBox клиент перешёл на более стабильную базу sing-box с изменениями, необходимыми Etonify. Собственное ядро упрощает обновления и тестирование, а доработки URLTest, переключения серверов и очистки ресурсов улучшают повседневную работу клиента.';

  @override
  String get teamTimelineNowTitle => 'Etonify сейчас';

  @override
  String get teamTimelineNowBody =>
      'Etonify продолжает развиваться: мы упрощаем интерфейс, улучшаем стабильность Android и сокращаем технический долг, сохраняя быстрый VPN-клиент.';

  @override
  String get teamDeveloperDdosxdRole => 'Ядро, сеть и собственные протоколы';

  @override
  String get teamDeveloperYamixdevRole =>
      'Android-клиент, интерфейс, ядро и релизы';

  @override
  String get teamDeveloperVerificationInfo => 'Участник команды MeowTeam.';

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
  String get diagnosticsTitle => 'Ресурсы и диагностика';

  @override
  String get diagnosticsSubtitle => 'Память, состояние ядра и диагностика.';

  @override
  String get aboutResourcesTitle => 'Ресурсы';

  @override
  String get aboutResourcesSubtitle =>
      'Снимок состояния Android и ядра по запросу. Нагрузка на процессор появится после второго обновления.';

  @override
  String get aboutResourcesPssTitle => 'Память процесса';

  @override
  String get aboutResourcesPssSubtitle =>
      'PSS — основная оценка памяти с учётом доли общих страниц. RSS показывает все страницы в RAM, Private Dirty — принадлежащие только процессу изменённые страницы, Swap PSS — долю памяти в swap. Эти значения нельзя складывать.';

  @override
  String get aboutResourcePss => 'Всего PSS';

  @override
  String get aboutResourceRss => 'Всего RSS';

  @override
  String get aboutResourceSwapPss => 'Swap PSS';

  @override
  String get aboutResourcePrivateDirty => 'Private Dirty';

  @override
  String get aboutResourceNativePss => 'Нативный PSS';

  @override
  String get aboutResourceDalvikPss => 'Android VM PSS';

  @override
  String get aboutResourceOtherPss => 'Прочий PSS';

  @override
  String get aboutResourceGraphicsPss => 'Графика PSS';

  @override
  String get aboutResourceCodePss => 'Код PSS';

  @override
  String get aboutResourceStackPss => 'Стек PSS';

  @override
  String get aboutResourcesRuntimeTitle => 'Клиент и ядро';

  @override
  String get aboutResourceNativeHeap => 'Нативная куча';

  @override
  String get aboutResourceJavaHeap => 'Куча Java';

  @override
  String get aboutResourceCoreMemory => 'Память ядра';

  @override
  String get aboutResourceFlutterImageCache => 'Кэш изображений Flutter';

  @override
  String get aboutResourceCoreGoroutines => 'Горутины ядра';

  @override
  String get aboutResourceCoreConnections => 'Соединения ядра (вход. / исход.)';

  @override
  String get aboutResourcesSystemTitle => 'Система';

  @override
  String get aboutResourceProcessCpu => 'CPU процесса с прошлого обновления';

  @override
  String get aboutResourceSystemMemory => 'Свободная RAM системы';

  @override
  String get aboutResourceBatteryTemp => 'Температура батареи';

  @override
  String get updatesTitle => 'Обновления приложения';

  @override
  String get updatesSubtitle => 'Проверить новую версию и установить её.';

  @override
  String get updatesChecking => 'Проверка обновлений…';

  @override
  String get updatesCheckAction => 'Проверить';

  @override
  String get updatesChannelMenuAction => 'Канал обновлений';

  @override
  String get updatesChannelTitle => 'Канал обновлений';

  @override
  String get updatesChannelStable => 'Stable';

  @override
  String get updatesChannelStableSubtitle =>
      'Стабильные версии для повседневного использования.';

  @override
  String get updatesChannelBeta => 'Beta';

  @override
  String get updatesChannelBetaSubtitle =>
      'Тестовые alpha-, beta- и RC-версии из GitHub Pre-release.';

  @override
  String get updatesChannelBetaWarning =>
      'Тестовые версии могут содержать ошибки. Вернуться на Stable можно, когда стабильная сборка станет новее установленной.';

  @override
  String get updatesPrereleaseVersionTooltip => 'Тестовая версия';

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
  String get updatesCurrentVersionNewerTitle => 'Установленная версия новее';

  @override
  String updatesCurrentVersionNewerSubtitle(
    String currentVersion,
    String channelVersion,
  ) {
    return 'Установлена $currentVersion. В выбранном канале доступна $channelVersion; обновление не требуется.';
  }

  @override
  String get updatesNoChannelReleaseTitle => 'В этом канале пока нет версий';

  @override
  String get updatesNoBetaReleaseSubtitle =>
      'На GitHub пока нет опубликованных Pre-release версий Etonify.';

  @override
  String get updatesNoStableReleaseSubtitle =>
      'На GitHub пока нет опубликованной стабильной версии Etonify.';

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
  String get appVersionLabel => 'Версия приложения';

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
      'Эти настройки хранятся только на этом устройстве.';

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
  String get notificationSettingsTitle => 'Уведомление VPN';

  @override
  String get notificationSettingsSubtitle =>
      'Сервер, трафик, пинг и частота обновления.';

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
  String get notificationTrafficTotalLabel => 'Всего трафика';

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
  String get memoryLimitTitle => 'Мягкий лимит памяти ядра';

  @override
  String get memoryLimitEnabledSubtitle =>
      'Рекомендуется. Ограничивает только память Go-части sing-box и помогает ядру раньше освобождать неиспользуемые данные. VPN не отключается при достижении этого лимита. Изменение вступит в силу после перезапуска приложения.';

  @override
  String get memoryLimitDisabledSubtitle =>
      'Выключено. Go-часть sing-box управляет памятью без заданного Etonify лимита и может удерживать больше RAM. Вступит в силу после перезапуска приложения.';

  @override
  String get memoryLimitDisableWarningTitle => 'Выключить мягкий лимит ядра?';

  @override
  String get memoryLimitDisableWarningMessage =>
      'Без мягкого лимита Go-часть sing-box может дольше удерживать свободную память. Это не меняет лимиты Flutter или Android и не влияет на автоматическое завершение приложения системой. Изменение вступит в силу после перезапуска Etonify.';

  @override
  String get memoryLimitDisableConfirm => 'Выключить';

  @override
  String get enableInboundTitle => 'Включить';

  @override
  String get vpnInDescription =>
      'VPN TUN создаёт системное VPN-подключение Android для трафика устройства. Правила маршрутизации определяют, что идёт через прокси, а что — напрямую.';

  @override
  String get vpnInboundEnabledSubtitle =>
      'Создаёт системный VPN-туннель для трафика устройства';

  @override
  String get inboundNoneEnabled =>
      'Выберите VPN или локальный прокси перед запуском.';

  @override
  String get mtuTitle => 'MTU';

  @override
  String get mtuSubtitle => 'Размер пакета TUN-интерфейса';

  @override
  String get mtuInputRange => 'Введите значение от 1280 до 9000.';

  @override
  String get mtuInvalidValue => 'Укажите значение от 1280 до 9000.';

  @override
  String get strictRouteTitle => 'Не допускать обход VPN';

  @override
  String get strictRouteSubtitle =>
      'Жёстко направляет трафик через VPN и снижает шанс утечек мимо туннеля';

  @override
  String get tunImplementationTitle => 'Сетевой стек TUN';

  @override
  String get tunImplementationSubtitle =>
      'Определяет, как клиент обрабатывает TCP- и UDP-трафик внутри VPN';

  @override
  String get tunImplementationMixed => 'Смешанный (Mixed)';

  @override
  String get tunImplementationMixedSubtitle =>
      'TCP обрабатывает системный стек Android, а UDP — виртуальный стек gVisor. Это стандартный вариант sing-box.';

  @override
  String get tunImplementationSystem => 'Системный (System)';

  @override
  String get tunImplementationSystemSubtitle =>
      'TCP и UDP обрабатывает сетевой стек Android. Совместимость зависит от устройства и его прошивки.';

  @override
  String get tunImplementationGvisor => 'gVisor';

  @override
  String get tunImplementationGvisorSubtitle =>
      'TCP и UDP обрабатывает виртуальный сетевой стек gVisor в пространстве пользователя. Может помочь, если системный стек работает нестабильно.';

  @override
  String get proxyInDescription =>
      'Локальный HTTP/SOCKS-прокси для приложений и устройств, где адрес прокси указан вручную. Это не системный VPN Android.';

  @override
  String get proxyInboundEnabledSubtitle =>
      'Запускает локальный HTTP/SOCKS-прокси для приложений и устройств';

  @override
  String get allowLanConnectionsTitle =>
      'Разрешить соединения из локальной сети';

  @override
  String get allowLanConnectionsSubtitle =>
      'Разрешает подключения из локальной сети; без этого доступен только телефон';

  @override
  String get portTitle => 'Порт';

  @override
  String get proxyPortSubtitle => 'Порт локального HTTP/SOCKS-прокси';

  @override
  String get connectionModeTitle => 'Режим подключения';

  @override
  String get connectionModeSubtitle =>
      'VPN охватывает трафик устройства. Локальный прокси работает только там, где его адрес указан вручную.';

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
  String get localProxySettingsSubtitle => 'Адрес, порт и данные доступа';

  @override
  String get lanProxySecurityTitle => 'Доступ защищён';

  @override
  String get lanProxySecuritySubtitle =>
      'Для подключений из локальной сети нужны логин и пароль. Авторизация ограничивает доступ, но не шифрует локальную сеть.';

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
  String get dnsUsePresetTitle => 'Использовать готовую настройку';

  @override
  String get dnsResolverTitle => 'DNS-сервер';

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
  String get dnsPresetCustom => 'Вручную';

  @override
  String get dnsPresetDeviceSubtitle =>
      'Использовать DNS текущей Android-сети.';

  @override
  String get dnsPresetCustomSubtitle =>
      'Введите IP-адрес или имя хоста. По умолчанию используется UDP; также доступны tcp://, tls:// и https://.';

  @override
  String get dnsPresetUdpSubtitle =>
      'Обычный DNS через UDP: быстро, но без шифрования.';

  @override
  String get dnsPresetTcpSubtitle =>
      'Обычный DNS через TCP: иногда стабильнее, но без шифрования.';

  @override
  String get dnsPresetTlsSubtitle =>
      'DNS через TLS: шифрованное соединение на порту 853.';

  @override
  String get dnsPresetHttpsSubtitle =>
      'DNS через HTTPS: шифрованные запросы, которые можно отправлять через прокси.';

  @override
  String get dnsProtectionTitle => 'Защита';

  @override
  String get dnsSecureOnlyTitle => 'Только защищённый DNS';

  @override
  String get dnsSecureOnlySubtitle =>
      'Разрешить только DoH и DoT. DNS устройства, UDP и TCP не используются.';

  @override
  String get dnsDirectThroughProxyTitle => 'Прямой DNS через прокси';

  @override
  String get dnsDirectThroughProxySubtitle =>
      'DNS прямых маршрутов идёт через прокси, а сайты подключаются напрямую.';

  @override
  String get dnsPreferIpv6Title => 'Предпочитать IPv6';

  @override
  String get dnsPreferIpv6Subtitle =>
      'Приоритет IPv6, если доступны обе версии адреса';

  @override
  String get urlTestUrlTitle => 'Адрес проверки';

  @override
  String get urlTestUrlSubtitle =>
      'Если подписка задаёт свой адрес, используется он';

  @override
  String get urlTestIntervalTitle => 'Интервал проверки, сек.';

  @override
  String get urlTestIntervalCompactTitle => 'Интервал проверки';

  @override
  String get urlTestIntervalSubtitle =>
      'Частота проверки прокси для автоматического выбора';

  @override
  String get urlTestTimeoutTitle => 'Таймаут проверки, сек.';

  @override
  String get urlTestTimeoutCompactTitle => 'Таймаут проверки';

  @override
  String get urlTestTimeoutSubtitle =>
      'Сколько ждать ответа от одного прокси перед ошибкой';

  @override
  String get urlTestConcurrencyTitle => 'Одновременные проверки';

  @override
  String get urlTestConcurrencySubtitle =>
      'Сколько серверов URLTest проверяет одновременно';

  @override
  String get urlTestSingleRetestTitle => 'Быстрая перепроверка, сек.';

  @override
  String get urlTestSingleRetestCompactTitle => 'Быстрая перепроверка';

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
      'После URLTest приложение определит внешний IP и страну у указанного количества самых быстрых серверов';

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
      'Заменяет стандартный User-Agent Etonify для этой подписки';

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
      'VPN не удалось полностью выключить. Откройте логи и повторите попытку.';

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
  String get settingsProfilesChecksTitle => 'Подписки и проверка';

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
      'Профиль обновляется по одному URL. Если старый импорт объединил несколько ссылок, оставьте нужную, а остальные источники добавьте отдельными профилями. После сохранения обновите подписку.';

  @override
  String get subscriptionUrlSingleSourceRequired =>
      'Оставьте один URL. Остальные источники добавьте отдельными профилями.';

  @override
  String get subscriptionUrlOrContent => 'URL или содержимое';

  @override
  String get subscriptionUrlOrContentHint =>
      'Вставьте URL, ссылку vless://, список ссылок или конфигурацию';

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
  String get reparseProxies => 'Пересобрать список прокси';

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
  String get subscriptionCopyUrl => 'Скопировать URL';

  @override
  String get subscriptionShowUrlQr => 'Показать QR-код URL';

  @override
  String get subscriptionUrlCopied => 'URL подписки скопирован';

  @override
  String get subscriptionImportHelpTitle => 'Как добавить подписку';

  @override
  String get subscriptionImportHelpBody =>
      'Скопируйте ссылку подписки у провайдера и выберите «Буфер обмена» либо отсканируйте QR-код. Если ссылка не распознаётся, выберите «Вручную» и вставьте URL, ссылку vless://, список ключей или конфигурацию sing-box/Xray. Для Happ-подписок при необходимости укажите User-Agent или HWID.';

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
  String get newUrlTitle => 'Новый URL';

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
  String get noSubscriptionsHint => 'Нажмите «+», чтобы добавить URL подписки';

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
  String lastUpdatedDateTime(String date, String time) {
    return 'Обновлено $date в $time';
  }

  @override
  String trafficUsage(String used, String total) {
    return '$used / $total';
  }

  @override
  String get expired => 'Срок истёк';

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
    return 'Подписка сохранена без серверов. Причина: $reason Проверьте ссылку, HWID или заголовки и обновите подписку.';
  }

  @override
  String get subscriptionErrorInvalidUrl =>
      'Ссылка подписки некорректна. Скопируйте её заново и проверьте, что она начинается с http:// или https://.';

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
      'Сервер отклонил запрос (HTTP 400). Проверьте ссылку и её параметры.';

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
      'Сервер подписки не ответил вовремя (HTTP 408). Повторите попытку позже.';

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
      'Сервер провайдера не ответил вовремя (HTTP 504). Повторите попытку позже.';

  @override
  String subscriptionErrorHttpStatus(int status) {
    return 'Сервер подписки вернул HTTP $status. Проверьте статус провайдера или запросите новую ссылку.';
  }

  @override
  String get subscriptionErrorDns =>
      'Не удалось найти сервер подписки. Проверьте домен, DNS и подключение к интернету.';

  @override
  String get subscriptionErrorConnection =>
      'Не удалось подключиться к серверу подписки. Проверьте подключение и повторите попытку позже.';

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
  String get wireGuardUnsupportedMessage =>
      'Начиная с версии 0.3.1 Etonify не поддерживает WireGuard из-за проблем со стабильностью протокола. Используйте сервер с другим протоколом.';

  @override
  String get wireGuardServersSkippedMessage =>
      'Серверы WireGuard пропущены. Начиная с версии 0.3.1 Etonify не поддерживает WireGuard из-за проблем со стабильностью протокола.';

  @override
  String get subscriptionErrorInvalidContent =>
      'Ответ сервера не является корректной подпиской. Проверьте, что ссылка ведёт прямо на файл подписки.';

  @override
  String get subscriptionErrorHappInvalid =>
      'Не удалось расшифровать ссылку Happ или найти внутри неё корректный URL подписки. Скопируйте свежую ссылку и повторите попытку.';

  @override
  String get subscriptionErrorUnknown =>
      'Не удалось обработать подписку. Проверьте ссылку и откройте диагностику — там сохранена техническая причина.';

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
      'Для этой Happ-подписки может понадобиться HWID. Отправьте его сейчас или импортируйте подписку без HWID.';

  @override
  String get subscriptionOperationSlowWarning =>
      'Сервер подписки отвечает дольше обычного. Если это повторяется, проверьте ссылку или подключение.';

  @override
  String get subscriptionOperationTimeout =>
      'Сервер подписки не ответил вовремя. Проверьте ссылку или подключение и повторите попытку.';

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
      'Направляет адреса локальной сети напрямую, вне VPN';

  @override
  String get russiaRoutesTitle => 'Умная маршрутизация';

  @override
  String get russiaRoutesRunetFreedomBadge => 'runetfreedom';

  @override
  String get russiaRoutesDomainListBadge => 'domain-list-community';

  @override
  String get russiaRoutesSubtitle =>
      'Российские сервисы — напрямую, остальные ресурсы — через VPN.';

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
      'Скачиваем свежую базу, проверяем файлы и безопасно заменяем локальные правила.';

  @override
  String get russiaRoutesStageChecking => 'Проверяем версию правил…';

  @override
  String get russiaRoutesStageDownloading => 'Скачиваем архив правил…';

  @override
  String get russiaRoutesStageVerifying => 'Проверяем целостность архива…';

  @override
  String get russiaRoutesStageExtracting => 'Распаковываем файлы георесурсов…';

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
  String russiaRoutesItemsProcessed(int completed) {
    return 'Обработано списков: $completed.';
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
      'Клиент скачивает локальный набор правил и подключает его к маршрутизации.';

  @override
  String get adBlockDownloadAction => 'Скачать';

  @override
  String get adBlockUpdateAction => 'Обновить';

  @override
  String get adBlockEnableTitle => 'Включить локальную блокировку';

  @override
  String get adBlockEnabledSubtitle =>
      'Использовать скачанный набор правил для блокировки доменов через DNS и маршрутизацию.';

  @override
  String get adBlockMissingSubtitle =>
      'Сначала скачайте фильтр, чтобы включить блокировку.';

  @override
  String get adBlockDownloadingStatus =>
      'Скачиваем и собираем локальный фильтр...';

  @override
  String get adBlockStageConnecting => 'Подключаемся к AdGuard…';

  @override
  String get adBlockStageDownloading => 'Скачиваем список фильтра…';

  @override
  String get adBlockStageCompiling => 'Собираем локальный набор правил…';

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
      'Раздельная маршрутизация сейчас работает нестабильно. Попробуйте отключить её и проверьте обновления клиента.';

  @override
  String get splitRoutingTunOnly =>
      'Работает только в режиме VPN. Локальный прокси не управляет приложениями.';

  @override
  String get splitRoutingModeTitle => 'Режим';

  @override
  String get splitRoutingModeDisabled => 'Выключено';

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
      'Etonify получает список установленных приложений только для выбора. Список остаётся на устройстве.';

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
      'Похоже, эта подписка требует HWID. Сервер вернул только один сервер с app/HWID в названии. Откройте настройки подписки и включите отправку HWID.';

  @override
  String get subscriptionLikelyRequiresHwidMessage =>
      'Сервер вернул только один сервер, и его название похоже на заглушку про app или HWID.\n\nВозможно, подписка ожидает HWID устройства в запросе.\n\nВключить отправку HWID и сразу обновить подписку?';

  @override
  String get subscriptionLikelyRequiresHwidAction => 'Включить HWID';

  @override
  String get subscriptionHwidEnabledAndUpdated =>
      'Отправка HWID включена. Подписка обновлена.';

  @override
  String get noValidOutboundsTitle => 'Нет рабочих узлов';

  @override
  String get noValidOutboundsWarning =>
      'В этой подписке не осталось рабочих серверов: они были отфильтрованы при проверке. Проверьте подписку или обновите её.';

  @override
  String get noValidOutboundsMessage =>
      'В этой подписке не осталось рабочих серверов.\n\nВсе узлы были отфильтрованы ещё до запуска, поэтому клиент не будет запускать sing-box с пустым списком прокси.\n\nПроверьте подписку, обновите её или импортируйте корректную.';

  @override
  String get noValidOutboundsAfterDropInvalidWarning =>
      'В выбранной подписке не осталось рабочих серверов после фильтрации. Проверьте её содержимое или обновите подписку.';

  @override
  String get noValidOutboundsAfterDropInvalidMessage =>
      'Все оставшиеся серверы в выбранной подписке были отброшены при запуске.\n\nКлиент остановился до передачи некорректной конфигурации в sing-box.\n\nПроверьте содержимое подписки и обновите или замените её.';

  @override
  String get experimentalTcpFastOpenTitle => 'TCP Fast Open';

  @override
  String get experimentalTcpFastOpenSubtitle =>
      'Может ускорить установление TCP-соединения. Результат зависит от сети и поддержки сервера.';

  @override
  String get experimentalTcpMultiPathTitle => 'TCP Multipath';

  @override
  String get experimentalTcpMultiPathSubtitle =>
      'Использует несколько сетевых путей. Может помочь при смене сети, но иногда работает нестабильно.';

  @override
  String get experimentalInterruptConnectionsTitle =>
      'Рвать активные соединения при смене узла';

  @override
  String get experimentalInterruptConnectionsSubtitle =>
      'Быстрее применяет смену прокси, но старые соединения приложений могут оборваться.';

  @override
  String get experimentalUrlTestStrictToleranceTitle =>
      'Точный автовыбор (1 мс)';

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
  String get tlsFragmentationTitle => 'Фрагментация TLS';

  @override
  String get tlsFragmentationSubtitle =>
      'Разбивает TLS-рукопожатие на части. Иногда помогает при DPI, но может замедлить подключение.';

  @override
  String get tlsFragmentationModeDisabled => 'Выключено';

  @override
  String get tlsFragmentationModeDisabledSubtitle =>
      'Не меняет TLS настройки серверов.';

  @override
  String get tlsFragmentationModeRecord => 'Фрагментация TLS-записей';

  @override
  String get tlsFragmentationModeRecordSubtitle =>
      'Более мягкий режим. Рекомендуется начать с него.';

  @override
  String get tlsFragmentationModeFragment => 'Фрагментация TLS';

  @override
  String get tlsFragmentationModeFragmentSubtitle =>
      'Более агрессивный режим с задержкой резервного подключения 300 мс.';

  @override
  String get blockLeaksTitle => 'Блокировать STUN/WebRTC';

  @override
  String get blockLeaksSubtitle =>
      'Блокирует STUN/WebRTC-трафик, который может обходить прокси. Это не заменяет проверку DNS и маршрутов.';

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
  String get connectionStageConfiguring => 'Сборка конфигурации';

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
  String get trafficRulesUsePresetTitle => 'Использовать готовое правило';

  @override
  String get trafficRulesUsePresetSubtitle =>
      'Выберите готовое правило для маршрутизации доменов и IP-адресов.';

  @override
  String get trafficRulesUsePresetAction => 'Применить правило';

  @override
  String get trafficRulesDisablePreset => 'Отключить правило';

  @override
  String get trafficRulesQuickSelection => 'Быстрый выбор';

  @override
  String get trafficRulesDeveloperSection => 'Правила от разработчика';

  @override
  String get trafficRulesDeveloperSubtitle =>
      'Проверенные правила с подробным описанием.';

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
  String get trafficRulesPreparing => 'Подготавливаем правило…';

  @override
  String get trafficRulesPrepareFailed =>
      'Не удалось подготовить данные правила. Проверьте интернет и повторите попытку.';

  @override
  String get remoteDownloadConnectTimeout =>
      'Не удалось подключиться к серверу за 5 секунд. Проверьте интернет или активный VPN и повторите попытку.';

  @override
  String get remoteDownloadResponseTimeout =>
      'Сервер не начал отвечать за 5 секунд. Проверьте интернет или активный VPN и повторите попытку.';

  @override
  String get remoteDownloadRetryWithoutVpn => 'Пробуем без VPN';

  @override
  String get remoteDownloadRetryWithoutVpnHint =>
      'VPN-маршрут не ответил. Повторяем через Wi-Fi или мобильную сеть.';

  @override
  String get remoteDownloadIdleTimeout =>
      'Загрузка остановлена: сервер не передавал данные 7 секунд. Попробуйте ещё раз.';

  @override
  String get routingRuleFilesTitle => 'Файлы георесурсов';

  @override
  String get routingRuleFilesSettingsTitle => 'Файлы георесурсов';

  @override
  String routingRuleFilesSettingsReady(int count) {
    return 'Готово файлов: $count';
  }

  @override
  String get routingRuleFilesSettingsPreparing =>
      'Встроенные файлы будут подготовлены при открытии';

  @override
  String get routingRuleFilesReadyTitle => 'Файлы георесурсов готовы';

  @override
  String get routingRuleFilesReadySubtitle =>
      'Файлы SRS хранятся на устройстве и работают без интернета.';

  @override
  String get routingRuleFilesPreparingTitle => 'Готовим встроенные георесурсы';

  @override
  String get routingRuleFilesPreparingSubtitle =>
      'Подготавливаем локальные файлы георесурсов для правил трафика.';

  @override
  String get routingRuleFilesSourceTitle => 'Источник';

  @override
  String get routingRuleFilesVersionTitle => 'Версия';

  @override
  String get routingRuleFilesCountTitle => 'Файлы';

  @override
  String get routingRuleFilesTotalSizeTitle => 'Общий размер';

  @override
  String get routingRuleFilesScopeTitle => 'Сейчас в приоритете Россия';

  @override
  String get routingRuleFilesScopeSubtitle =>
      'Набор пока содержит правила для российских сетей и сервисов. География будет расширяться в следующих обновлениях.';

  @override
  String get routingRuleFilesOpenSourceFailed =>
      'Не удалось открыть страницу источника. Попробуйте ещё раз.';

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
  String get routingRuleFilesListTitle => 'Файлы георесурсов';

  @override
  String get routingRuleFilesEmptyTitle => 'Файлы ещё не готовы';

  @override
  String get routingRuleFilesEmptySubtitle =>
      'Откройте экран ещё раз или нажмите «Обновить файлы».';

  @override
  String trafficRulesRuleCount(int count) {
    return 'Категорий: $count';
  }

  @override
  String get coreIntegrationTitle => 'Ядро и конфигурация';

  @override
  String get coreIntegrationSubtitle =>
      'Фактическое состояние встроенного ядра и последнего конфига, а не только положение переключателей в интерфейсе.';

  @override
  String get coreApiLabel => 'API ядра';

  @override
  String get coreCompatibilityLabel => 'Совместимость';

  @override
  String get coreCompatible => 'Совместимо';

  @override
  String get coreIncompatible => 'Несовместимо';

  @override
  String get coreConfigStateLabel => 'Состояние конфига';

  @override
  String get coreConfigApplied => 'Применён';

  @override
  String get coreConfigValidated => 'Проверен';

  @override
  String get coreConfigFailed => 'Ошибка';

  @override
  String get coreConfigSuperseded => 'Заменён новым';

  @override
  String get coreConfigNotApplied => 'Ещё не применялся';

  @override
  String get coreConfigPending => 'Применяется…';

  @override
  String get coreRuntimeStateLabel => 'Состояние VPN';

  @override
  String get coreRuntimeRunning => 'Работает';

  @override
  String get coreRuntimeStopped => 'Остановлен';

  @override
  String get coreRuntimeGenerationLabel => 'Поколение runtime';

  @override
  String get coreConfigSchemaLabel => 'Схема конфига';

  @override
  String get coreLastChangeLabel => 'Последнее применение';
}
