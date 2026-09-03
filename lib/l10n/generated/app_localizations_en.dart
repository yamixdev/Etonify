// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get profiles => 'Profiles';

  @override
  String get close => 'Close';

  @override
  String get homeTab => 'Home';

  @override
  String get proxiesTab => 'Proxies';

  @override
  String get proxiesTitle => 'Proxies';

  @override
  String get proxySwitching => 'Switching';

  @override
  String get proxyUnavailable => 'Unavailable';

  @override
  String get proxyLatencyNoResult => 'No result';

  @override
  String get proxyLatencyNoResultDescription =>
      'No latency test result is available for this server yet.';

  @override
  String get proxySelectorTitle => 'Selector';

  @override
  String get proxyLowestName => 'Lowest';

  @override
  String get proxyAutomaticSelectionLabel => 'Automatic selection';

  @override
  String get proxyChainLabel => 'Chain';

  @override
  String get proxyChainAddTitle => 'Add proxy chain';

  @override
  String get proxyChainAddTile => 'Add proxy chain';

  @override
  String get proxyChainChangeFirstHop => 'Change first proxy';

  @override
  String get proxyChainRenameAction => 'Rename';

  @override
  String get proxyChainRenameTitle => 'Rename proxy chain';

  @override
  String get proxyChainRemoveAction => 'Remove proxy chain';

  @override
  String get proxyChainNameLabel => 'Name';

  @override
  String get proxyChainFirstHopLabel => 'First proxy';

  @override
  String get proxyChainExitLabel => 'Exit proxy';

  @override
  String get proxyChainNothingFound => 'Nothing found';

  @override
  String get proxyChainSaveAction => 'Save';

  @override
  String get shareProxyTitle => 'Share';

  @override
  String get shareProxyLinkLabel => 'Share link';

  @override
  String get shareSingboxOutboundLabel => 'sing-box outbound';

  @override
  String copiedToClipboard(String label) {
    return '$label copied';
  }

  @override
  String get unavailableForThisType => 'Unavailable for this type';

  @override
  String get sort => 'Sort';

  @override
  String get sortByDefault => 'Source order';

  @override
  String get sortByLatency => 'By latency';

  @override
  String get sortByWorking => 'Working only';

  @override
  String get sortByName => 'By name';

  @override
  String get sortByCountry => 'By country';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get generalSectionTitle => 'General';

  @override
  String get inboundTitle => 'Inbound';

  @override
  String get dnsTitle => 'DNS';

  @override
  String get whitelistTitle => 'Whitelist';

  @override
  String get whitelistSubtitle => 'Reserved routing tools';

  @override
  String get experimentalTitle => 'Experimental';

  @override
  String get securityTitle => 'Security';

  @override
  String get securitySubtitle => 'TLS certificates and connection verification';

  @override
  String get securityTlsSectionTitle => 'TLS certificates';

  @override
  String get securityUntrustedProxyCertificatesTitle =>
      'Allow untrusted proxy certificates';

  @override
  String get securityUntrustedProxyCertificatesSubtitle =>
      'Connect to proxy servers with self-signed, expired, or otherwise untrusted certificates. This weakens protection against connection interception.';

  @override
  String get securityUntrustedSubscriptionCertificatesTitle =>
      'Allow untrusted subscription certificates';

  @override
  String get securityUntrustedSubscriptionCertificatesSubtitle =>
      'Update HTTPS subscriptions even when the website certificate cannot be verified. The subscription URL and content may be intercepted or replaced.';

  @override
  String get securityConfirmProxyTitle => 'Allow untrusted proxy certificates?';

  @override
  String get securityConfirmProxyMessage =>
      'Certificate verification will be disabled for every TLS proxy connection. Enable this only for configurations you trust.';

  @override
  String get securityConfirmSubscriptionTitle =>
      'Allow untrusted subscription certificates?';

  @override
  String get securityConfirmSubscriptionMessage =>
      'Certificate verification will be disabled while updating HTTPS subscriptions. The subscription URL and content may be intercepted or replaced.';

  @override
  String get securityAllowAction => 'Allow';

  @override
  String get experimentalSubtitle =>
      'Multipath, Fast Open, and connection switching behavior';

  @override
  String get logsTitle => 'Logs';

  @override
  String get logsSubtitle => 'Generated sing-box config and app events';

  @override
  String get urlTestTitle => 'Server checks';

  @override
  String get urlTestSubtitle => 'Latency checks and automatic server selection';

  @override
  String get vpnInTitle => 'VPN In';

  @override
  String get proxyInTitle => 'Proxy In';

  @override
  String get dnsDirectTitle => 'Direct';

  @override
  String get dnsProxyTitle => 'Via proxy';

  @override
  String get dnsIpPreferenceTitle => 'IP version';

  @override
  String get aboutSectionTitle => 'About';

  @override
  String get aboutSectionSubtitle =>
      'App version, core, team, and service information.';

  @override
  String get aboutHeroSubtitle =>
      'An Android VPN client we are building to be fast, understandable, and reliable for everyday use.';

  @override
  String get aboutDevelopedBy =>
      'Etonify is developed by the small independent MeowTeam.';

  @override
  String get aboutTeamLabel => 'Team';

  @override
  String get aboutContactLabel => 'Message the developers';

  @override
  String get aboutCoreSourceLabel => 'core source code';

  @override
  String get aboutDocumentationTitle => 'Etonify documentation';

  @override
  String get aboutDocumentationSubtitle => 'Set up and use Etonify.';

  @override
  String get documentationPageTitle => 'Documentation';

  @override
  String get documentationPageSubtitle =>
      'Short instructions for setting up and using Etonify.';

  @override
  String get documentationGroupGettingStarted => 'Getting started';

  @override
  String get documentationGroupConnection => 'Connection';

  @override
  String get documentationGroupRouting => 'Routing and DNS';

  @override
  String get documentationGroupMaintenance => 'Maintenance';

  @override
  String get documentationGroupHelp => 'Diagnostics';

  @override
  String get documentationGroupDocuments => 'Documents';

  @override
  String get documentationQuickStartTitle => 'Quick start';

  @override
  String get documentationQuickStartBody =>
      '1. Add a subscription or individual server.\n2. Run a server check.\n3. Select a server or Lowest.\n4. Tap connect and allow the VPN connection.\n5. If it does not connect, try another server and open Logs.';

  @override
  String get documentationWhatTitle => 'About Etonify';

  @override
  String get documentationWhatBody =>
      'Etonify works on Android 8.0 and newer. It is a sing-box client, not a VPN service. Add a subscription or server from your provider. Settings, subscriptions, and logs stay on the device.';

  @override
  String get documentationModesTitle => 'VPN and local proxy';

  @override
  String get documentationModesBody =>
      'VPN TUN routes app traffic through the Android system VPN.\n\nThe local HTTP/SOCKS proxy works only in apps configured to use its address. VPN and local proxy can run together. Enable LAN access for other devices on your network.';

  @override
  String get documentationProtocolsTitle => 'Formats and protocols';

  @override
  String get documentationProtocolsBody =>
      'You can import links, QR codes, and sing-box, Xray, or Happ configurations.\n\nSupported protocols include VLESS, VMess, Trojan, Shadowsocks, ShadowsocksR, Hysteria, Hysteria2, TUIC, AnyTLS, Naive, HTTP, and SOCKS. Import confirms the format, not server availability.';

  @override
  String get documentationChainsTitle => 'Proxy chains';

  @override
  String get documentationChainsBody =>
      'A chain routes traffic through a first proxy and an exit proxy. Both servers must work. Latency is usually higher. Chains do not provide automatic failover.';

  @override
  String get documentationSubscriptionsTitle => 'Subscriptions and profiles';

  @override
  String get documentationSubscriptionsBody =>
      'A profile stores subscription sources, servers, and the last selection. Add data from the clipboard, a file, a QR code, or manually. Automatic refresh updates the subscription on schedule. Previous data stays available if an update fails.';

  @override
  String get documentationChecksTitle => 'Server checks';

  @override
  String get documentationChecksBody =>
      'URLTest sends an HTTP request through the server. It is not an ICMP ping. The result depends on the server, TLS, test website, and network.\n\nA dash means there is no result or it was cleared after a network change. A red warning icon means the check failed. Lowest selects an available server with the lowest delay.';

  @override
  String get documentationBackgroundTitle =>
      'Background operation and notification';

  @override
  String get documentationBackgroundBody =>
      'While VPN is active, Android shows a notification with the server, delay, traffic, and a stop action.\n\nClosing the interface does not stop the VPN. Force-stopping the app disables the service until Etonify is opened again. Some devices require background activity and auto-start permission.';

  @override
  String get documentationRoutingTitle => 'Split tunneling and TUN stack';

  @override
  String get documentationRoutingBody =>
      'Split tunneling works in VPN TUN mode. Via VPN sends selected apps into the tunnel. Outside VPN leaves them on a direct connection.\n\nMixed uses Android for TCP and gVisor for UDP. System uses Android for TCP and UDP. gVisor handles both inside the client. Keep Mixed unless you have a compatibility problem.';

  @override
  String get documentationTrafficRulesTitle => 'Traffic rules';

  @override
  String get documentationTrafficRulesBody =>
      'A preset chooses a direct or proxy route for domains and IP addresses. One preset can be active at a time.\n\nSplit tunneling first selects which apps enter the VPN. Traffic rules then select the route for their connections.';

  @override
  String get documentationDnsTitle => 'DNS';

  @override
  String get documentationDnsBody =>
      'Etonify supports device DNS, UDP, TCP, DoT, and DoH. Direct uses the regular connection. Via proxy uses the selected server.\n\nFakeIP is an experimental option and may not work with some apps.';

  @override
  String get documentationRuleFilesTitle => 'Geo-resource files';

  @override
  String get documentationRuleFilesBody =>
      'Traffic presets use local .srs files and work offline. A new version replaces the old one only after a successful download.\n\nAd blocking uses a separate AdGuard filter. Update files and the filter in Routing settings.';

  @override
  String get documentationSecurityTitle => 'TLS security';

  @override
  String get documentationSecurityBody =>
      'Etonify verifies TLS certificates for servers and HTTPS subscriptions by default. Verification can be disabled separately for servers and subscriptions. Do this only for a trusted source. Otherwise, keys and traffic can be intercepted.';

  @override
  String get documentationUpdatesTitle => 'Downloads and updates';

  @override
  String get documentationUpdatesBody =>
      'Subscriptions, geo-resources, the ad-blocking filter, and client updates first download through the active VPN. On failure, Etonify tries Wi-Fi or mobile data. If another VPN is active, its rules apply.\n\nDownloads have time and size limits. APK files are verified before installation.';

  @override
  String get documentationBackupTitle => 'Import, export, and backups';

  @override
  String get documentationBackupBody =>
      'Settings export does not include subscriptions or keys. Subscription export contains profiles and servers.\n\nProtect backups with a password. An unencrypted file stores keys in plain text. A forgotten password cannot be recovered.';

  @override
  String get documentationExperimentalTitle => 'Experimental options';

  @override
  String get documentationExperimentalBody =>
      'FakeIP, TLS fragmentation, TCP Fast Open, TCP MultiPath, and multiplexing change network behavior. They are not required for a normal connection.\n\nChange one option at a time. Restore the default if the connection becomes worse.';

  @override
  String get documentationDiagnosticsTitle => 'Logs and resources';

  @override
  String get documentationDiagnosticsBody =>
      'Resources and diagnostics show VPN status, versions, and process memory. PSS, RSS, Private Dirty, Swap, heap, code, and graphics must not be added together.\n\nExport logs immediately after an error. Check the file for private data before sharing it.';

  @override
  String get documentationLimitsTitle => 'Important limits';

  @override
  String get documentationLimitsBody =>
      'Etonify works only on Android and does not include VPN servers. Availability depends on the server, subscription, DNS, carrier, and device.\n\nURLTest checks one address and does not guarantee access to every website. Large subscriptions and full server checks temporarily increase memory, CPU, battery, and data use.';

  @override
  String get telegramChannelLabel => 'Telegram channel';

  @override
  String get legalTermsTitle => 'Terms of Use';

  @override
  String get legalPrivacyTitle => 'Privacy Policy';

  @override
  String get legalTermsSummary =>
      'Rules for responsible use and project disclaimers.';

  @override
  String get legalPrivacySummary =>
      'What Etonify stores locally and what it does not collect.';

  @override
  String get legalGateTitle => 'Before using Etonify';

  @override
  String legalGateSubtitle(String version) {
    return 'Starting with version $version, please read and accept the Terms and Privacy Policy to continue.';
  }

  @override
  String get legalAcceptAction => 'Accept and continue';

  @override
  String get legalAcceptHint => 'Open both documents to enable continue.';

  @override
  String get legalDocumentReadAction => 'I have read it';

  @override
  String get legalContactAction => 'Ask a question';

  @override
  String get legalImportBlockedMessage =>
      'Accept Terms and Privacy Policy before importing subscriptions.';

  @override
  String get legalTermsBody =>
      '# Etonify Terms of Use\n\n## What the app does\n\nEtonify is an Android VPN client. **It does not sell or provide VPN servers:** users add subscriptions, profiles, and servers from third-party providers.\n\n## User responsibility\n\nUse Etonify according to applicable law and service rules. Do not use it for attacks, fraud, malware, harassment, or other illegal activity.\n\n- You are responsible for added profiles and access keys.\n- Third-party providers determine their own service terms.\n- MeowTeam does not control subscription content or third-party server traffic.\n\n## Operation and updates\n\nEtonify is provided **as is**. We improve reliability and security, but cannot guarantee every server, route, DNS resolver, carrier, or modified Android firmware. Updates are installed only after user action and Android system confirmation.\n\n## Feedback\n\nQuestions, bug reports, and feature requests can be sent directly to the developers: **https://t.me/etonify?direct**.\n\nBy continuing, you confirm that you have read these terms and accept responsibility for using the app.';

  @override
  String get legalPrivacyBody =>
      '# Etonify Privacy Policy\n\n## Summary\n\nEtonify has **no advertising, analytics SDKs, or hidden tracking**. MeowTeam does not sell user data or automatically receive your VPN keys.\n\n## Data stored on the device\n\nSubscriptions, profiles, selected servers, settings, diagnostic logs, and downloaded rule files are stored locally. Backups and exports may contain access keys, so keep them private.\n\n## Network requests\n\n- Subscription imports and refreshes contact the address supplied by the user. That server can see normal request information, including the IP address.\n- Client and routing-rule update checks contact GitHub and the sources named in the interface.\n- HWID is sent to a subscription service only for profiles where the user enables it.\n\n## Android permissions\n\n- **VPN service** creates the system VPN tunnel.\n- **QUERY_ALL_PACKAGES** is used only to display installed apps for split tunneling. The app list is not sent to MeowTeam.\n- **Camera** is used only to scan QR codes.\n- **Notifications** display VPN service state.\n- **APK installation** is used only for user-approved updates. Android shows a separate system confirmation.\n\n## Logs and messages\n\nLogs are stored locally until the user exports or sends them. Review exported files before sharing publicly. Information voluntarily sent through Telegram is handled under Telegram\'s rules.\n\nPrivacy questions can be sent directly to the developers: **https://t.me/etonify?direct**.';

  @override
  String get coreVersionLabel => 'Core version';

  @override
  String get debugMenuTitle => 'Debug';

  @override
  String get debugMenuSubtitle =>
      'Hidden area for debugging and service actions.';

  @override
  String get debugNetworkHeartbeatTitle => 'Network heartbeat';

  @override
  String debugNetworkHeartbeatSubtitle(int seconds) {
    return 'Re-asserts the default network if Android misses callbacks. Current interval: ${seconds}s. Applies on next VPN start.';
  }

  @override
  String get debugWakeLockTitle => 'Partial wake lock';

  @override
  String get debugWakeLockSubtitle =>
      'Keeps CPU awake while VPN runs. Off by default because it can heat the phone on aggressive firmware.';

  @override
  String get debugRecordSnapshot => 'Record performance snapshot';

  @override
  String get debugSnapshotDone => 'Performance snapshot added to logs';

  @override
  String get debugRuntimeMeasurementTitle => 'Background runtime measurement';

  @override
  String get debugRuntimeMeasurementSubtitle =>
      'Measures CPU, memory, core tasks, connections and routed traffic every 5 seconds. It runs only while started and never changes VPN routing.';

  @override
  String debugRuntimeMeasurementDuration(String duration) {
    return 'Duration: $duration';
  }

  @override
  String debugRuntimeMeasurementProgress(String elapsed, String duration) {
    return 'Running: $elapsed of $duration';
  }

  @override
  String get debugRuntimeMeasurementStart => 'Start measurement';

  @override
  String get debugRuntimeMeasurementStop => 'Stop measurement';

  @override
  String get debugRuntimeMeasurementSave => 'Save report';

  @override
  String get debugRuntimeMeasurementIdle => 'Ready to measure';

  @override
  String get debugRuntimeMeasurementCompleted => 'Measurement completed';

  @override
  String get debugRuntimeMeasurementStopped => 'Measurement stopped';

  @override
  String get debugRuntimeMeasurementCollecting => 'Collecting data…';

  @override
  String get debugRuntimeMeasurementHealthy =>
      'No abnormal resource growth was detected.';

  @override
  String get debugRuntimeMeasurementHighCpu =>
      'High CPU with low routed traffic. This suggests background native/core work rather than normal transfer load.';

  @override
  String get debugRuntimeMeasurementGoroutineGrowth =>
      'Core task count increased during the measurement.';

  @override
  String get debugRuntimeMeasurementMemoryGrowth =>
      'Process memory grew noticeably during the measurement.';

  @override
  String get debugRuntimeMeasurementConnectionChurn =>
      'Many core connections were present while traffic was low.';

  @override
  String get debugRuntimeMeasurementUnavailable =>
      'Not enough data for an assessment yet.';

  @override
  String get debugRuntimeMeasurementSaved =>
      'Measurement report is ready to save';

  @override
  String get teamPageTitle => 'MeowTeam';

  @override
  String get teamIntroTitle => 'The team behind Etonify';

  @override
  String get teamIntroBody =>
      'MeowTeam is two developers building Etonify, its core, and networking components together as an independent open-source project.';

  @override
  String get teamTimelineForkTitle => 'Early client development';

  @override
  String get teamTimelineForkBody =>
      'Early test versions helped define the Android runtime, subscription handling, diagnostics, and interface that Etonify now maintains.';

  @override
  String get teamTimelineRefactorTitle => 'Large refactor';

  @override
  String get teamTimelineRefactorBody =>
      'We gradually split the large legacy code into focused components, simplified VPN control, and added checks for critical scenarios.';

  @override
  String get teamTimelineCoreTitle => 'Moving to etonify-core';

  @override
  String get teamTimelineCoreBody =>
      'After MeowSingBox, the client moved to a more stable sing-box base with the changes Etonify needs. Maintaining our own core makes updates and testing easier, while URLTest, server failover, and resource-cleanup improvements benefit everyday use.';

  @override
  String get teamTimelineNowTitle => 'Etonify today';

  @override
  String get teamTimelineNowBody =>
      'Etonify is still evolving: we keep simplifying UX, improving Android stability, and cutting technical debt without losing the speed-focused VPN experience.';

  @override
  String get teamDeveloperDdosxdRole =>
      'Core, networking, and custom protocols';

  @override
  String get teamDeveloperYamixdevRole =>
      'Android client, interface, core, and releases';

  @override
  String get teamDeveloperVerificationInfo => 'Member of MeowTeam.';

  @override
  String get teamTelegramRole => 'Official channel and release news';

  @override
  String get languageSettingTitle => 'Language';

  @override
  String get themeSettingTitle => 'Theme';

  @override
  String get accentColorTitle => 'Accent color';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Russian';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeAmoled => 'AMOLED';

  @override
  String get diagnosticsTitle => 'Resources & diagnostics';

  @override
  String get diagnosticsSubtitle => 'Memory, core status, and diagnostics.';

  @override
  String get aboutResourcesTitle => 'Resources';

  @override
  String get aboutResourcesSubtitle =>
      'On-demand Android and core snapshot. CPU is measured over one second.';

  @override
  String get aboutResourcesPssTitle => 'Process memory';

  @override
  String get aboutResourcesPssSubtitle =>
      'PSS is the primary memory estimate including a share of common pages. RSS counts every resident page, Private Dirty covers modified pages owned only by this process, and Swap PSS is its proportional swap share. Do not add these values together.';

  @override
  String get aboutResourcePss => 'Total PSS';

  @override
  String get aboutResourceRss => 'Total RSS';

  @override
  String get aboutResourceSwapPss => 'Swap PSS';

  @override
  String get aboutResourcePrivateDirty => 'Private Dirty';

  @override
  String get aboutResourceNativePss => 'Native PSS';

  @override
  String get aboutResourceDalvikPss => 'Android VM PSS';

  @override
  String get aboutResourceOtherPss => 'Other PSS';

  @override
  String get aboutResourceGraphicsPss => 'Graphics PSS';

  @override
  String get aboutResourceCodePss => 'Code PSS';

  @override
  String get aboutResourceStackPss => 'Stack PSS';

  @override
  String get aboutResourcesRuntimeTitle => 'Client and core';

  @override
  String get aboutResourceNativeHeap => 'Native heap';

  @override
  String get aboutResourceJavaHeap => 'Java heap';

  @override
  String get aboutResourceCoreMemory => 'Process RSS reported by core';

  @override
  String get aboutResourceFlutterImageCache => 'Flutter image cache';

  @override
  String get aboutResourceCoreGoroutines => 'Core goroutines';

  @override
  String get aboutResourceCoreConnections => 'Core connections (in / out)';

  @override
  String get aboutResourcesSystemTitle => 'System';

  @override
  String get aboutResourceProcessCpu => 'Process CPU, all cores';

  @override
  String get aboutResourceSystemMemory => 'Free system RAM';

  @override
  String get aboutResourceBatteryTemp => 'Battery temperature';

  @override
  String get updatesTitle => 'App updates';

  @override
  String get updatesSubtitle => 'Check for a new version and install it.';

  @override
  String get updatesChecking => 'Checking for updates…';

  @override
  String get updatesCheckAction => 'Check now';

  @override
  String get updatesChannelMenuAction => 'Update channel';

  @override
  String get updatesChannelTitle => 'Update channel';

  @override
  String get updatesChannelStable => 'Stable';

  @override
  String get updatesChannelStableSubtitle =>
      'Stable releases for everyday use.';

  @override
  String get updatesChannelBeta => 'Beta';

  @override
  String get updatesChannelBetaSubtitle =>
      'Test alpha, beta, and RC builds published as GitHub prereleases.';

  @override
  String get updatesChannelBetaWarning =>
      'Test builds may contain bugs. You can return to Stable when a stable build becomes newer than the installed build.';

  @override
  String get updatesPrereleaseVersionTooltip => 'Test build';

  @override
  String get updatesRetryAction => 'Retry';

  @override
  String get updatesUnsupportedAndroidTitle => 'Update not supported';

  @override
  String updatesUnsupportedAndroidSubtitle(String version, int minSdk) {
    return 'Version $version requires Android SDK $minSdk or newer. This device can keep using the latest compatible release.';
  }

  @override
  String get updatesDownloadAction => 'Download update';

  @override
  String get updatesInstallAction => 'Install APK';

  @override
  String get updatesDownloadWarning =>
      'Keep Etonify open until the download finishes.';

  @override
  String get updatesOpeningInstaller => 'Opening the system installer…';

  @override
  String get updatesInstallPermissionHint =>
      'Allow APK installs for Etonify, then tap “Install APK” again.';

  @override
  String get updatesInstallPermissionTitle => 'Permission required';

  @override
  String get updatesInstallPermissionMessage =>
      'Allow Etonify to install unknown apps before it can open the downloaded APK installer. Without this permission you can only download the file manually.';

  @override
  String get updatesInstallPermissionOpen => 'Open settings';

  @override
  String get updatesInstallPermissionGranted =>
      'APK install permission is enabled.';

  @override
  String get updatesInstallModeTitle => 'Update installation';

  @override
  String get updatesInstallModeAsk => 'Ask every time';

  @override
  String get updatesInstallModeAskSubtitle =>
      'Etonify will ask whether to download manually or install automatically.';

  @override
  String get updatesInstallModeManual => 'Manual';

  @override
  String get updatesInstallModeManualSubtitle =>
      'The client downloads the APK and shows an install button.';

  @override
  String get updatesInstallModeAuto => 'Automatic';

  @override
  String get updatesInstallModeAutoSubtitle =>
      'The client downloads the APK and opens the Android installer.';

  @override
  String get updatesInstallMethodTitle =>
      'How should this update be installed?';

  @override
  String get updatesInstallMethodManualTitle => 'Download manually';

  @override
  String get updatesInstallMethodManualSubtitle =>
      'The APK is saved in the update cache. You can install it later.';

  @override
  String get updatesInstallMethodAutoTitle => 'Download and install';

  @override
  String get updatesInstallMethodAutoSubtitle =>
      'After download, Etonify opens the Android system installer.';

  @override
  String get updatesInstallMethodRemember => 'Remember this choice';

  @override
  String get updatesApkVerificationTitle => 'APK check';

  @override
  String get updatesApkVerificationVerified => 'SHA-256 matches';

  @override
  String get updatesApkVerificationUnavailable =>
      'SHA-256 is not provided by this release';

  @override
  String get updatesApkVerificationFailed => 'SHA-256 does not match';

  @override
  String get updatesDownloadedFileMissing =>
      'The update file is missing. Download the APK again.';

  @override
  String get updatesDeleteCachedApkAction => 'Delete installer APK';

  @override
  String get updatesDeleteCachedApkTitle => 'Delete installer APK?';

  @override
  String updatesDeleteCachedApkMessage(Object version) {
    return 'This will delete the downloaded $version update APK and old temporary Etonify APK files from the app cache.';
  }

  @override
  String updatesDeleteCachedApkDone(int count) {
    return 'Update cache cleaned. Files deleted: $count.';
  }

  @override
  String get updatesUpToDateTitle => 'Etonify is up to date';

  @override
  String updatesUpToDateSubtitle(String version) {
    return 'Installed version: $version';
  }

  @override
  String get updatesCurrentVersionNewerTitle => 'Installed version is newer';

  @override
  String updatesCurrentVersionNewerSubtitle(
    String currentVersion,
    String channelVersion,
  ) {
    return 'Installed: $currentVersion. Selected channel: $channelVersion. No update is required.';
  }

  @override
  String get updatesNoChannelReleaseTitle => 'No releases in this channel yet';

  @override
  String get updatesNoBetaReleaseSubtitle =>
      'No Etonify prerelease has been published on GitHub yet.';

  @override
  String get updatesNoStableReleaseSubtitle =>
      'No stable Etonify release has been published on GitHub yet.';

  @override
  String get updatesAvailableTitle => 'Update available';

  @override
  String updatesAvailableSubtitle(String version, String size) {
    return '$version · $size';
  }

  @override
  String get updatesAvailableSnack => 'Client update available';

  @override
  String updatesAvailableSnackVersion(Object version) {
    return 'Client update $version is available';
  }

  @override
  String get updatesOpenAction => 'Open';

  @override
  String get updatesDownloadingTitle => 'Downloading update';

  @override
  String get updatesStageCleaning => 'Removing old files…';

  @override
  String get updatesStageVerifying => 'Verifying APK and signature…';

  @override
  String get updatesDownloadedTitle => 'Update downloaded';

  @override
  String updatesDownloadedSubtitle(String fileName) {
    return 'Saved to app update cache: $fileName';
  }

  @override
  String get updatesErrorTitle => 'Could not check updates';

  @override
  String get updatesErrorSubtitle =>
      'If GitHub is blocked on this network, Etonify will try again tomorrow.';

  @override
  String get updatesCurrentVersion => 'Current version';

  @override
  String get updatesLatestVersion => 'Latest version';

  @override
  String get updatesAsset => 'APK';

  @override
  String updatesLastChecked(String time) {
    return 'Last checked: $time';
  }

  @override
  String get updatesReleaseNotesTitle => 'What\'s new';

  @override
  String get updatesNoReleaseNotes => 'This release does not include notes.';

  @override
  String updatesProgressBytes(String downloaded, String total) {
    return '$downloaded / $total';
  }

  @override
  String updatesProgressSpeedEta(String speed, String eta) {
    return '$speed/s · $eta left';
  }

  @override
  String updatesEtaSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String updatesEtaMinutes(int minutes, int seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String get updatesUnknownSize => 'Unknown size';

  @override
  String get appVersionLabel => 'App version';

  @override
  String get currentProfileLabel => 'Current profile';

  @override
  String get selectedProxyLabel => 'Selected proxy';

  @override
  String get onboardingStatusLabel => 'Intro';

  @override
  String get onboardingSeen => 'Completed';

  @override
  String get showOnboardingAgain => 'Show intro again';

  @override
  String get settingsFootnote =>
      'These settings are local to this device and are stored in Hive.';

  @override
  String get connected => 'Connected';

  @override
  String get tapToConnect => 'Tap to Connect';

  @override
  String get resolvingIp => 'Resolving IP…';

  @override
  String get millisecondsUnit => ' ms';

  @override
  String get refreshLatency => 'Refresh latency';

  @override
  String get checkingLatency => 'Checking latency';

  @override
  String get checkingLatencyShort => 'Checking…';

  @override
  String get openTrafficDashboard => 'Open traffic dashboard';

  @override
  String get refreshActiveSubscription => 'Refresh current subscription';

  @override
  String get refreshActiveSubscriptionUnavailable =>
      'Manual imports cannot be refreshed';

  @override
  String activeSubscriptionRefreshComplete(String name) {
    return '$name updated';
  }

  @override
  String get trafficDashboardTitle => 'Traffic dashboard';

  @override
  String get trafficDashboardSubtitle =>
      'Live speed, session totals, and connection info';

  @override
  String get trafficDashboardDownload => 'Download';

  @override
  String get trafficDashboardUpload => 'Upload';

  @override
  String get trafficDashboardSessionTraffic => 'Session traffic';

  @override
  String get trafficDashboardConnectedFor => 'Connected for';

  @override
  String get trafficDashboardGraphTitle => 'Live traffic';

  @override
  String trafficDashboardGraphMax(String speed) {
    return 'Peak $speed';
  }

  @override
  String get trafficDashboardNoSamples => 'Waiting for traffic data';

  @override
  String get trafficDashboardConnectionState => 'Connection';

  @override
  String get trafficDashboardCurrentProfile => 'Profile';

  @override
  String get trafficDashboardActiveProxy => 'Proxy';

  @override
  String get trafficDashboardServerIp => 'Server IP';

  @override
  String get trafficDashboardDownloadTotal => 'Downloaded';

  @override
  String get trafficDashboardUploadTotal => 'Uploaded';

  @override
  String get trafficDashboardStateConnected => 'Connected';

  @override
  String get trafficDashboardStateConnecting => 'Connecting';

  @override
  String get trafficDashboardStateDisconnected => 'Disconnected';

  @override
  String trafficDashboardUptimeHours(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String trafficDashboardUptimeMinutes(int minutes, int seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String trafficDashboardUptimeSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get notAvailableShort => 'N/A';

  @override
  String daysLeft(int days) {
    return '$days days left';
  }

  @override
  String get daysLeftUnlimited => '∞ days left';

  @override
  String get unlimitedTraffic => 'Unlimited';

  @override
  String get unlimitedSymbol => '∞';

  @override
  String get welcomeGreeting => 'Hi';

  @override
  String get welcomeTitlePrefix => 'Welcome to';

  @override
  String get welcomeSubtitle => 'Fast Android VPN client';

  @override
  String get welcomeTapHint => 'tap anywhere to continue';

  @override
  String get hapticTitle => 'Vibration';

  @override
  String get hapticSubtitle => 'Light vibration for important actions';

  @override
  String get statusNotificationTitle => 'Notification status';

  @override
  String get statusNotificationSubtitle =>
      'Shows the selected server, speed, and latency while VPN is active.';

  @override
  String get notificationSettingsTitle => 'VPN notification';

  @override
  String get notificationSettingsSubtitle =>
      'Server, traffic, latency, and refresh rate.';

  @override
  String get notificationTrafficDisplayTitle => 'What to show in notification';

  @override
  String get notificationTrafficDisplaySubtitle =>
      'Current speed, total transferred, or both.';

  @override
  String get notificationTrafficDisplaySpeed => 'Current speed';

  @override
  String get notificationTrafficDisplayTotal => 'Total transferred';

  @override
  String get notificationTrafficDisplayBoth => 'Speed and total';

  @override
  String get notificationTrafficTotalLabel => 'Total traffic';

  @override
  String get notificationTrafficRefreshTitle => 'Traffic refresh';

  @override
  String get notificationTrafficRefreshSubtitle =>
      'How often to update data in the notification.';

  @override
  String notificationTrafficRefreshSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get notificationConnected => 'VPN connected';

  @override
  String get notificationPingChecking => '...';

  @override
  String get notificationPingUnavailable => 'Latency unavailable';

  @override
  String get notificationRefreshPingAction => 'Refresh latency';

  @override
  String get notificationStopAction => 'Stop';

  @override
  String get hideServerIpTitle => 'Hide server IP';

  @override
  String get hideServerIpSubtitle => 'Masks last two octets of the IP address';

  @override
  String get memoryLimitTitle => 'Soft core memory limit';

  @override
  String get memoryLimitEnabledSubtitle =>
      'Optional adaptive limit for memory managed by the Go part of sing-box. The value is applied immediately and does not limit the whole app.';

  @override
  String get memoryLimitDisabledSubtitle =>
      'Disabled. The Go part of sing-box manages memory without an Etonify budget and may retain more RAM. Takes effect after app restart.';

  @override
  String get memoryLimitDisableWarningTitle => 'Disable the soft core limit?';

  @override
  String get memoryLimitDisableWarningMessage =>
      'Without the soft limit, the Go part of sing-box may retain unused memory for longer. This does not change Flutter or Android memory limits and does not affect system process termination. The change takes effect after restarting Etonify.';

  @override
  String get memoryLimitDisableConfirm => 'Disable';

  @override
  String get enableInboundTitle => 'Enabled';

  @override
  String get vpnInDescription =>
      'VPN TUN is the Android system VPN path for phone traffic. Apps see an Android VPN, while routing decides what goes through proxy or direct.';

  @override
  String get vpnInboundEnabledSubtitle =>
      'Creates a VPN TUN inbound and routes traffic through it';

  @override
  String get inboundNoneEnabled =>
      'Enable VPN TUN or Proxy In before starting.';

  @override
  String get mtuTitle => 'MTU';

  @override
  String get mtuSubtitle => 'TUN interface packet size';

  @override
  String get mtuInputRange => 'Enter a value from 1280 to 9000.';

  @override
  String get mtuInvalidValue => 'Use a value from 1280 to 9000.';

  @override
  String get strictRouteTitle => 'Prevent VPN bypass';

  @override
  String get strictRouteSubtitle =>
      'Forces traffic through VPN and reduces the chance of traffic escaping the tunnel';

  @override
  String get tunImplementationTitle => 'TUN network stack';

  @override
  String get tunImplementationSubtitle =>
      'Controls how the client handles TCP and UDP traffic inside the VPN';

  @override
  String get tunImplementationMixed => 'Mixed (system TCP + gVisor UDP)';

  @override
  String get tunImplementationMixedSubtitle =>
      'Uses the Android system stack for TCP and gVisor for UDP. This is sing-box\'s default when gVisor is available.';

  @override
  String get tunImplementationSystem => 'System (Android)';

  @override
  String get tunImplementationSystemSubtitle =>
      'Uses the Android system network stack for TCP and UDP. Compatibility depends on the device and its firmware.';

  @override
  String get tunImplementationGvisor => 'gVisor';

  @override
  String get tunImplementationGvisorSubtitle =>
      'Uses the gVisor userspace network stack for TCP and UDP. It can help when the system stack is unstable.';

  @override
  String get proxyInDescription =>
      'Proxy In / mixed is a local HTTP/SOCKS entry for apps or other devices that you configure manually. It is not the Android system VPN.';

  @override
  String get proxyInboundEnabledSubtitle =>
      'Starts a local mixed inbound for apps and devices';

  @override
  String get allowLanConnectionsTitle => 'Allow LAN connections';

  @override
  String get allowLanConnectionsSubtitle =>
      'If enabled, listen on 0.0.0.0, otherwise on 127.0.0.1';

  @override
  String get portTitle => 'Port';

  @override
  String get proxyPortSubtitle => 'Local mixed inbound port';

  @override
  String get connectionModeTitle => 'Connection mode';

  @override
  String get connectionModeSubtitle =>
      'VPN covers the whole phone. Local proxy is used only by apps and devices configured with its address manually.';

  @override
  String get connectionModeVpn => 'VPN';

  @override
  String get connectionModeVpnSubtitle =>
      'System Android VPN for all phone traffic';

  @override
  String get connectionModeProxy => 'Proxy';

  @override
  String get connectionModeProxySubtitle =>
      'Local HTTP/SOCKS without a system VPN';

  @override
  String connectionModeActiveStatus(String mode) {
    return 'Active: $mode';
  }

  @override
  String get connectionModeVpnStatusName => 'VPN TUN';

  @override
  String get connectionModeProxyStatusName => 'Proxy';

  @override
  String get advancedTunTitle => 'Advanced TUN settings';

  @override
  String get advancedTunSubtitle =>
      'MTU, strict routing, and network stack implementation';

  @override
  String get localProxyTitle => 'Local proxy';

  @override
  String get localProxySubtitle =>
      'Additional HTTP/SOCKS endpoint for manually configured apps';

  @override
  String get localProxySettingsSubtitle =>
      'Address, port, and access credentials';

  @override
  String get lanProxySecurityTitle => 'Access protected';

  @override
  String get lanProxySecuritySubtitle =>
      'LAN devices must provide the username and password. Authentication prevents unauthorized use but does not encrypt the local network by itself.';

  @override
  String get proxyUsernameTitle => 'Username';

  @override
  String get proxyUsernameSubtitle =>
      '1–64 characters, without spaces or a colon';

  @override
  String get proxyPasswordTitle => 'Password';

  @override
  String get regenerateProxyPasswordTitle => 'Change password';

  @override
  String get copyProxyCredentialsTitle => 'Copy connection details';

  @override
  String get proxyCredentialsCopied => 'Proxy connection details copied';

  @override
  String get proxyEndpointTitle => 'Address';

  @override
  String get proxyLanAddressHint => 'Phone IP';

  @override
  String get dnsUsePresetTitle => 'Use preset';

  @override
  String get dnsResolverTitle => 'Resolver';

  @override
  String get dnsDirectPresetSubtitle => 'Recommended: udp://1.1.1.1';

  @override
  String get dnsDirectResolverSubtitle =>
      'DNS for direct requests without proxy';

  @override
  String get dnsProxyPresetSubtitle =>
      'Recommended: https://dns.cloudflare.com/dns-query';

  @override
  String get dnsProxyResolverSubtitle => 'DNS for requests through proxy';

  @override
  String get dnsResolverTypeTitle => 'Resolver type';

  @override
  String get dnsPresetDevice => 'Device network';

  @override
  String get dnsPresetCustom => 'Custom';

  @override
  String get dnsPresetDeviceSubtitle =>
      'Use DNS from the current Android network.';

  @override
  String get dnsPresetCustomSubtitle =>
      'Enter an IP/host (UDP by default) or use udp://, tcp://, tls://, or https://.';

  @override
  String get dnsPresetUdpSubtitle => 'Plain UDP DNS. Fast, but not encrypted.';

  @override
  String get dnsPresetTcpSubtitle =>
      'Plain TCP DNS. More stable on some networks, but not encrypted.';

  @override
  String get dnsPresetTlsSubtitle => 'DNS over TLS. Encrypted DNS on port 853.';

  @override
  String get dnsPresetHttpsSubtitle =>
      'DNS over HTTPS. Encrypted DNS over HTTPS, often best through proxy.';

  @override
  String get dnsProtectionTitle => 'Protection';

  @override
  String get dnsSecureOnlyTitle => 'Encrypted DNS only';

  @override
  String get dnsSecureOnlySubtitle =>
      'Allow only DoH and DoT. Plain UDP, TCP and device DNS are not used.';

  @override
  String get dnsDirectThroughProxyTitle => 'Direct DNS via proxy';

  @override
  String get dnsDirectThroughProxySubtitle =>
      'Protect DNS for direct routes while website traffic stays direct.';

  @override
  String get dnsPreferIpv6Title => 'Prefer IPv6';

  @override
  String get dnsPreferIpv6Subtitle =>
      'Prefer IPv6 when both address versions are available';

  @override
  String get urlTestUrlTitle => 'Test URL';

  @override
  String get urlTestUrlSubtitle =>
      'If the subscription already defines a value, that value is used';

  @override
  String get urlTestIntervalTitle => 'Interval, sec.';

  @override
  String get urlTestIntervalCompactTitle => 'Check interval';

  @override
  String get urlTestIntervalSubtitle =>
      'How often proxies are checked for automatic selection';

  @override
  String get urlTestTimeoutTitle => 'Timeout, sec.';

  @override
  String get urlTestTimeoutCompactTitle => 'Test timeout';

  @override
  String get urlTestTimeoutSubtitle =>
      'How long to wait for one proxy test before failing it';

  @override
  String get urlTestConcurrencyTitle => 'Test concurrency';

  @override
  String get urlTestConcurrencySubtitle =>
      'How many proxies URLTest checks at the same time';

  @override
  String get urlTestSingleRetestTitle => 'Quick retry delay, sec.';

  @override
  String get urlTestSingleRetestCompactTitle => 'Quick retry';

  @override
  String get urlTestSingleRetestSubtitle =>
      'How long to wait before one quick recheck after a proxy fails';

  @override
  String get locationLookupTitle => 'Locations';

  @override
  String get locationLookupSubtitle =>
      'IP and country through the proxies themselves';

  @override
  String get locationLookupLimitTitle => 'Check best proxies';

  @override
  String get locationLookupLimitSubtitle =>
      'After URLTest, the app resolves external IP and country for this many fastest outbounds';

  @override
  String get locationLookupTimeoutTitle => 'Request timeout';

  @override
  String get locationLookupTimeoutSubtitle =>
      'How long to wait for external IP and country for one server';

  @override
  String get locationLookupConcurrencyTitle => 'Parallel requests';

  @override
  String get locationLookupConcurrencySubtitle =>
      'How many location requests may run at the same time';

  @override
  String settingsSecondsShort(int seconds) {
    return '${seconds}s';
  }

  @override
  String get serverRequestTitle => 'Server request';

  @override
  String get sendHwidTitle => 'Send HWID';

  @override
  String get sendHwidSubtitle => 'Required by some Happ subscriptions';

  @override
  String get useCustomHwidTitle => 'Set a custom HWID';

  @override
  String get useCustomHwidSubtitle => 'Use it instead of this device\'s HWID';

  @override
  String get customUserAgentTitle => 'Custom User-Agent';

  @override
  String get customUserAgentSubtitle =>
      'Overrides the default Etonify user agent for this subscription';

  @override
  String get customHwidTitle => 'Custom HWID';

  @override
  String get customHwidSubtitle => 'Leave empty to use the device HWID';

  @override
  String get customRequestHeadersTitle => 'Custom headers';

  @override
  String get customRequestHeadersSubtitle =>
      'One header per line in Header: value format';

  @override
  String get hwidTitle => 'HWID';

  @override
  String get hwidSubtitle =>
      'Your device identifier used by some subscription providers';

  @override
  String get hwidValueTitle => 'Your HWID';

  @override
  String get coreStartFailedTitle => 'Failed to start core';

  @override
  String coreStartFailedMessage(String message) {
    return 'sing-box failed to start.\n\n$message';
  }

  @override
  String get vpnStopFailed =>
      'VPN did not stop completely. Open logs and try again.';

  @override
  String get clearLogsTitle => 'Clear logs';

  @override
  String get logsFilterTitle => 'Filter';

  @override
  String get logsFilterAll => 'All';

  @override
  String get singBoxLogLevelTitle => 'sing-box log level';

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
  String get noLogsTitle => 'No logs yet';

  @override
  String get continueLabel => 'Get started';

  @override
  String get subscriptionsTab => 'Subscriptions';

  @override
  String get subscriptionsTitle => 'Subscriptions';

  @override
  String get settingsProfilesChecksTitle => 'Subscriptions and checks';

  @override
  String get settingsProfilesChecksSubtitle =>
      'Server checks · HWID · profile options';

  @override
  String get addSubscription => 'Add subscription';

  @override
  String get addSubscriptionQuickTitle => 'Add profile';

  @override
  String get addSubscriptionQuickSubtitle =>
      'Choose how to import a subscription.';

  @override
  String get addSubscriptionFromClipboard => 'Clipboard';

  @override
  String get addSubscriptionManual => 'Manual';

  @override
  String get addSubscriptionReadingClipboard => 'Reading clipboard…';

  @override
  String get addSubscriptionReadingFile => 'Reading file…';

  @override
  String get addSubscriptionImporting => 'Importing subscription…';

  @override
  String get addSubscriptionSaving => 'Saving profile…';

  @override
  String get addSubscriptionDone => 'Subscription added';

  @override
  String get clipboardEmpty => 'Clipboard is empty';

  @override
  String get scanQrCode => 'Scan QR';

  @override
  String get showQrCode => 'Show QR';

  @override
  String get subscriptionQrTitle => 'Subscription QR';

  @override
  String get subscriptionQrHint =>
      'Scan this code on another device to import the subscription.';

  @override
  String get subscriptionQrUnsupported =>
      'This subscription cannot be shared as QR yet.';

  @override
  String get invalidQrSubscription =>
      'The QR code does not contain a supported subscription link.';

  @override
  String get subscriptionUrl => 'Subscription URL';

  @override
  String get editSubscriptionUrlAction => 'Edit URL';

  @override
  String get saveAction => 'Save';

  @override
  String get subscriptionUrlEditHint =>
      'A profile can update from one URL. If an old import glued several links together, keep the required line and add the other sources as separate profiles. Refresh the subscription after saving.';

  @override
  String get subscriptionUrlSingleSourceRequired =>
      'Keep one URL. Add the other sources as separate profiles.';

  @override
  String get subscriptionUrlOrContent => 'URL or content';

  @override
  String get subscriptionUrlOrContentHint =>
      'Paste a URL, vless:// link, link list, or config';

  @override
  String get importFromFile => 'From file';

  @override
  String get invalidSubscriptionFile => 'Failed to read the subscription file';

  @override
  String get backupUseSettingsImport =>
      'This is an Etonify backup. Import it from Settings → Import.';

  @override
  String get subscriptionName => 'Name (optional)';

  @override
  String get add => 'Add';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get refresh => 'Refresh';

  @override
  String get reparseProxies => 'Reparse proxies';

  @override
  String get subscriptionLocalImportBadge => 'Local import';

  @override
  String get refreshAll => 'Refresh all';

  @override
  String get refreshSubscriptions => 'Refresh subscriptions';

  @override
  String get subscriptionSortTitle => 'Sort subscriptions';

  @override
  String get subscriptionSortManual => 'Current order';

  @override
  String get subscriptionSortByName => 'By name';

  @override
  String get subscriptionSortByUpdated => 'By last update';

  @override
  String get subscriptionSortByServers => 'By proxy count';

  @override
  String get subscriptionActionsTitle => 'Subscription actions';

  @override
  String get subscriptionCopyUrl => 'URL to clipboard';

  @override
  String get subscriptionShowUrlQr => 'Show URL QR code';

  @override
  String get subscriptionUrlCopied => 'Subscription URL copied';

  @override
  String get subscriptionImportHelpTitle => 'How to add a subscription';

  @override
  String get subscriptionImportHelpBody =>
      'Copy the subscription link from your provider and tap Clipboard, or scan a QR code. If the link is not recognized, open Manual and paste a URL, vless:// link, key list, or sing-box/Xray config. For Happ subscriptions, enable User-Agent or HWID in manual import when your provider requires it.';

  @override
  String subscriptionsRefreshAllComplete(int updated, int failed) {
    return 'Updated $updated subscriptions, $failed failed';
  }

  @override
  String subscriptionsRefreshAllProgress(int completed, int total) {
    return 'Updating $completed of $total';
  }

  @override
  String get deleteSubscription => 'Delete subscription?';

  @override
  String get deleteSubscriptionConfirm =>
      'This will remove all proxies from this subscription.';

  @override
  String get subscriptionDetailsTitle => 'Subscription';

  @override
  String get subscriptionMovedTitle => 'Subscription moved';

  @override
  String get ignoreAction => 'Ignore';

  @override
  String get updateUrlAction => 'Update URL';

  @override
  String get autoUpdateTitle => 'Auto update';

  @override
  String get disableAutoUpdateTitle => 'Disable auto update';

  @override
  String get disabledLabel => 'Disabled';

  @override
  String refreshesEvery(String interval) {
    return 'Refreshes every: $interval';
  }

  @override
  String get usageTitle => 'Usage';

  @override
  String spentTraffic(String usage) {
    return 'Spent $usage';
  }

  @override
  String untilDate(String date) {
    return 'Until $date';
  }

  @override
  String get infoTitle => 'Information';

  @override
  String get supportUrlLabel => 'Support';

  @override
  String get websiteLabel => 'Website';

  @override
  String get newUrlTitle => 'NewURL';

  @override
  String get movedSubscriptionMessage =>
      'The server reported that this subscription moved to a new URL.';

  @override
  String get movedSubscriptionPrompt =>
      'The server reports a new subscription URL. Update it now or keep the current one?';

  @override
  String get noSubscriptions => 'No subscriptions yet';

  @override
  String get noProxies => 'No proxies';

  @override
  String get noSubscriptionsHint => 'Tap + to add a subscription URL';

  @override
  String outboundsCount(int count) {
    return '$count proxies';
  }

  @override
  String subscriptionServersCount(int count) {
    return '$count proxies';
  }

  @override
  String get subscriptionReparseRecommended => 'Reparse needed';

  @override
  String get subscriptionProxyTypeLabel => 'Proxies';

  @override
  String moreProxies(int count) {
    return '…$count more proxies';
  }

  @override
  String lastUpdatedDateTime(String date, String time) {
    return 'Updated $date at $time';
  }

  @override
  String trafficUsage(String used, String total) {
    return '$used / $total';
  }

  @override
  String get expired => 'Expired';

  @override
  String get loading => 'Loading…';

  @override
  String get error => 'Error';

  @override
  String get invalidUrl => 'Please enter a valid URL';

  @override
  String get fetchFailed => 'Failed to fetch subscription';

  @override
  String get subscriptionSavedWithFetchWarning =>
      'The subscription was saved, but the server did not respond. You can change HWID or headers and refresh it later.';

  @override
  String subscriptionSavedWithFetchWarningReason(String reason) {
    return 'The subscription was saved without servers. Reason: $reason Fix the link, HWID, or headers, then refresh it.';
  }

  @override
  String get subscriptionErrorInvalidUrl =>
      'The subscription link is invalid. Copy it again and make sure it starts with http:// or https://.';

  @override
  String get subscriptionErrorHttpsRequired =>
      'This subscription sends an HWID or credentials, so it can only be loaded over HTTPS.';

  @override
  String get subscriptionErrorUnsafeRedirect =>
      'The subscription server tried to redirect from HTTPS to insecure HTTP. Etonify blocked the redirect.';

  @override
  String get subscriptionErrorRedirect =>
      'The subscription link redirects incorrectly or too many times. Ask the provider for a direct link.';

  @override
  String get subscriptionErrorHttp400 =>
      'The server rejected the request (HTTP 400). Check the link and its parameters.';

  @override
  String get subscriptionErrorHttp401 =>
      'Authorization failed (HTTP 401). The token, login, or HWID may be invalid.';

  @override
  String get subscriptionErrorHttp402 =>
      'Payment is required (HTTP 402). Renew the subscription or contact the provider.';

  @override
  String get subscriptionErrorHttp403 =>
      'Access is denied (HTTP 403). The subscription may be expired, blocked, or require the correct HWID.';

  @override
  String get subscriptionErrorHttp404 =>
      'Subscription not found (HTTP 404). The link may have been removed or copied incorrectly.';

  @override
  String get subscriptionErrorHttp408 =>
      'The subscription server timed out (HTTP 408). Try again later.';

  @override
  String get subscriptionErrorHttp410 =>
      'The subscription has expired or was removed (HTTP 410). Request a new link from the provider.';

  @override
  String get subscriptionErrorHttp429 =>
      'Too many requests (HTTP 429). Wait a little before trying again.';

  @override
  String get subscriptionErrorHttp500 =>
      'The subscription server has an internal error (HTTP 500). This is a provider-side problem.';

  @override
  String get subscriptionErrorHttp502 =>
      'The subscription gateway is unavailable (HTTP 502). The provider cannot reach its upstream server right now.';

  @override
  String get subscriptionErrorHttp503 =>
      'The subscription service is temporarily unavailable (HTTP 503), possibly due to maintenance.';

  @override
  String get subscriptionErrorHttp504 =>
      'The provider\'s upstream server did not respond in time (HTTP 504). Try again later.';

  @override
  String subscriptionErrorHttpStatus(int status) {
    return 'The subscription server returned HTTP $status. Check the provider status or ask for a new link.';
  }

  @override
  String get subscriptionErrorDns =>
      'The subscription host could not be found. Check the domain, DNS, and internet connection.';

  @override
  String get subscriptionErrorConnection =>
      'Could not connect to the subscription server. Check your internet connection or try again later.';

  @override
  String get subscriptionErrorTls =>
      'A secure connection to the subscription server failed. Its TLS certificate may be invalid or expired.';

  @override
  String get subscriptionErrorEmptyResponse =>
      'The subscription server returned an empty response. The link may be expired or the provider may be having problems.';

  @override
  String get subscriptionErrorHtmlResponse =>
      'The server returned a web page instead of a subscription. The link may open a login or error page.';

  @override
  String get subscriptionErrorResponseTooLarge =>
      'The subscription response is too large and was blocked to protect the app.';

  @override
  String get subscriptionErrorNoUsableProxies =>
      'No supported proxy servers were found in the subscription. It may be empty, expired, or use an unsupported format.';

  @override
  String get wireGuardUnsupportedMessage =>
      'Starting with version 0.3.1, Etonify does not support WireGuard because of protocol stability issues. Use a server with another protocol.';

  @override
  String get wireGuardServersSkippedMessage =>
      'WireGuard servers were skipped. Starting with version 0.3.1, Etonify does not support WireGuard because of protocol stability issues.';

  @override
  String get subscriptionErrorInvalidContent =>
      'The server response is not a valid subscription. Check that the link points directly to a subscription file.';

  @override
  String get subscriptionErrorHappInvalid =>
      'The Happ link could not be decrypted or contains an invalid subscription URL. Copy a fresh link and try again.';

  @override
  String get subscriptionErrorUnknown =>
      'The subscription could not be processed. Check the link and open Diagnostics for the technical reason.';

  @override
  String get sourceLabel => 'Source';

  @override
  String importedFromFileLabel(String name) {
    return 'Imported from file: $name';
  }

  @override
  String get deepLinkImportTitle => 'Import subscription';

  @override
  String get deepLinkImportMessage =>
      'Do you really want to import this subscription?';

  @override
  String get deepLinkImportNameLabel => 'Name';

  @override
  String get deepLinkImportAction => 'Import';

  @override
  String get deepLinkImportSourceLabel => 'Source link';

  @override
  String get deepLinkImportResolvedUrlLabel => 'Resolved subscription URL';

  @override
  String get deepLinkImportHappBadge => 'Happ subscription';

  @override
  String get deepLinkImportHappNotice =>
      'Some Happ subscriptions require an HWID. Etonify sends it only after you confirm.';

  @override
  String get deepLinkImportHappSendHwidAction => 'Send HWID and import';

  @override
  String get deepLinkImportHappWithoutHwidAction => 'Import without HWID';

  @override
  String get deepLinkImportHappCancelAction => 'Do not import';

  @override
  String get deepLinkImportUserAgentLabel => 'User-Agent';

  @override
  String get deepLinkImportHwidLabel => 'HWID';

  @override
  String get deepLinkImportHwidValue => 'Will be sent only after confirmation';

  @override
  String deepLinkImportSuccess(String name) {
    return 'Subscription \"$name\" imported';
  }

  @override
  String get happCryptoLinkImportedLabel => 'Imported from a Happ link';

  @override
  String get happCryptoLinkTitle => 'Happ link';

  @override
  String get happCryptUnsupportedTitle => 'Happ crypt5';

  @override
  String get happCryptUnsupportedMessage =>
      'This Happ link is not supported yet.';

  @override
  String get happImportTitle => 'Happ subscription';

  @override
  String get happImportMessage =>
      'This Happ subscription may require an HWID. Send it now or try importing without it.';

  @override
  String get subscriptionOperationSlowWarning =>
      'The subscription server is taking longer than usual. Check the link or network if this keeps happening.';

  @override
  String get subscriptionOperationTimeout =>
      'The subscription server did not respond in time. Check the link or network and try again.';

  @override
  String get continueAction => 'Continue';

  @override
  String get routingTitle => 'Routing';

  @override
  String get routingSubtitle => 'Traffic routing rules';

  @override
  String get bypassLocalNetworkTitle => 'Bypass local network';

  @override
  String get bypassLocalNetworkSubtitle =>
      'Route private and LAN addresses directly';

  @override
  String get russiaRoutesTitle => 'Smart routing';

  @override
  String get russiaRoutesRunetFreedomBadge => 'runetfreedom';

  @override
  String get russiaRoutesDomainListBadge => 'domain-list-community';

  @override
  String get russiaRoutesSubtitle =>
      'Russian services go direct while blocked resources stay on VPN.';

  @override
  String get russiaRoutesInstallAction => 'Download rules';

  @override
  String get russiaRoutesReinstallAction => 'Update';

  @override
  String get russiaRoutesUpdateAction => 'Check now';

  @override
  String russiaRoutesUpdateAvailable(String version) {
    return 'A new rules version is available: $version';
  }

  @override
  String get russiaRoutesLatest => 'The latest rules version is installed.';

  @override
  String get russiaRoutesEnableTitle => 'Enable smart routing';

  @override
  String get russiaRoutesEnabledSubtitle =>
      'Apply the prepared rules to the VPN connection.';

  @override
  String get russiaRoutesMissingSubtitle =>
      'The bundled database works offline and is connected when enabled.';

  @override
  String get russiaRoutesPreparingStatus => 'Updating rules...';

  @override
  String get russiaRoutesPreparingHint =>
      'Downloading the latest database, verifying SRS files, and safely replacing local rules.';

  @override
  String get russiaRoutesStageChecking => 'Checking rule version…';

  @override
  String get russiaRoutesStageDownloading => 'Downloading rule archive…';

  @override
  String get russiaRoutesStageVerifying => 'Verifying archive integrity…';

  @override
  String get russiaRoutesStageExtracting => 'Extracting SRS files…';

  @override
  String get russiaRoutesStageCategories => 'Updating service lists…';

  @override
  String get russiaRoutesStageCompiling => 'Compiling local rules…';

  @override
  String get russiaRoutesStageActivating => 'Replacing rules safely…';

  @override
  String get russiaRoutesStageComplete => 'Rules updated';

  @override
  String russiaRoutesDownloadProgress(String completed, String total) {
    return 'Downloaded $completed of $total.';
  }

  @override
  String russiaRoutesItemsProgress(int completed, int total) {
    return 'Processed lists: $completed of $total.';
  }

  @override
  String russiaRoutesItemsProcessed(int completed) {
    return 'Processed lists: $completed.';
  }

  @override
  String get russiaRoutesMissingStatus => 'Rules are not installed yet';

  @override
  String get russiaRoutesMissingHint =>
      'The bundled database is connected first, then a fresh version is checked and downloaded in the background.';

  @override
  String get russiaRoutesReadyHint =>
      'Rules are stored locally. New versions are checked on startup, at most once a day.';

  @override
  String russiaRoutesReadyStatus(String versionTag) {
    return 'Ready · $versionTag';
  }

  @override
  String get russiaRoutesLiveSource => 'runetfreedom';

  @override
  String get russiaRoutesBundledSource => 'bundled database';

  @override
  String russiaRoutesSourceMeta(
    String source,
    String verifiedAt,
    int fileCount,
  ) {
    return 'Source: $source · $verifiedAt · files: $fileCount';
  }

  @override
  String russiaRoutesMeta(
    String installedAt,
    String domainListUpdatedAt,
    int categoryCount,
    int domainCount,
  ) {
    return 'runetfreedom: $installedAt · domain-list-community: $domainListUpdatedAt · categories: $categoryCount · domains: $domainCount';
  }

  @override
  String get adBlockTitle => 'Ad blocking';

  @override
  String get adBlockSubtitle =>
      'The client downloads a local rule-set itself and wires it into routing.';

  @override
  String get adBlockDownloadAction => 'Download';

  @override
  String get adBlockUpdateAction => 'Update';

  @override
  String get adBlockEnableTitle => 'Enable local blocking';

  @override
  String get adBlockEnabledSubtitle =>
      'Use the downloaded local rule-set for DNS and route reject.';

  @override
  String get adBlockMissingSubtitle =>
      'Download the filter package first in order to use it.';

  @override
  String get adBlockDownloadingStatus =>
      'Downloading and building the local filter...';

  @override
  String get adBlockStageConnecting => 'Connecting to AdGuard…';

  @override
  String get adBlockStageDownloading => 'Downloading the filter list…';

  @override
  String get adBlockStageCompiling => 'Building the local rule set…';

  @override
  String get adBlockStageActivating => 'Replacing the rule set safely…';

  @override
  String get adBlockStageComplete => 'Filter updated';

  @override
  String get adBlockPreparingHint => 'Preparing the download…';

  @override
  String adBlockDownloadedProgress(String completed) {
    return 'Downloaded $completed';
  }

  @override
  String adBlockDownloadProgress(String completed, String total) {
    return '$completed of $total';
  }

  @override
  String adBlockDownloadProgressEta(
    String completed,
    String total,
    int seconds,
  ) {
    return '$completed of $total · about ${seconds}s left';
  }

  @override
  String get adBlockMissingStatus => 'Filter is not downloaded yet';

  @override
  String get adBlockMissingHint =>
      'We download the list from AdGuard and keep it locally for sing-box.';

  @override
  String adBlockReadyStatus(int blockedCount) {
    return 'Filter is ready, domains: $blockedCount';
  }

  @override
  String adBlockMeta(String updatedAt, int allowedCount) {
    return 'Updated: $updatedAt · exceptions: $allowedCount';
  }

  @override
  String get splitRoutingTitle => 'Split routing';

  @override
  String get splitRoutingSubtitle =>
      'Choose which apps use the VPN and which connect directly.';

  @override
  String get splitRoutingUnavailableTitle => 'Temporarily unavailable';

  @override
  String get splitRoutingUnavailableMessage =>
      'Split tunneling does not work correctly right now. We are working on a fix. Follow updates.';

  @override
  String get splitRoutingTunOnly =>
      'Available only in VPN mode. Local proxy mode cannot manage apps.';

  @override
  String get splitRoutingModeTitle => 'Mode';

  @override
  String get splitRoutingModeDisabled => 'Off';

  @override
  String get splitRoutingModeDisabledSubtitle => 'Split routing is not used';

  @override
  String get splitRoutingModeProxySelected => 'Through VPN';

  @override
  String get splitRoutingModeProxySelectedSubtitle =>
      'Only selected apps use the VPN';

  @override
  String get splitRoutingModeBypassSelected => 'Outside VPN';

  @override
  String get splitRoutingModeBypassSelectedSubtitle =>
      'Selected apps connect directly';

  @override
  String get splitRoutingLockdownWarning =>
      'Android Always-on VPN with \'Block connections without VPN\' can block network access for apps selected outside the VPN.';

  @override
  String get splitRoutingAppsTitle => 'Applications';

  @override
  String get splitRoutingAppVisibilityNotice =>
      'Android gives Etonify the installed-app list only for selection. The list stays on this device.';

  @override
  String get splitRoutingPackagesTitle => 'Package names';

  @override
  String get splitRoutingPackagesHint => 'com.termux\norg.mozilla.firefox';

  @override
  String get splitRoutingPackagesHelper =>
      'Package name, for example org.telegram.messenger';

  @override
  String get splitRoutingPickAppsAction => 'Choose apps';

  @override
  String get splitRoutingPickAppsTitle => 'Choose apps';

  @override
  String get splitRoutingSearchHint => 'Search by app or package name';

  @override
  String get splitRoutingAndroidOnly =>
      'App picker is available on Android only';

  @override
  String get splitRoutingLoadAppsFailed => 'Failed to load installed apps';

  @override
  String splitRoutingSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get splitRoutingNoAppsTitle => 'No apps selected yet';

  @override
  String get splitRoutingNoAppsSubtitle => 'Choose apps for this mode';

  @override
  String get splitRoutingManualEditorTitle => 'Manual package list';

  @override
  String get splitRoutingManualEditorSubtitle => 'Enter package names manually';

  @override
  String refreshIntervalDaysShort(int count) {
    return '$count d';
  }

  @override
  String refreshIntervalHoursShort(int count) {
    return '$count h';
  }

  @override
  String refreshIntervalMinutesShort(int count) {
    return '$count min';
  }

  @override
  String get happCrypt5Supported => 'Available';

  @override
  String get happCrypt5Unsupported => 'Unavailable';

  @override
  String get happCrypt5Checking => 'Checking Happ crypt5...';

  @override
  String get happCrypt5SupportedDescription =>
      'This build can open Happ crypt5 links.';

  @override
  String get happCrypt5UnsupportedDescription =>
      'This build has no Happ crypt5 files. Regular subscriptions still work.';

  @override
  String get subscriptionLikelyRequiresHwidTitle => 'HWID may be required';

  @override
  String get subscriptionLikelyRequiresHwidWarning =>
      'This subscription probably requires HWID. The server returned only one outbound with app/HWID in its name. Open the subscription settings and enable HWID sending.';

  @override
  String get subscriptionLikelyRequiresHwidMessage =>
      'The server returned only one outbound, and its name looks like a placeholder related to app or HWID.\n\nThis usually means the subscription expects the device HWID in the request.\n\nEnable HWID sending now and update the subscription again?';

  @override
  String get subscriptionLikelyRequiresHwidAction => 'Enable HWID';

  @override
  String get subscriptionHwidEnabledAndUpdated =>
      'HWID sending enabled. The subscription was updated.';

  @override
  String get noValidOutboundsTitle => 'No working nodes';

  @override
  String get noValidOutboundsWarning =>
      'There are no working outbounds left in this subscription. They were filtered out during validation. Check the subscription or update it.';

  @override
  String get noValidOutboundsMessage =>
      'This subscription does not have any working outbounds left.\n\nAll nodes were filtered out during validation before startup, so the client will not try to launch sing-box with an empty proxy set.\n\nCheck the subscription, refresh it, or import a valid one.';

  @override
  String get noValidOutboundsAfterDropInvalidWarning =>
      'There are no working outbounds left in the selected subscription after invalid nodes were dropped. Check the subscription, something looks wrong with it.';

  @override
  String get noValidOutboundsAfterDropInvalidMessage =>
      'All remaining nodes in the selected subscription were dropped as invalid during startup.\n\nThe client stopped before handing a broken config to sing-box.\n\nCheck the subscription content and update or replace it.';

  @override
  String get experimentalTcpFastOpenTitle => 'TCP Fast Open';

  @override
  String get experimentalTcpFastOpenSubtitle =>
      'May reduce TCP handshake time, but support depends on the network and server.';

  @override
  String get experimentalTcpMultiPathTitle => 'TCP Multipath';

  @override
  String get experimentalTcpMultiPathSubtitle =>
      'Tries multiple network paths. Can help handoff, but may heat the phone or behave unstably.';

  @override
  String get experimentalInterruptConnectionsTitle =>
      'Interrupt active connections on node change';

  @override
  String get experimentalInterruptConnectionsSubtitle =>
      'Applies proxy changes faster, but old app connections can be dropped.';

  @override
  String get experimentalUrlTestStrictToleranceTitle =>
      'URLTest 1 ms tolerance';

  @override
  String get experimentalUrlTestStrictToleranceSubtitle =>
      'Selects the lowest-latency proxy more strictly, but may switch servers more often.';

  @override
  String get experimentalFakeIpTitle => 'Rewrite DNS answers (FakeIP)';

  @override
  String get experimentalFakeIpSubtitle =>
      'Speeds up domain handling inside VPN TUN. Some applications may be incompatible.';

  @override
  String get experimentalFakeIpUnavailableSubtitle =>
      'Available only with VPN TUN and split routing turned off.';

  @override
  String get tlsFragmentationTitle => 'TLS fragmentation';

  @override
  String get tlsFragmentationSubtitle =>
      'Fragments TLS handshakes for proxy outbounds. It can help with DPI, but may slow connection setup.';

  @override
  String get tlsFragmentationModeDisabled => 'Disabled';

  @override
  String get tlsFragmentationModeDisabledSubtitle =>
      'Does not change server TLS settings.';

  @override
  String get tlsFragmentationModeRecord => 'TLS record fragment';

  @override
  String get tlsFragmentationModeRecordSubtitle =>
      'Softer mode. Try this first.';

  @override
  String get tlsFragmentationModeFragment => 'TLS fragment';

  @override
  String get tlsFragmentationModeFragmentSubtitle =>
      'More aggressive mode with a 300 ms fallback delay.';

  @override
  String get blockLeaksTitle => 'Fix some leaks';

  @override
  String get blockLeaksSubtitle =>
      'Blocks only STUN/WebRTC traffic that may bypass the proxy';

  @override
  String get addSubscriptionCaption => 'Add a subscription from a link or file';

  @override
  String get pasteSubscriptionLink => 'Paste subscription link';

  @override
  String get orManually => 'Or manually';

  @override
  String get pasteAction => 'Paste';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get settingsMenuImport => 'Import';

  @override
  String get settingsMenuExport => 'Export';

  @override
  String get settingsResetAction => 'Reset settings';

  @override
  String get settingsResetTitle => 'Reset settings?';

  @override
  String get settingsResetMessage =>
      'All client settings will return to their defaults. Subscriptions and the selected server will be kept.';

  @override
  String get settingsResetSuccess => 'Settings reset to defaults';

  @override
  String get backupExportSettings => 'Export settings';

  @override
  String get backupExportProfileEncrypted =>
      'Export subscriptions with password';

  @override
  String get backupExportProfilePlain =>
      'Export subscriptions without encryption';

  @override
  String get backupPlainWarningTitle => 'The file will contain VPN keys';

  @override
  String get backupPlainWarningMessage =>
      'Plain export is readable by anyone who gets the file. Use encrypted export unless you fully trust the storage and transfer path.';

  @override
  String get backupPlainImportTitle => 'Plain profile file';

  @override
  String get backupPlainImportMessage =>
      'This file contains subscriptions and VPN keys without encryption. Import it only if you trust the source.';

  @override
  String get backupPasswordCreateTitle => 'Create export password';

  @override
  String get backupPasswordEnterTitle => 'Enter profile password';

  @override
  String get backupPasswordHint => 'Password';

  @override
  String get backupSaved => 'Backup file saved';

  @override
  String get backupImported => 'Import completed';

  @override
  String get backupUnsupportedVersion =>
      'This backup format is not supported by this client version.';

  @override
  String get backupNewerVersionTitle => 'Backup from a newer client';

  @override
  String backupNewerVersionMessage(String version) {
    return 'This file was created by Etonify $version. Some settings may not apply correctly. Continue?';
  }

  @override
  String get splitRoutingEmptyWhitelist =>
      'Choose at least one app or disable split tunneling before starting VPN.';

  @override
  String get splitRoutingUnknownAppLabel => 'App not found';

  @override
  String get splitRoutingLoadingAppLabel => 'Looking up app…';

  @override
  String get connectionStagePreparing => 'Preparing VPN';

  @override
  String get connectionStageConfiguring => 'Building config';

  @override
  String get connectionStageStarting => 'Starting core';

  @override
  String get connectionStageStopping => 'Stopping VPN';

  @override
  String get connectionStageRecovering => 'Recovering';

  @override
  String get connectionStageSelectingProxy => 'Selecting server';

  @override
  String get vpnStartTimedOut =>
      'VPN did not start within 15 seconds. Startup was stopped.';

  @override
  String get vpnStartFailed => 'Failed to start VPN.';

  @override
  String get trafficRulesTitle => 'Traffic rules';

  @override
  String get trafficRulesSettingsTitle => 'Traffic rules';

  @override
  String get trafficRulesSettingsSubtitle =>
      'Choose one verified rule for domains and IP routes.';

  @override
  String get trafficRulesCurrentLabel => 'Active rule';

  @override
  String get trafficRulesNone => 'Not selected';

  @override
  String get trafficRulesUsePresetTitle => 'Use traffic rules';

  @override
  String get trafficRulesUsePresetSubtitle =>
      'Choose a ready-made preset for domain and IP routing.';

  @override
  String get trafficRulesUsePresetAction => 'Use preset';

  @override
  String get trafficRulesDisablePreset => 'Disable preset';

  @override
  String get trafficRulesQuickSelection => 'Quick selection';

  @override
  String get trafficRulesDeveloperSection => 'Developer rules';

  @override
  String get trafficRulesDeveloperSubtitle =>
      'Verified presets with a detailed breakdown.';

  @override
  String get trafficRulesVerified => 'Verified';

  @override
  String get trafficRulesVerifiedInfo =>
      'Verified by MeowTeam. Created by the official developer.';

  @override
  String get trafficRulesOnlyOne =>
      'Only one traffic rule can be active at a time to avoid conflicts.';

  @override
  String get trafficRulesAvailableOffline =>
      'After preparation, the rule works without an internet connection.';

  @override
  String get trafficRulesDataReady => 'Rule data is ready';

  @override
  String get trafficRulesDataMissing => 'Rule data has not been prepared yet';

  @override
  String get trafficRulesUpdateData => 'Update rule data';

  @override
  String get trafficRulesDeleteData => 'Delete rule data';

  @override
  String get trafficRulesRussianTitle => '.RU without VPN';

  @override
  String get trafficRulesRussianSubtitle =>
      'Russian services and local addresses bypass the VPN.';

  @override
  String get trafficRulesAiTitle => 'AI services through VPN';

  @override
  String get trafficRulesAiSubtitle =>
      'Popular AI services are routed through the VPN; everything else is direct.';

  @override
  String get trafficRulesSocialTitle => 'Social networks through VPN';

  @override
  String get trafficRulesSocialSubtitle =>
      'Popular social networks and messengers are routed through the VPN; everything else is direct.';

  @override
  String get trafficRulesDetails => 'Rule details';

  @override
  String get trafficRulesDescription => 'Description';

  @override
  String get trafficRulesAuthor => 'Author';

  @override
  String get trafficRulesRoutingDomains => 'Domain routing';

  @override
  String get trafficRulesSettings => 'Settings';

  @override
  String get trafficRulesRuDnsTitle => 'DNS for .RU without VPN';

  @override
  String get trafficRulesRuDnsSubtitle =>
      'Used only for Russian domains that this rule sends directly. Default: udp://77.88.8.8.';

  @override
  String get trafficRulesDefaultRoute => 'Everything else';

  @override
  String get trafficRulesDirect => 'Direct';

  @override
  String get trafficRulesVpn => 'Through VPN';

  @override
  String get trafficRulesIncludes => 'Includes';

  @override
  String get trafficRulesLocalNetwork => 'Local network always stays direct';

  @override
  String get trafficRulesChoose => 'Choose rule';

  @override
  String get trafficRulesChosen => 'Selected';

  @override
  String get trafficRulesDisabled => 'Disabled';

  @override
  String get trafficRulesPreparing => 'Preparing rule data…';

  @override
  String get trafficRulesPrepareFailed =>
      'Could not prepare rule data. Check your connection and try again.';

  @override
  String get remoteDownloadConnectTimeout =>
      'Could not connect to the server within 5 seconds. Check your connection or active VPN and try again.';

  @override
  String get remoteDownloadResponseTimeout =>
      'The server did not start responding within 5 seconds. Check your connection or active VPN and try again.';

  @override
  String get remoteDownloadRetryWithoutVpn => 'Trying without VPN';

  @override
  String get remoteDownloadRetryWithoutVpnHint =>
      'The VPN route did not respond. Retrying over Wi-Fi or mobile data.';

  @override
  String get remoteDownloadIdleTimeout =>
      'The download stopped because the server sent no data for 7 seconds. Try again.';

  @override
  String get routingRuleFilesTitle => 'Rule files';

  @override
  String get routingRuleFilesSettingsTitle => 'Rule files';

  @override
  String routingRuleFilesSettingsReady(int count) {
    return '$count files ready';
  }

  @override
  String get routingRuleFilesSettingsPreparing =>
      'Bundled files are prepared when you open this screen';

  @override
  String get routingRuleFilesReadyTitle => 'Rule files are ready';

  @override
  String get routingRuleFilesReadySubtitle =>
      'SRS files are stored on this device and work offline.';

  @override
  String get routingRuleFilesPreparingTitle => 'Preparing bundled files';

  @override
  String get routingRuleFilesPreparingSubtitle =>
      'Preparing local SRS files for traffic rules.';

  @override
  String get routingRuleFilesSourceTitle => 'Source';

  @override
  String get routingRuleFilesVersionTitle => 'Version';

  @override
  String get routingRuleFilesCountTitle => 'Files';

  @override
  String get routingRuleFilesTotalSizeTitle => 'Total size';

  @override
  String get routingRuleFilesScopeTitle => 'Russia is the current priority';

  @override
  String get routingRuleFilesScopeSubtitle =>
      'The current set focuses on Russian networks and services. More regions will be added in future updates.';

  @override
  String get routingRuleFilesOpenSourceFailed =>
      'Unable to open the source page. Try again.';

  @override
  String routingRuleFilesSourceMeta(String source, String version, int count) {
    return 'Source: $source · version: $version · files: $count';
  }

  @override
  String get routingRuleFilesUpdateAction => 'Update files';

  @override
  String get routingRuleFilesUpdatingAction => 'Updating files…';

  @override
  String routingRuleFilesEta(String duration) {
    return 'About $duration remaining';
  }

  @override
  String routingRuleFilesSecondsShort(int seconds) {
    return '${seconds}s';
  }

  @override
  String routingRuleFilesMinutesShort(int minutes) {
    return '${minutes}m';
  }

  @override
  String get routingRuleFilesListTitle => 'Rule files';

  @override
  String get routingRuleFilesEmptyTitle => 'Files are not ready yet';

  @override
  String get routingRuleFilesEmptySubtitle =>
      'Open this screen again or tap Update files.';

  @override
  String trafficRulesRuleCount(int count) {
    return '$count categories';
  }

  @override
  String get coreIntegrationTitle => 'Core and configuration';

  @override
  String get coreIntegrationSubtitle =>
      'Shows the actual bundled core and last applied configuration state, not just the switches displayed by the app.';

  @override
  String get coreApiLabel => 'Core API';

  @override
  String get coreCompatibilityLabel => 'Compatibility';

  @override
  String get coreCompatible => 'Compatible';

  @override
  String get coreIncompatible => 'Incompatible';

  @override
  String get coreConfigStateLabel => 'Configuration state';

  @override
  String get coreConfigApplied => 'Applied';

  @override
  String get coreConfigValidated => 'Validated';

  @override
  String get coreConfigFailed => 'Failed';

  @override
  String get coreConfigSuperseded => 'Superseded';

  @override
  String get coreConfigNotApplied => 'Not applied yet';

  @override
  String get coreConfigPending => 'Applying…';

  @override
  String get coreRuntimeStateLabel => 'VPN state';

  @override
  String get coreRuntimeRunning => 'Running';

  @override
  String get coreRuntimeStopped => 'Stopped';

  @override
  String get coreRuntimeGenerationLabel => 'Runtime generation';

  @override
  String get coreConfigSchemaLabel => 'Configuration schema';

  @override
  String get coreLastChangeLabel => 'Last applied';
}
