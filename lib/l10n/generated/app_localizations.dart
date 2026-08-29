import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @profiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profiles;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @proxiesTab.
  ///
  /// In en, this message translates to:
  /// **'Proxies'**
  String get proxiesTab;

  /// No description provided for @proxiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Proxies'**
  String get proxiesTitle;

  /// No description provided for @proxySwitching.
  ///
  /// In en, this message translates to:
  /// **'Switching'**
  String get proxySwitching;

  /// No description provided for @proxyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get proxyUnavailable;

  /// No description provided for @proxyLatencyNoResult.
  ///
  /// In en, this message translates to:
  /// **'No result'**
  String get proxyLatencyNoResult;

  /// No description provided for @proxyLatencyNoResultDescription.
  ///
  /// In en, this message translates to:
  /// **'No latency test result is available for this server yet.'**
  String get proxyLatencyNoResultDescription;

  /// No description provided for @proxySelectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Selector'**
  String get proxySelectorTitle;

  /// No description provided for @proxyLowestName.
  ///
  /// In en, this message translates to:
  /// **'Lowest'**
  String get proxyLowestName;

  /// No description provided for @proxyAutomaticSelectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Automatic selection'**
  String get proxyAutomaticSelectionLabel;

  /// No description provided for @proxyChainLabel.
  ///
  /// In en, this message translates to:
  /// **'Chain'**
  String get proxyChainLabel;

  /// No description provided for @proxyChainAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add proxy chain'**
  String get proxyChainAddTitle;

  /// No description provided for @proxyChainAddTile.
  ///
  /// In en, this message translates to:
  /// **'Add proxy chain'**
  String get proxyChainAddTile;

  /// No description provided for @proxyChainChangeFirstHop.
  ///
  /// In en, this message translates to:
  /// **'Change first proxy'**
  String get proxyChainChangeFirstHop;

  /// No description provided for @proxyChainRenameAction.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get proxyChainRenameAction;

  /// No description provided for @proxyChainRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename proxy chain'**
  String get proxyChainRenameTitle;

  /// No description provided for @proxyChainRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove proxy chain'**
  String get proxyChainRemoveAction;

  /// No description provided for @proxyChainNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get proxyChainNameLabel;

  /// No description provided for @proxyChainFirstHopLabel.
  ///
  /// In en, this message translates to:
  /// **'First proxy'**
  String get proxyChainFirstHopLabel;

  /// No description provided for @proxyChainExitLabel.
  ///
  /// In en, this message translates to:
  /// **'Exit proxy'**
  String get proxyChainExitLabel;

  /// No description provided for @proxyChainNothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get proxyChainNothingFound;

  /// No description provided for @proxyChainSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get proxyChainSaveAction;

  /// No description provided for @shareProxyTitle.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareProxyTitle;

  /// No description provided for @shareProxyLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get shareProxyLinkLabel;

  /// No description provided for @shareSingboxOutboundLabel.
  ///
  /// In en, this message translates to:
  /// **'sing-box outbound'**
  String get shareSingboxOutboundLabel;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'{label} copied'**
  String copiedToClipboard(String label);

  /// No description provided for @unavailableForThisType.
  ///
  /// In en, this message translates to:
  /// **'Unavailable for this type'**
  String get unavailableForThisType;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @sortByDefault.
  ///
  /// In en, this message translates to:
  /// **'Source order'**
  String get sortByDefault;

  /// No description provided for @sortByLatency.
  ///
  /// In en, this message translates to:
  /// **'By latency'**
  String get sortByLatency;

  /// No description provided for @sortByWorking.
  ///
  /// In en, this message translates to:
  /// **'Working only'**
  String get sortByWorking;

  /// No description provided for @sortByName.
  ///
  /// In en, this message translates to:
  /// **'By name'**
  String get sortByName;

  /// No description provided for @sortByCountry.
  ///
  /// In en, this message translates to:
  /// **'By country'**
  String get sortByCountry;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @generalSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalSectionTitle;

  /// No description provided for @inboundTitle.
  ///
  /// In en, this message translates to:
  /// **'Inbound'**
  String get inboundTitle;

  /// No description provided for @dnsTitle.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get dnsTitle;

  /// No description provided for @whitelistTitle.
  ///
  /// In en, this message translates to:
  /// **'Whitelist'**
  String get whitelistTitle;

  /// No description provided for @whitelistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reserved routing tools'**
  String get whitelistSubtitle;

  /// No description provided for @experimentalTitle.
  ///
  /// In en, this message translates to:
  /// **'Experimental'**
  String get experimentalTitle;

  /// No description provided for @securityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securityTitle;

  /// No description provided for @securitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'TLS certificates and connection verification'**
  String get securitySubtitle;

  /// No description provided for @securityTlsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'TLS certificates'**
  String get securityTlsSectionTitle;

  /// No description provided for @securityUntrustedProxyCertificatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow untrusted proxy certificates'**
  String get securityUntrustedProxyCertificatesTitle;

  /// No description provided for @securityUntrustedProxyCertificatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to proxy servers with self-signed, expired, or otherwise untrusted certificates. This weakens protection against connection interception.'**
  String get securityUntrustedProxyCertificatesSubtitle;

  /// No description provided for @securityUntrustedSubscriptionCertificatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow untrusted subscription certificates'**
  String get securityUntrustedSubscriptionCertificatesTitle;

  /// No description provided for @securityUntrustedSubscriptionCertificatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update HTTPS subscriptions even when the website certificate cannot be verified. The subscription URL and content may be intercepted or replaced.'**
  String get securityUntrustedSubscriptionCertificatesSubtitle;

  /// No description provided for @securityConfirmProxyTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow untrusted proxy certificates?'**
  String get securityConfirmProxyTitle;

  /// No description provided for @securityConfirmProxyMessage.
  ///
  /// In en, this message translates to:
  /// **'Certificate verification will be disabled for every TLS proxy connection. Enable this only for configurations you trust.'**
  String get securityConfirmProxyMessage;

  /// No description provided for @securityConfirmSubscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow untrusted subscription certificates?'**
  String get securityConfirmSubscriptionTitle;

  /// No description provided for @securityConfirmSubscriptionMessage.
  ///
  /// In en, this message translates to:
  /// **'Certificate verification will be disabled while updating HTTPS subscriptions. The subscription URL and content may be intercepted or replaced.'**
  String get securityConfirmSubscriptionMessage;

  /// No description provided for @securityAllowAction.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get securityAllowAction;

  /// No description provided for @experimentalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Multipath, Fast Open, and connection switching behavior'**
  String get experimentalSubtitle;

  /// No description provided for @logsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTitle;

  /// No description provided for @logsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generated sing-box config and app events'**
  String get logsSubtitle;

  /// No description provided for @urlTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Server checks'**
  String get urlTestTitle;

  /// No description provided for @urlTestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Latency checks and automatic server selection'**
  String get urlTestSubtitle;

  /// No description provided for @vpnInTitle.
  ///
  /// In en, this message translates to:
  /// **'VPN In'**
  String get vpnInTitle;

  /// No description provided for @proxyInTitle.
  ///
  /// In en, this message translates to:
  /// **'Proxy In'**
  String get proxyInTitle;

  /// No description provided for @dnsDirectTitle.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get dnsDirectTitle;

  /// No description provided for @dnsProxyTitle.
  ///
  /// In en, this message translates to:
  /// **'Via proxy'**
  String get dnsProxyTitle;

  /// No description provided for @dnsIpPreferenceTitle.
  ///
  /// In en, this message translates to:
  /// **'IP version'**
  String get dnsIpPreferenceTitle;

  /// No description provided for @aboutSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSectionTitle;

  /// No description provided for @aboutSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App version, core, team, and service information.'**
  String get aboutSectionSubtitle;

  /// No description provided for @aboutHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'An Android VPN client we are building to be fast, understandable, and reliable for everyday use.'**
  String get aboutHeroSubtitle;

  /// No description provided for @aboutDevelopedBy.
  ///
  /// In en, this message translates to:
  /// **'Etonify is developed by the small independent MeowTeam.'**
  String get aboutDevelopedBy;

  /// No description provided for @aboutTeamLabel.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get aboutTeamLabel;

  /// No description provided for @aboutContactLabel.
  ///
  /// In en, this message translates to:
  /// **'Message the developers'**
  String get aboutContactLabel;

  /// No description provided for @aboutCoreSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'core source code'**
  String get aboutCoreSourceLabel;

  /// No description provided for @aboutDocumentationTitle.
  ///
  /// In en, this message translates to:
  /// **'Etonify documentation'**
  String get aboutDocumentationTitle;

  /// No description provided for @aboutDocumentationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up and use Etonify.'**
  String get aboutDocumentationSubtitle;

  /// No description provided for @documentationPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Documentation'**
  String get documentationPageTitle;

  /// No description provided for @documentationPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Short instructions for setting up and using Etonify.'**
  String get documentationPageSubtitle;

  /// No description provided for @documentationGroupGettingStarted.
  ///
  /// In en, this message translates to:
  /// **'Getting started'**
  String get documentationGroupGettingStarted;

  /// No description provided for @documentationGroupConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get documentationGroupConnection;

  /// No description provided for @documentationGroupRouting.
  ///
  /// In en, this message translates to:
  /// **'Routing and DNS'**
  String get documentationGroupRouting;

  /// No description provided for @documentationGroupMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get documentationGroupMaintenance;

  /// No description provided for @documentationGroupHelp.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get documentationGroupHelp;

  /// No description provided for @documentationGroupDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documentationGroupDocuments;

  /// No description provided for @documentationQuickStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick start'**
  String get documentationQuickStartTitle;

  /// No description provided for @documentationQuickStartBody.
  ///
  /// In en, this message translates to:
  /// **'1. Add a subscription or individual server.\n2. Run a server check.\n3. Select a server or Lowest.\n4. Tap connect and allow the VPN connection.\n5. If it does not connect, try another server and open Logs.'**
  String get documentationQuickStartBody;

  /// No description provided for @documentationWhatTitle.
  ///
  /// In en, this message translates to:
  /// **'About Etonify'**
  String get documentationWhatTitle;

  /// No description provided for @documentationWhatBody.
  ///
  /// In en, this message translates to:
  /// **'Etonify works on Android 8.0 and newer. It is a sing-box client, not a VPN service. Add a subscription or server from your provider. Settings, subscriptions, and logs stay on the device.'**
  String get documentationWhatBody;

  /// No description provided for @documentationModesTitle.
  ///
  /// In en, this message translates to:
  /// **'VPN and local proxy'**
  String get documentationModesTitle;

  /// No description provided for @documentationModesBody.
  ///
  /// In en, this message translates to:
  /// **'VPN TUN routes app traffic through the Android system VPN.\n\nThe local HTTP/SOCKS proxy works only in apps configured to use its address. VPN and local proxy can run together. Enable LAN access for other devices on your network.'**
  String get documentationModesBody;

  /// No description provided for @documentationProtocolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Formats and protocols'**
  String get documentationProtocolsTitle;

  /// No description provided for @documentationProtocolsBody.
  ///
  /// In en, this message translates to:
  /// **'You can import links, QR codes, WireGuard files, and sing-box, Xray, or Happ configurations.\n\nSupported protocols include VLESS, VMess, Trojan, Shadowsocks, ShadowsocksR, Hysteria, Hysteria2, TUIC, WireGuard, AnyTLS, Naive, HTTP, and SOCKS. Import confirms the format, not server availability.'**
  String get documentationProtocolsBody;

  /// No description provided for @documentationChainsTitle.
  ///
  /// In en, this message translates to:
  /// **'Proxy chains'**
  String get documentationChainsTitle;

  /// No description provided for @documentationChainsBody.
  ///
  /// In en, this message translates to:
  /// **'A chain routes traffic through a first proxy and an exit proxy. Both servers must work. Latency is usually higher. Chains do not provide automatic failover.'**
  String get documentationChainsBody;

  /// No description provided for @documentationSubscriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions and profiles'**
  String get documentationSubscriptionsTitle;

  /// No description provided for @documentationSubscriptionsBody.
  ///
  /// In en, this message translates to:
  /// **'A profile stores subscription sources, servers, and the last selection. Add data from the clipboard, a file, a QR code, or manually. Automatic refresh updates the subscription on schedule. Previous data stays available if an update fails.'**
  String get documentationSubscriptionsBody;

  /// No description provided for @documentationChecksTitle.
  ///
  /// In en, this message translates to:
  /// **'Server checks'**
  String get documentationChecksTitle;

  /// No description provided for @documentationChecksBody.
  ///
  /// In en, this message translates to:
  /// **'URLTest sends an HTTP request through the server. It is not an ICMP ping. The result depends on the server, TLS, test website, and network.\n\nA dash means there is no result or it was cleared after a network change. A red warning icon means the check failed. Lowest selects an available server with the lowest delay.'**
  String get documentationChecksBody;

  /// No description provided for @documentationBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Background operation and notification'**
  String get documentationBackgroundTitle;

  /// No description provided for @documentationBackgroundBody.
  ///
  /// In en, this message translates to:
  /// **'While VPN is active, Android shows a notification with the server, delay, traffic, and a stop action.\n\nClosing the interface does not stop the VPN. Force-stopping the app disables the service until Etonify is opened again. Some devices require background activity and auto-start permission.'**
  String get documentationBackgroundBody;

  /// No description provided for @documentationRoutingTitle.
  ///
  /// In en, this message translates to:
  /// **'Split tunneling and TUN stack'**
  String get documentationRoutingTitle;

  /// No description provided for @documentationRoutingBody.
  ///
  /// In en, this message translates to:
  /// **'Split tunneling works in VPN TUN mode. Via VPN sends selected apps into the tunnel. Outside VPN leaves them on a direct connection.\n\nMixed uses Android for TCP and gVisor for UDP. System uses Android for TCP and UDP. gVisor handles both inside the client. Keep Mixed unless you have a compatibility problem.'**
  String get documentationRoutingBody;

  /// No description provided for @documentationTrafficRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Traffic rules'**
  String get documentationTrafficRulesTitle;

  /// No description provided for @documentationTrafficRulesBody.
  ///
  /// In en, this message translates to:
  /// **'A preset chooses a direct or proxy route for domains and IP addresses. One preset can be active at a time.\n\nSplit tunneling first selects which apps enter the VPN. Traffic rules then select the route for their connections.'**
  String get documentationTrafficRulesBody;

  /// No description provided for @documentationDnsTitle.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get documentationDnsTitle;

  /// No description provided for @documentationDnsBody.
  ///
  /// In en, this message translates to:
  /// **'Etonify supports device DNS, UDP, TCP, DoT, and DoH. Direct uses the regular connection. Via proxy uses the selected server.\n\nFakeIP is an experimental option and may not work with some apps.'**
  String get documentationDnsBody;

  /// No description provided for @documentationRuleFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Geo-resource files'**
  String get documentationRuleFilesTitle;

  /// No description provided for @documentationRuleFilesBody.
  ///
  /// In en, this message translates to:
  /// **'Traffic presets use local .srs files and work offline. A new version replaces the old one only after a successful download.\n\nAd blocking uses a separate AdGuard filter. Update files and the filter in Routing settings.'**
  String get documentationRuleFilesBody;

  /// No description provided for @documentationSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'TLS security'**
  String get documentationSecurityTitle;

  /// No description provided for @documentationSecurityBody.
  ///
  /// In en, this message translates to:
  /// **'Etonify verifies TLS certificates for servers and HTTPS subscriptions by default. Verification can be disabled separately for servers and subscriptions. Do this only for a trusted source. Otherwise, keys and traffic can be intercepted.'**
  String get documentationSecurityBody;

  /// No description provided for @documentationUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloads and updates'**
  String get documentationUpdatesTitle;

  /// No description provided for @documentationUpdatesBody.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions, geo-resources, the ad-blocking filter, and client updates first download through the active VPN. On failure, Etonify tries Wi-Fi or mobile data. If another VPN is active, its rules apply.\n\nDownloads have time and size limits. APK files are verified before installation.'**
  String get documentationUpdatesBody;

  /// No description provided for @documentationBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Import, export, and backups'**
  String get documentationBackupTitle;

  /// No description provided for @documentationBackupBody.
  ///
  /// In en, this message translates to:
  /// **'Settings export does not include subscriptions or keys. Subscription export contains profiles and servers.\n\nProtect backups with a password. An unencrypted file stores keys in plain text. A forgotten password cannot be recovered.'**
  String get documentationBackupBody;

  /// No description provided for @documentationExperimentalTitle.
  ///
  /// In en, this message translates to:
  /// **'Experimental options'**
  String get documentationExperimentalTitle;

  /// No description provided for @documentationExperimentalBody.
  ///
  /// In en, this message translates to:
  /// **'FakeIP, TLS fragmentation, TCP Fast Open, TCP MultiPath, and multiplexing change network behavior. They are not required for a normal connection.\n\nChange one option at a time. Restore the default if the connection becomes worse.'**
  String get documentationExperimentalBody;

  /// No description provided for @documentationDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs and resources'**
  String get documentationDiagnosticsTitle;

  /// No description provided for @documentationDiagnosticsBody.
  ///
  /// In en, this message translates to:
  /// **'Resources and diagnostics show VPN status, versions, and process memory. PSS, RSS, Private Dirty, Swap, heap, code, and graphics must not be added together.\n\nExport logs immediately after an error. Check the file for private data before sharing it.'**
  String get documentationDiagnosticsBody;

  /// No description provided for @documentationLimitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Important limits'**
  String get documentationLimitsTitle;

  /// No description provided for @documentationLimitsBody.
  ///
  /// In en, this message translates to:
  /// **'Etonify works only on Android and does not include VPN servers. Availability depends on the server, subscription, DNS, carrier, and device.\n\nURLTest checks one address and does not guarantee access to every website. Large subscriptions and full server checks temporarily increase memory, CPU, battery, and data use.'**
  String get documentationLimitsBody;

  /// No description provided for @telegramChannelLabel.
  ///
  /// In en, this message translates to:
  /// **'Telegram channel'**
  String get telegramChannelLabel;

  /// No description provided for @legalTermsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get legalTermsTitle;

  /// No description provided for @legalPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get legalPrivacyTitle;

  /// No description provided for @legalTermsSummary.
  ///
  /// In en, this message translates to:
  /// **'Rules for responsible use and project disclaimers.'**
  String get legalTermsSummary;

  /// No description provided for @legalPrivacySummary.
  ///
  /// In en, this message translates to:
  /// **'What Etonify stores locally and what it does not collect.'**
  String get legalPrivacySummary;

  /// No description provided for @legalGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Before using Etonify'**
  String get legalGateTitle;

  /// No description provided for @legalGateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Starting with version {version}, please read and accept the Terms and Privacy Policy to continue.'**
  String legalGateSubtitle(String version);

  /// No description provided for @legalAcceptAction.
  ///
  /// In en, this message translates to:
  /// **'Accept and continue'**
  String get legalAcceptAction;

  /// No description provided for @legalAcceptHint.
  ///
  /// In en, this message translates to:
  /// **'Open both documents to enable continue.'**
  String get legalAcceptHint;

  /// No description provided for @legalDocumentReadAction.
  ///
  /// In en, this message translates to:
  /// **'I have read it'**
  String get legalDocumentReadAction;

  /// No description provided for @legalContactAction.
  ///
  /// In en, this message translates to:
  /// **'Ask a question'**
  String get legalContactAction;

  /// No description provided for @legalImportBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Accept Terms and Privacy Policy before importing subscriptions.'**
  String get legalImportBlockedMessage;

  /// No description provided for @legalTermsBody.
  ///
  /// In en, this message translates to:
  /// **'# Etonify Terms of Use\n\n## What the app does\n\nEtonify is an Android VPN client. **It does not sell or provide VPN servers:** users add subscriptions, profiles, and servers from third-party providers.\n\n## User responsibility\n\nUse Etonify according to applicable law and service rules. Do not use it for attacks, fraud, malware, harassment, or other illegal activity.\n\n- You are responsible for added profiles and access keys.\n- Third-party providers determine their own service terms.\n- MeowTeam does not control subscription content or third-party server traffic.\n\n## Operation and updates\n\nEtonify is provided **as is**. We improve reliability and security, but cannot guarantee every server, route, DNS resolver, carrier, or modified Android firmware. Updates are installed only after user action and Android system confirmation.\n\n## Feedback\n\nQuestions, bug reports, and feature requests can be sent directly to the developers: **https://t.me/etonify?direct**.\n\nBy continuing, you confirm that you have read these terms and accept responsibility for using the app.'**
  String get legalTermsBody;

  /// No description provided for @legalPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'# Etonify Privacy Policy\n\n## Summary\n\nEtonify has **no advertising, analytics SDKs, or hidden tracking**. MeowTeam does not sell user data or automatically receive your VPN keys.\n\n## Data stored on the device\n\nSubscriptions, profiles, selected servers, settings, diagnostic logs, and downloaded rule files are stored locally. Backups and exports may contain access keys, so keep them private.\n\n## Network requests\n\n- Subscription imports and refreshes contact the address supplied by the user. That server can see normal request information, including the IP address.\n- Client and routing-rule update checks contact GitHub and the sources named in the interface.\n- HWID is sent to a subscription service only for profiles where the user enables it.\n\n## Android permissions\n\n- **VPN service** creates the system VPN tunnel.\n- **QUERY_ALL_PACKAGES** is used only to display installed apps for split tunneling. The app list is not sent to MeowTeam.\n- **Camera** is used only to scan QR codes.\n- **Notifications** display VPN service state.\n- **APK installation** is used only for user-approved updates. Android shows a separate system confirmation.\n\n## Logs and messages\n\nLogs are stored locally until the user exports or sends them. Review exported files before sharing publicly. Information voluntarily sent through Telegram is handled under Telegram\'s rules.\n\nPrivacy questions can be sent directly to the developers: **https://t.me/etonify?direct**.'**
  String get legalPrivacyBody;

  /// No description provided for @coreVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Core version'**
  String get coreVersionLabel;

  /// No description provided for @debugMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debugMenuTitle;

  /// No description provided for @debugMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hidden area for debugging and service actions.'**
  String get debugMenuSubtitle;

  /// No description provided for @debugNetworkHeartbeatTitle.
  ///
  /// In en, this message translates to:
  /// **'Network heartbeat'**
  String get debugNetworkHeartbeatTitle;

  /// No description provided for @debugNetworkHeartbeatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Re-asserts the default network if Android misses callbacks. Current interval: {seconds}s. Applies on next VPN start.'**
  String debugNetworkHeartbeatSubtitle(int seconds);

  /// No description provided for @debugWakeLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Partial wake lock'**
  String get debugWakeLockTitle;

  /// No description provided for @debugWakeLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keeps CPU awake while VPN runs. Off by default because it can heat the phone on aggressive firmware.'**
  String get debugWakeLockSubtitle;

  /// No description provided for @debugRecordSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Record performance snapshot'**
  String get debugRecordSnapshot;

  /// No description provided for @debugSnapshotDone.
  ///
  /// In en, this message translates to:
  /// **'Performance snapshot added to logs'**
  String get debugSnapshotDone;

  /// No description provided for @debugRuntimeMeasurementTitle.
  ///
  /// In en, this message translates to:
  /// **'Background runtime measurement'**
  String get debugRuntimeMeasurementTitle;

  /// No description provided for @debugRuntimeMeasurementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Measures CPU, memory, core tasks, connections and routed traffic every 5 seconds. It runs only while started and never changes VPN routing.'**
  String get debugRuntimeMeasurementSubtitle;

  /// No description provided for @debugRuntimeMeasurementDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration: {duration}'**
  String debugRuntimeMeasurementDuration(String duration);

  /// No description provided for @debugRuntimeMeasurementProgress.
  ///
  /// In en, this message translates to:
  /// **'Running: {elapsed} of {duration}'**
  String debugRuntimeMeasurementProgress(String elapsed, String duration);

  /// No description provided for @debugRuntimeMeasurementStart.
  ///
  /// In en, this message translates to:
  /// **'Start measurement'**
  String get debugRuntimeMeasurementStart;

  /// No description provided for @debugRuntimeMeasurementStop.
  ///
  /// In en, this message translates to:
  /// **'Stop measurement'**
  String get debugRuntimeMeasurementStop;

  /// No description provided for @debugRuntimeMeasurementSave.
  ///
  /// In en, this message translates to:
  /// **'Save report'**
  String get debugRuntimeMeasurementSave;

  /// No description provided for @debugRuntimeMeasurementIdle.
  ///
  /// In en, this message translates to:
  /// **'Ready to measure'**
  String get debugRuntimeMeasurementIdle;

  /// No description provided for @debugRuntimeMeasurementCompleted.
  ///
  /// In en, this message translates to:
  /// **'Measurement completed'**
  String get debugRuntimeMeasurementCompleted;

  /// No description provided for @debugRuntimeMeasurementStopped.
  ///
  /// In en, this message translates to:
  /// **'Measurement stopped'**
  String get debugRuntimeMeasurementStopped;

  /// No description provided for @debugRuntimeMeasurementCollecting.
  ///
  /// In en, this message translates to:
  /// **'Collecting data…'**
  String get debugRuntimeMeasurementCollecting;

  /// No description provided for @debugRuntimeMeasurementHealthy.
  ///
  /// In en, this message translates to:
  /// **'No abnormal resource growth was detected.'**
  String get debugRuntimeMeasurementHealthy;

  /// No description provided for @debugRuntimeMeasurementHighCpu.
  ///
  /// In en, this message translates to:
  /// **'High CPU with low routed traffic. This suggests background native/core work rather than normal transfer load.'**
  String get debugRuntimeMeasurementHighCpu;

  /// No description provided for @debugRuntimeMeasurementGoroutineGrowth.
  ///
  /// In en, this message translates to:
  /// **'Core task count increased during the measurement.'**
  String get debugRuntimeMeasurementGoroutineGrowth;

  /// No description provided for @debugRuntimeMeasurementMemoryGrowth.
  ///
  /// In en, this message translates to:
  /// **'Process memory grew noticeably during the measurement.'**
  String get debugRuntimeMeasurementMemoryGrowth;

  /// No description provided for @debugRuntimeMeasurementConnectionChurn.
  ///
  /// In en, this message translates to:
  /// **'Many core connections were present while traffic was low.'**
  String get debugRuntimeMeasurementConnectionChurn;

  /// No description provided for @debugRuntimeMeasurementUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not enough data for an assessment yet.'**
  String get debugRuntimeMeasurementUnavailable;

  /// No description provided for @debugRuntimeMeasurementSaved.
  ///
  /// In en, this message translates to:
  /// **'Measurement report is ready to save'**
  String get debugRuntimeMeasurementSaved;

  /// No description provided for @teamPageTitle.
  ///
  /// In en, this message translates to:
  /// **'MeowTeam'**
  String get teamPageTitle;

  /// No description provided for @teamIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'The team behind Etonify'**
  String get teamIntroTitle;

  /// No description provided for @teamIntroBody.
  ///
  /// In en, this message translates to:
  /// **'MeowTeam is two developers building Etonify, its core, and networking components together as an independent open-source project.'**
  String get teamIntroBody;

  /// No description provided for @teamTimelineForkTitle.
  ///
  /// In en, this message translates to:
  /// **'Early client development'**
  String get teamTimelineForkTitle;

  /// No description provided for @teamTimelineForkBody.
  ///
  /// In en, this message translates to:
  /// **'Early test versions helped define the Android runtime, subscription handling, diagnostics, and interface that Etonify now maintains.'**
  String get teamTimelineForkBody;

  /// No description provided for @teamTimelineRefactorTitle.
  ///
  /// In en, this message translates to:
  /// **'Large refactor'**
  String get teamTimelineRefactorTitle;

  /// No description provided for @teamTimelineRefactorBody.
  ///
  /// In en, this message translates to:
  /// **'We gradually split the large legacy code into focused components, simplified VPN control, and added checks for critical scenarios.'**
  String get teamTimelineRefactorBody;

  /// No description provided for @teamTimelineCoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Moving to etonify-core'**
  String get teamTimelineCoreTitle;

  /// No description provided for @teamTimelineCoreBody.
  ///
  /// In en, this message translates to:
  /// **'After MeowSingBox, the client moved to a more stable sing-box base with the changes Etonify needs. Maintaining our own core makes updates and testing easier, while URLTest, server failover, and resource-cleanup improvements benefit everyday use.'**
  String get teamTimelineCoreBody;

  /// No description provided for @teamTimelineNowTitle.
  ///
  /// In en, this message translates to:
  /// **'Etonify today'**
  String get teamTimelineNowTitle;

  /// No description provided for @teamTimelineNowBody.
  ///
  /// In en, this message translates to:
  /// **'Etonify is still evolving: we keep simplifying UX, improving Android stability, and cutting technical debt without losing the speed-focused VPN experience.'**
  String get teamTimelineNowBody;

  /// No description provided for @teamDeveloperDdosxdRole.
  ///
  /// In en, this message translates to:
  /// **'Core, networking, and custom protocols'**
  String get teamDeveloperDdosxdRole;

  /// No description provided for @teamDeveloperYamixdevRole.
  ///
  /// In en, this message translates to:
  /// **'Android client, interface, core, and releases'**
  String get teamDeveloperYamixdevRole;

  /// No description provided for @teamDeveloperVerificationInfo.
  ///
  /// In en, this message translates to:
  /// **'Member of MeowTeam.'**
  String get teamDeveloperVerificationInfo;

  /// No description provided for @teamTelegramRole.
  ///
  /// In en, this message translates to:
  /// **'Official channel and release news'**
  String get teamTelegramRole;

  /// No description provided for @languageSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSettingTitle;

  /// No description provided for @themeSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeSettingTitle;

  /// No description provided for @accentColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColorTitle;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeAmoled.
  ///
  /// In en, this message translates to:
  /// **'AMOLED'**
  String get themeAmoled;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Resources & diagnostics'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Memory, core status, and diagnostics.'**
  String get diagnosticsSubtitle;

  /// No description provided for @aboutResourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get aboutResourcesTitle;

  /// No description provided for @aboutResourcesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'On-demand Android and core snapshot. CPU appears after the second refresh.'**
  String get aboutResourcesSubtitle;

  /// No description provided for @aboutResourcesPssTitle.
  ///
  /// In en, this message translates to:
  /// **'Process memory'**
  String get aboutResourcesPssTitle;

  /// No description provided for @aboutResourcesPssSubtitle.
  ///
  /// In en, this message translates to:
  /// **'PSS is the primary memory estimate including a share of common pages. RSS counts every resident page, Private Dirty covers modified pages owned only by this process, and Swap PSS is its proportional swap share. Do not add these values together.'**
  String get aboutResourcesPssSubtitle;

  /// No description provided for @aboutResourcePss.
  ///
  /// In en, this message translates to:
  /// **'Total PSS'**
  String get aboutResourcePss;

  /// No description provided for @aboutResourceRss.
  ///
  /// In en, this message translates to:
  /// **'Total RSS'**
  String get aboutResourceRss;

  /// No description provided for @aboutResourceSwapPss.
  ///
  /// In en, this message translates to:
  /// **'Swap PSS'**
  String get aboutResourceSwapPss;

  /// No description provided for @aboutResourcePrivateDirty.
  ///
  /// In en, this message translates to:
  /// **'Private Dirty'**
  String get aboutResourcePrivateDirty;

  /// No description provided for @aboutResourceNativePss.
  ///
  /// In en, this message translates to:
  /// **'Native PSS'**
  String get aboutResourceNativePss;

  /// No description provided for @aboutResourceDalvikPss.
  ///
  /// In en, this message translates to:
  /// **'Android VM PSS'**
  String get aboutResourceDalvikPss;

  /// No description provided for @aboutResourceOtherPss.
  ///
  /// In en, this message translates to:
  /// **'Other PSS'**
  String get aboutResourceOtherPss;

  /// No description provided for @aboutResourceGraphicsPss.
  ///
  /// In en, this message translates to:
  /// **'Graphics PSS'**
  String get aboutResourceGraphicsPss;

  /// No description provided for @aboutResourceCodePss.
  ///
  /// In en, this message translates to:
  /// **'Code PSS'**
  String get aboutResourceCodePss;

  /// No description provided for @aboutResourceStackPss.
  ///
  /// In en, this message translates to:
  /// **'Stack PSS'**
  String get aboutResourceStackPss;

  /// No description provided for @aboutResourcesRuntimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Client and core'**
  String get aboutResourcesRuntimeTitle;

  /// No description provided for @aboutResourceNativeHeap.
  ///
  /// In en, this message translates to:
  /// **'Native heap'**
  String get aboutResourceNativeHeap;

  /// No description provided for @aboutResourceJavaHeap.
  ///
  /// In en, this message translates to:
  /// **'Java heap'**
  String get aboutResourceJavaHeap;

  /// No description provided for @aboutResourceCoreMemory.
  ///
  /// In en, this message translates to:
  /// **'Core memory'**
  String get aboutResourceCoreMemory;

  /// No description provided for @aboutResourceFlutterImageCache.
  ///
  /// In en, this message translates to:
  /// **'Flutter image cache'**
  String get aboutResourceFlutterImageCache;

  /// No description provided for @aboutResourceCoreGoroutines.
  ///
  /// In en, this message translates to:
  /// **'Core goroutines'**
  String get aboutResourceCoreGoroutines;

  /// No description provided for @aboutResourceCoreConnections.
  ///
  /// In en, this message translates to:
  /// **'Core connections (in / out)'**
  String get aboutResourceCoreConnections;

  /// No description provided for @aboutResourcesSystemTitle.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get aboutResourcesSystemTitle;

  /// No description provided for @aboutResourceProcessCpu.
  ///
  /// In en, this message translates to:
  /// **'Process CPU since last refresh'**
  String get aboutResourceProcessCpu;

  /// No description provided for @aboutResourceSystemMemory.
  ///
  /// In en, this message translates to:
  /// **'Free system RAM'**
  String get aboutResourceSystemMemory;

  /// No description provided for @aboutResourceBatteryTemp.
  ///
  /// In en, this message translates to:
  /// **'Battery temperature'**
  String get aboutResourceBatteryTemp;

  /// No description provided for @updatesTitle.
  ///
  /// In en, this message translates to:
  /// **'App updates'**
  String get updatesTitle;

  /// No description provided for @updatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check for a new version and install it.'**
  String get updatesSubtitle;

  /// No description provided for @updatesChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get updatesChecking;

  /// No description provided for @updatesCheckAction.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get updatesCheckAction;

  /// No description provided for @updatesChannelMenuAction.
  ///
  /// In en, this message translates to:
  /// **'Update channel'**
  String get updatesChannelMenuAction;

  /// No description provided for @updatesChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'Update channel'**
  String get updatesChannelTitle;

  /// No description provided for @updatesChannelStable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get updatesChannelStable;

  /// No description provided for @updatesChannelStableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stable releases for everyday use.'**
  String get updatesChannelStableSubtitle;

  /// No description provided for @updatesChannelBeta.
  ///
  /// In en, this message translates to:
  /// **'Beta'**
  String get updatesChannelBeta;

  /// No description provided for @updatesChannelBetaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Test alpha, beta, and RC builds published as GitHub prereleases.'**
  String get updatesChannelBetaSubtitle;

  /// No description provided for @updatesChannelBetaWarning.
  ///
  /// In en, this message translates to:
  /// **'Test builds may contain bugs. You can return to Stable when a stable build becomes newer than the installed build.'**
  String get updatesChannelBetaWarning;

  /// No description provided for @updatesPrereleaseVersionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Test build'**
  String get updatesPrereleaseVersionTooltip;

  /// No description provided for @updatesRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get updatesRetryAction;

  /// No description provided for @updatesUnsupportedAndroidTitle.
  ///
  /// In en, this message translates to:
  /// **'Update not supported'**
  String get updatesUnsupportedAndroidTitle;

  /// No description provided for @updatesUnsupportedAndroidSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version {version} requires Android SDK {minSdk} or newer. This device can keep using the latest compatible release.'**
  String updatesUnsupportedAndroidSubtitle(String version, int minSdk);

  /// No description provided for @updatesDownloadAction.
  ///
  /// In en, this message translates to:
  /// **'Download update'**
  String get updatesDownloadAction;

  /// No description provided for @updatesInstallAction.
  ///
  /// In en, this message translates to:
  /// **'Install APK'**
  String get updatesInstallAction;

  /// No description provided for @updatesDownloadWarning.
  ///
  /// In en, this message translates to:
  /// **'Keep Etonify open until the download finishes.'**
  String get updatesDownloadWarning;

  /// No description provided for @updatesOpeningInstaller.
  ///
  /// In en, this message translates to:
  /// **'Opening the system installer…'**
  String get updatesOpeningInstaller;

  /// No description provided for @updatesInstallPermissionHint.
  ///
  /// In en, this message translates to:
  /// **'Allow APK installs for Etonify, then tap “Install APK” again.'**
  String get updatesInstallPermissionHint;

  /// No description provided for @updatesInstallPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission required'**
  String get updatesInstallPermissionTitle;

  /// No description provided for @updatesInstallPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Allow Etonify to install unknown apps before it can open the downloaded APK installer. Without this permission you can only download the file manually.'**
  String get updatesInstallPermissionMessage;

  /// No description provided for @updatesInstallPermissionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get updatesInstallPermissionOpen;

  /// No description provided for @updatesInstallPermissionGranted.
  ///
  /// In en, this message translates to:
  /// **'APK install permission is enabled.'**
  String get updatesInstallPermissionGranted;

  /// No description provided for @updatesInstallModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Update installation'**
  String get updatesInstallModeTitle;

  /// No description provided for @updatesInstallModeAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask every time'**
  String get updatesInstallModeAsk;

  /// No description provided for @updatesInstallModeAskSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Etonify will ask whether to download manually or install automatically.'**
  String get updatesInstallModeAskSubtitle;

  /// No description provided for @updatesInstallModeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get updatesInstallModeManual;

  /// No description provided for @updatesInstallModeManualSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The client downloads the APK and shows an install button.'**
  String get updatesInstallModeManualSubtitle;

  /// No description provided for @updatesInstallModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get updatesInstallModeAuto;

  /// No description provided for @updatesInstallModeAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The client downloads the APK and opens the Android installer.'**
  String get updatesInstallModeAutoSubtitle;

  /// No description provided for @updatesInstallMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'How should this update be installed?'**
  String get updatesInstallMethodTitle;

  /// No description provided for @updatesInstallMethodManualTitle.
  ///
  /// In en, this message translates to:
  /// **'Download manually'**
  String get updatesInstallMethodManualTitle;

  /// No description provided for @updatesInstallMethodManualSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The APK is saved in the update cache. You can install it later.'**
  String get updatesInstallMethodManualSubtitle;

  /// No description provided for @updatesInstallMethodAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'Download and install'**
  String get updatesInstallMethodAutoTitle;

  /// No description provided for @updatesInstallMethodAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'After download, Etonify opens the Android system installer.'**
  String get updatesInstallMethodAutoSubtitle;

  /// No description provided for @updatesInstallMethodRemember.
  ///
  /// In en, this message translates to:
  /// **'Remember this choice'**
  String get updatesInstallMethodRemember;

  /// No description provided for @updatesApkVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'APK check'**
  String get updatesApkVerificationTitle;

  /// No description provided for @updatesApkVerificationVerified.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 matches'**
  String get updatesApkVerificationVerified;

  /// No description provided for @updatesApkVerificationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 is not provided by this release'**
  String get updatesApkVerificationUnavailable;

  /// No description provided for @updatesApkVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 does not match'**
  String get updatesApkVerificationFailed;

  /// No description provided for @updatesDownloadedFileMissing.
  ///
  /// In en, this message translates to:
  /// **'The update file is missing. Download the APK again.'**
  String get updatesDownloadedFileMissing;

  /// No description provided for @updatesDeleteCachedApkAction.
  ///
  /// In en, this message translates to:
  /// **'Delete installer APK'**
  String get updatesDeleteCachedApkAction;

  /// No description provided for @updatesDeleteCachedApkTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete installer APK?'**
  String get updatesDeleteCachedApkTitle;

  /// No description provided for @updatesDeleteCachedApkMessage.
  ///
  /// In en, this message translates to:
  /// **'This will delete the downloaded {version} update APK and old temporary Etonify APK files from the app cache.'**
  String updatesDeleteCachedApkMessage(Object version);

  /// No description provided for @updatesDeleteCachedApkDone.
  ///
  /// In en, this message translates to:
  /// **'Update cache cleaned. Files deleted: {count}.'**
  String updatesDeleteCachedApkDone(int count);

  /// No description provided for @updatesUpToDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Etonify is up to date'**
  String get updatesUpToDateTitle;

  /// No description provided for @updatesUpToDateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Installed version: {version}'**
  String updatesUpToDateSubtitle(String version);

  /// No description provided for @updatesCurrentVersionNewerTitle.
  ///
  /// In en, this message translates to:
  /// **'Installed version is newer'**
  String get updatesCurrentVersionNewerTitle;

  /// No description provided for @updatesCurrentVersionNewerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Installed: {currentVersion}. Selected channel: {channelVersion}. No update is required.'**
  String updatesCurrentVersionNewerSubtitle(
    String currentVersion,
    String channelVersion,
  );

  /// No description provided for @updatesNoChannelReleaseTitle.
  ///
  /// In en, this message translates to:
  /// **'No releases in this channel yet'**
  String get updatesNoChannelReleaseTitle;

  /// No description provided for @updatesNoBetaReleaseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No Etonify prerelease has been published on GitHub yet.'**
  String get updatesNoBetaReleaseSubtitle;

  /// No description provided for @updatesNoStableReleaseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No stable Etonify release has been published on GitHub yet.'**
  String get updatesNoStableReleaseSubtitle;

  /// No description provided for @updatesAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updatesAvailableTitle;

  /// No description provided for @updatesAvailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{version} · {size}'**
  String updatesAvailableSubtitle(String version, String size);

  /// No description provided for @updatesAvailableSnack.
  ///
  /// In en, this message translates to:
  /// **'Client update available'**
  String get updatesAvailableSnack;

  /// No description provided for @updatesAvailableSnackVersion.
  ///
  /// In en, this message translates to:
  /// **'Client update {version} is available'**
  String updatesAvailableSnackVersion(Object version);

  /// No description provided for @updatesOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get updatesOpenAction;

  /// No description provided for @updatesDownloadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading update'**
  String get updatesDownloadingTitle;

  /// No description provided for @updatesStageCleaning.
  ///
  /// In en, this message translates to:
  /// **'Removing old files…'**
  String get updatesStageCleaning;

  /// No description provided for @updatesStageVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying APK and signature…'**
  String get updatesStageVerifying;

  /// No description provided for @updatesDownloadedTitle.
  ///
  /// In en, this message translates to:
  /// **'Update downloaded'**
  String get updatesDownloadedTitle;

  /// No description provided for @updatesDownloadedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved to app update cache: {fileName}'**
  String updatesDownloadedSubtitle(String fileName);

  /// No description provided for @updatesErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not check updates'**
  String get updatesErrorTitle;

  /// No description provided for @updatesErrorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If GitHub is blocked on this network, Etonify will try again tomorrow.'**
  String get updatesErrorSubtitle;

  /// No description provided for @updatesCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version'**
  String get updatesCurrentVersion;

  /// No description provided for @updatesLatestVersion.
  ///
  /// In en, this message translates to:
  /// **'Latest version'**
  String get updatesLatestVersion;

  /// No description provided for @updatesAsset.
  ///
  /// In en, this message translates to:
  /// **'APK'**
  String get updatesAsset;

  /// No description provided for @updatesLastChecked.
  ///
  /// In en, this message translates to:
  /// **'Last checked: {time}'**
  String updatesLastChecked(String time);

  /// No description provided for @updatesReleaseNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get updatesReleaseNotesTitle;

  /// No description provided for @updatesNoReleaseNotes.
  ///
  /// In en, this message translates to:
  /// **'This release does not include notes.'**
  String get updatesNoReleaseNotes;

  /// No description provided for @updatesProgressBytes.
  ///
  /// In en, this message translates to:
  /// **'{downloaded} / {total}'**
  String updatesProgressBytes(String downloaded, String total);

  /// No description provided for @updatesProgressSpeedEta.
  ///
  /// In en, this message translates to:
  /// **'{speed}/s · {eta} left'**
  String updatesProgressSpeedEta(String speed, String eta);

  /// No description provided for @updatesEtaSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String updatesEtaSeconds(int seconds);

  /// No description provided for @updatesEtaMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String updatesEtaMinutes(int minutes, int seconds);

  /// No description provided for @updatesUnknownSize.
  ///
  /// In en, this message translates to:
  /// **'Unknown size'**
  String get updatesUnknownSize;

  /// No description provided for @appVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersionLabel;

  /// No description provided for @currentProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Current profile'**
  String get currentProfileLabel;

  /// No description provided for @selectedProxyLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected proxy'**
  String get selectedProxyLabel;

  /// No description provided for @onboardingStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Intro'**
  String get onboardingStatusLabel;

  /// No description provided for @onboardingSeen.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get onboardingSeen;

  /// No description provided for @showOnboardingAgain.
  ///
  /// In en, this message translates to:
  /// **'Show intro again'**
  String get showOnboardingAgain;

  /// No description provided for @settingsFootnote.
  ///
  /// In en, this message translates to:
  /// **'These settings are local to this device and are stored in Hive.'**
  String get settingsFootnote;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @tapToConnect.
  ///
  /// In en, this message translates to:
  /// **'Tap to Connect'**
  String get tapToConnect;

  /// No description provided for @resolvingIp.
  ///
  /// In en, this message translates to:
  /// **'Resolving IP…'**
  String get resolvingIp;

  /// No description provided for @millisecondsUnit.
  ///
  /// In en, this message translates to:
  /// **' ms'**
  String get millisecondsUnit;

  /// No description provided for @refreshLatency.
  ///
  /// In en, this message translates to:
  /// **'Refresh latency'**
  String get refreshLatency;

  /// No description provided for @checkingLatency.
  ///
  /// In en, this message translates to:
  /// **'Checking latency'**
  String get checkingLatency;

  /// No description provided for @checkingLatencyShort.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checkingLatencyShort;

  /// No description provided for @openTrafficDashboard.
  ///
  /// In en, this message translates to:
  /// **'Open traffic dashboard'**
  String get openTrafficDashboard;

  /// No description provided for @refreshActiveSubscription.
  ///
  /// In en, this message translates to:
  /// **'Refresh current subscription'**
  String get refreshActiveSubscription;

  /// No description provided for @refreshActiveSubscriptionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Manual imports cannot be refreshed'**
  String get refreshActiveSubscriptionUnavailable;

  /// No description provided for @activeSubscriptionRefreshComplete.
  ///
  /// In en, this message translates to:
  /// **'{name} updated'**
  String activeSubscriptionRefreshComplete(String name);

  /// No description provided for @trafficDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Traffic dashboard'**
  String get trafficDashboardTitle;

  /// No description provided for @trafficDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live speed, session totals, and connection info'**
  String get trafficDashboardSubtitle;

  /// No description provided for @trafficDashboardDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get trafficDashboardDownload;

  /// No description provided for @trafficDashboardUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get trafficDashboardUpload;

  /// No description provided for @trafficDashboardSessionTraffic.
  ///
  /// In en, this message translates to:
  /// **'Session traffic'**
  String get trafficDashboardSessionTraffic;

  /// No description provided for @trafficDashboardConnectedFor.
  ///
  /// In en, this message translates to:
  /// **'Connected for'**
  String get trafficDashboardConnectedFor;

  /// No description provided for @trafficDashboardGraphTitle.
  ///
  /// In en, this message translates to:
  /// **'Live traffic'**
  String get trafficDashboardGraphTitle;

  /// No description provided for @trafficDashboardGraphMax.
  ///
  /// In en, this message translates to:
  /// **'Peak {speed}'**
  String trafficDashboardGraphMax(String speed);

  /// No description provided for @trafficDashboardNoSamples.
  ///
  /// In en, this message translates to:
  /// **'Waiting for traffic data'**
  String get trafficDashboardNoSamples;

  /// No description provided for @trafficDashboardConnectionState.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get trafficDashboardConnectionState;

  /// No description provided for @trafficDashboardCurrentProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get trafficDashboardCurrentProfile;

  /// No description provided for @trafficDashboardActiveProxy.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get trafficDashboardActiveProxy;

  /// No description provided for @trafficDashboardServerIp.
  ///
  /// In en, this message translates to:
  /// **'Server IP'**
  String get trafficDashboardServerIp;

  /// No description provided for @trafficDashboardDownloadTotal.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get trafficDashboardDownloadTotal;

  /// No description provided for @trafficDashboardUploadTotal.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get trafficDashboardUploadTotal;

  /// No description provided for @trafficDashboardStateConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get trafficDashboardStateConnected;

  /// No description provided for @trafficDashboardStateConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get trafficDashboardStateConnecting;

  /// No description provided for @trafficDashboardStateDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get trafficDashboardStateDisconnected;

  /// No description provided for @trafficDashboardUptimeHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String trafficDashboardUptimeHours(int hours, int minutes);

  /// No description provided for @trafficDashboardUptimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min {seconds} s'**
  String trafficDashboardUptimeMinutes(int minutes, int seconds);

  /// No description provided for @trafficDashboardUptimeSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String trafficDashboardUptimeSeconds(int seconds);

  /// No description provided for @notAvailableShort.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get notAvailableShort;

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days} days left'**
  String daysLeft(int days);

  /// No description provided for @daysLeftUnlimited.
  ///
  /// In en, this message translates to:
  /// **'∞ days left'**
  String get daysLeftUnlimited;

  /// No description provided for @unlimitedTraffic.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get unlimitedTraffic;

  /// No description provided for @unlimitedSymbol.
  ///
  /// In en, this message translates to:
  /// **'∞'**
  String get unlimitedSymbol;

  /// No description provided for @welcomeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi'**
  String get welcomeGreeting;

  /// No description provided for @welcomeTitlePrefix.
  ///
  /// In en, this message translates to:
  /// **'Welcome to'**
  String get welcomeTitlePrefix;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fast Android VPN client'**
  String get welcomeSubtitle;

  /// No description provided for @welcomeTapHint.
  ///
  /// In en, this message translates to:
  /// **'tap anywhere to continue'**
  String get welcomeTapHint;

  /// No description provided for @hapticTitle.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get hapticTitle;

  /// No description provided for @hapticSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Light vibration for important actions'**
  String get hapticSubtitle;

  /// No description provided for @statusNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification status'**
  String get statusNotificationTitle;

  /// No description provided for @statusNotificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shows the selected server, speed, and latency while VPN is active.'**
  String get statusNotificationSubtitle;

  /// No description provided for @notificationSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'VPN notification'**
  String get notificationSettingsTitle;

  /// No description provided for @notificationSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Server, traffic, latency, and refresh rate.'**
  String get notificationSettingsSubtitle;

  /// No description provided for @notificationTrafficDisplayTitle.
  ///
  /// In en, this message translates to:
  /// **'What to show in notification'**
  String get notificationTrafficDisplayTitle;

  /// No description provided for @notificationTrafficDisplaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Current speed, total transferred, or both.'**
  String get notificationTrafficDisplaySubtitle;

  /// No description provided for @notificationTrafficDisplaySpeed.
  ///
  /// In en, this message translates to:
  /// **'Current speed'**
  String get notificationTrafficDisplaySpeed;

  /// No description provided for @notificationTrafficDisplayTotal.
  ///
  /// In en, this message translates to:
  /// **'Total transferred'**
  String get notificationTrafficDisplayTotal;

  /// No description provided for @notificationTrafficDisplayBoth.
  ///
  /// In en, this message translates to:
  /// **'Speed and total'**
  String get notificationTrafficDisplayBoth;

  /// No description provided for @notificationTrafficTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total traffic'**
  String get notificationTrafficTotalLabel;

  /// No description provided for @notificationTrafficRefreshTitle.
  ///
  /// In en, this message translates to:
  /// **'Traffic refresh'**
  String get notificationTrafficRefreshTitle;

  /// No description provided for @notificationTrafficRefreshSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How often to update data in the notification.'**
  String get notificationTrafficRefreshSubtitle;

  /// No description provided for @notificationTrafficRefreshSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String notificationTrafficRefreshSeconds(int seconds);

  /// No description provided for @notificationConnected.
  ///
  /// In en, this message translates to:
  /// **'VPN connected'**
  String get notificationConnected;

  /// No description provided for @notificationPingChecking.
  ///
  /// In en, this message translates to:
  /// **'...'**
  String get notificationPingChecking;

  /// No description provided for @notificationPingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Latency unavailable'**
  String get notificationPingUnavailable;

  /// No description provided for @notificationRefreshPingAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh latency'**
  String get notificationRefreshPingAction;

  /// No description provided for @notificationStopAction.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get notificationStopAction;

  /// No description provided for @hideServerIpTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide server IP'**
  String get hideServerIpTitle;

  /// No description provided for @hideServerIpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Masks last two octets of the IP address'**
  String get hideServerIpSubtitle;

  /// No description provided for @memoryLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Soft core memory limit'**
  String get memoryLimitTitle;

  /// No description provided for @memoryLimitEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recommended. Limits only memory managed by the Go part of sing-box and encourages earlier cleanup of unused data. Reaching this limit does not stop the VPN. Changes take effect after app restart.'**
  String get memoryLimitEnabledSubtitle;

  /// No description provided for @memoryLimitDisabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disabled. The Go part of sing-box manages memory without an Etonify budget and may retain more RAM. Takes effect after app restart.'**
  String get memoryLimitDisabledSubtitle;

  /// No description provided for @memoryLimitDisableWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable the soft core limit?'**
  String get memoryLimitDisableWarningTitle;

  /// No description provided for @memoryLimitDisableWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Without the soft limit, the Go part of sing-box may retain unused memory for longer. This does not change Flutter or Android memory limits and does not affect system process termination. The change takes effect after restarting Etonify.'**
  String get memoryLimitDisableWarningMessage;

  /// No description provided for @memoryLimitDisableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get memoryLimitDisableConfirm;

  /// No description provided for @enableInboundTitle.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enableInboundTitle;

  /// No description provided for @vpnInDescription.
  ///
  /// In en, this message translates to:
  /// **'VPN TUN is the Android system VPN path for phone traffic. Apps see an Android VPN, while routing decides what goes through proxy or direct.'**
  String get vpnInDescription;

  /// No description provided for @vpnInboundEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Creates a VPN TUN inbound and routes traffic through it'**
  String get vpnInboundEnabledSubtitle;

  /// No description provided for @inboundNoneEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable VPN TUN or Proxy In before starting.'**
  String get inboundNoneEnabled;

  /// No description provided for @mtuTitle.
  ///
  /// In en, this message translates to:
  /// **'MTU'**
  String get mtuTitle;

  /// No description provided for @mtuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'TUN interface packet size'**
  String get mtuSubtitle;

  /// No description provided for @mtuInputRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a value from 1280 to 9000.'**
  String get mtuInputRange;

  /// No description provided for @mtuInvalidValue.
  ///
  /// In en, this message translates to:
  /// **'Use a value from 1280 to 9000.'**
  String get mtuInvalidValue;

  /// No description provided for @strictRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Prevent VPN bypass'**
  String get strictRouteTitle;

  /// No description provided for @strictRouteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Forces traffic through VPN and reduces the chance of traffic escaping the tunnel'**
  String get strictRouteSubtitle;

  /// No description provided for @tunImplementationTitle.
  ///
  /// In en, this message translates to:
  /// **'TUN network stack'**
  String get tunImplementationTitle;

  /// No description provided for @tunImplementationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Controls how the client handles TCP and UDP traffic inside the VPN'**
  String get tunImplementationSubtitle;

  /// No description provided for @tunImplementationMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed (system TCP + gVisor UDP)'**
  String get tunImplementationMixed;

  /// No description provided for @tunImplementationMixedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Uses the Android system stack for TCP and gVisor for UDP. This is sing-box\'s default when gVisor is available.'**
  String get tunImplementationMixedSubtitle;

  /// No description provided for @tunImplementationSystem.
  ///
  /// In en, this message translates to:
  /// **'System (Android)'**
  String get tunImplementationSystem;

  /// No description provided for @tunImplementationSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Uses the Android system network stack for TCP and UDP. Compatibility depends on the device and its firmware.'**
  String get tunImplementationSystemSubtitle;

  /// No description provided for @tunImplementationGvisor.
  ///
  /// In en, this message translates to:
  /// **'gVisor'**
  String get tunImplementationGvisor;

  /// No description provided for @tunImplementationGvisorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Uses the gVisor userspace network stack for TCP and UDP. It can help when the system stack is unstable.'**
  String get tunImplementationGvisorSubtitle;

  /// No description provided for @proxyInDescription.
  ///
  /// In en, this message translates to:
  /// **'Proxy In / mixed is a local HTTP/SOCKS entry for apps or other devices that you configure manually. It is not the Android system VPN.'**
  String get proxyInDescription;

  /// No description provided for @proxyInboundEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Starts a local mixed inbound for apps and devices'**
  String get proxyInboundEnabledSubtitle;

  /// No description provided for @allowLanConnectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow LAN connections'**
  String get allowLanConnectionsTitle;

  /// No description provided for @allowLanConnectionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If enabled, listen on 0.0.0.0, otherwise on 127.0.0.1'**
  String get allowLanConnectionsSubtitle;

  /// No description provided for @portTitle.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get portTitle;

  /// No description provided for @proxyPortSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local mixed inbound port'**
  String get proxyPortSubtitle;

  /// No description provided for @connectionModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection mode'**
  String get connectionModeTitle;

  /// No description provided for @connectionModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'VPN covers the whole phone. Local proxy is used only by apps and devices configured with its address manually.'**
  String get connectionModeSubtitle;

  /// No description provided for @connectionModeVpn.
  ///
  /// In en, this message translates to:
  /// **'VPN'**
  String get connectionModeVpn;

  /// No description provided for @connectionModeVpnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'System Android VPN for all phone traffic'**
  String get connectionModeVpnSubtitle;

  /// No description provided for @connectionModeProxy.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get connectionModeProxy;

  /// No description provided for @connectionModeProxySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local HTTP/SOCKS without a system VPN'**
  String get connectionModeProxySubtitle;

  /// No description provided for @connectionModeActiveStatus.
  ///
  /// In en, this message translates to:
  /// **'Active: {mode}'**
  String connectionModeActiveStatus(String mode);

  /// No description provided for @connectionModeVpnStatusName.
  ///
  /// In en, this message translates to:
  /// **'VPN TUN'**
  String get connectionModeVpnStatusName;

  /// No description provided for @connectionModeProxyStatusName.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get connectionModeProxyStatusName;

  /// No description provided for @advancedTunTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced TUN settings'**
  String get advancedTunTitle;

  /// No description provided for @advancedTunSubtitle.
  ///
  /// In en, this message translates to:
  /// **'MTU, strict routing, and network stack implementation'**
  String get advancedTunSubtitle;

  /// No description provided for @localProxyTitle.
  ///
  /// In en, this message translates to:
  /// **'Local proxy'**
  String get localProxyTitle;

  /// No description provided for @localProxySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Additional HTTP/SOCKS endpoint for manually configured apps'**
  String get localProxySubtitle;

  /// No description provided for @localProxySettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Address, port, and access credentials'**
  String get localProxySettingsSubtitle;

  /// No description provided for @lanProxySecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Access protected'**
  String get lanProxySecurityTitle;

  /// No description provided for @lanProxySecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'LAN devices must provide the username and password. Authentication prevents unauthorized use but does not encrypt the local network by itself.'**
  String get lanProxySecuritySubtitle;

  /// No description provided for @proxyUsernameTitle.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get proxyUsernameTitle;

  /// No description provided for @proxyUsernameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'1–64 characters, without spaces or a colon'**
  String get proxyUsernameSubtitle;

  /// No description provided for @proxyPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get proxyPasswordTitle;

  /// No description provided for @regenerateProxyPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get regenerateProxyPasswordTitle;

  /// No description provided for @copyProxyCredentialsTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy connection details'**
  String get copyProxyCredentialsTitle;

  /// No description provided for @proxyCredentialsCopied.
  ///
  /// In en, this message translates to:
  /// **'Proxy connection details copied'**
  String get proxyCredentialsCopied;

  /// No description provided for @proxyEndpointTitle.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get proxyEndpointTitle;

  /// No description provided for @proxyLanAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Phone IP'**
  String get proxyLanAddressHint;

  /// No description provided for @dnsUsePresetTitle.
  ///
  /// In en, this message translates to:
  /// **'Use preset'**
  String get dnsUsePresetTitle;

  /// No description provided for @dnsResolverTitle.
  ///
  /// In en, this message translates to:
  /// **'Resolver'**
  String get dnsResolverTitle;

  /// No description provided for @dnsDirectPresetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recommended: udp://1.1.1.1'**
  String get dnsDirectPresetSubtitle;

  /// No description provided for @dnsDirectResolverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'DNS for direct requests without proxy'**
  String get dnsDirectResolverSubtitle;

  /// No description provided for @dnsProxyPresetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recommended: https://dns.cloudflare.com/dns-query'**
  String get dnsProxyPresetSubtitle;

  /// No description provided for @dnsProxyResolverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'DNS for requests through proxy'**
  String get dnsProxyResolverSubtitle;

  /// No description provided for @dnsResolverTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Resolver type'**
  String get dnsResolverTypeTitle;

  /// No description provided for @dnsPresetDevice.
  ///
  /// In en, this message translates to:
  /// **'Device network'**
  String get dnsPresetDevice;

  /// No description provided for @dnsPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get dnsPresetCustom;

  /// No description provided for @dnsPresetDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use DNS from the current Android network.'**
  String get dnsPresetDeviceSubtitle;

  /// No description provided for @dnsPresetCustomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter an IP/host (UDP by default) or use udp://, tcp://, tls://, or https://.'**
  String get dnsPresetCustomSubtitle;

  /// No description provided for @dnsPresetUdpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plain UDP DNS. Fast, but not encrypted.'**
  String get dnsPresetUdpSubtitle;

  /// No description provided for @dnsPresetTcpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plain TCP DNS. More stable on some networks, but not encrypted.'**
  String get dnsPresetTcpSubtitle;

  /// No description provided for @dnsPresetTlsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'DNS over TLS. Encrypted DNS on port 853.'**
  String get dnsPresetTlsSubtitle;

  /// No description provided for @dnsPresetHttpsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'DNS over HTTPS. Encrypted DNS over HTTPS, often best through proxy.'**
  String get dnsPresetHttpsSubtitle;

  /// No description provided for @dnsPreferIpv6Title.
  ///
  /// In en, this message translates to:
  /// **'Prefer IPv6'**
  String get dnsPreferIpv6Title;

  /// No description provided for @dnsPreferIpv6Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Prefer IPv6 when both address versions are available'**
  String get dnsPreferIpv6Subtitle;

  /// No description provided for @urlTestUrlTitle.
  ///
  /// In en, this message translates to:
  /// **'Test URL'**
  String get urlTestUrlTitle;

  /// No description provided for @urlTestUrlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If the subscription already defines a value, that value is used'**
  String get urlTestUrlSubtitle;

  /// No description provided for @urlTestIntervalTitle.
  ///
  /// In en, this message translates to:
  /// **'Interval, sec.'**
  String get urlTestIntervalTitle;

  /// No description provided for @urlTestIntervalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How often proxies are checked for automatic selection'**
  String get urlTestIntervalSubtitle;

  /// No description provided for @urlTestTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Timeout, sec.'**
  String get urlTestTimeoutTitle;

  /// No description provided for @urlTestTimeoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How long to wait for one proxy test before failing it'**
  String get urlTestTimeoutSubtitle;

  /// No description provided for @urlTestConcurrencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Test concurrency'**
  String get urlTestConcurrencyTitle;

  /// No description provided for @urlTestConcurrencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How many proxies URLTest checks at the same time'**
  String get urlTestConcurrencySubtitle;

  /// No description provided for @urlTestSingleRetestTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick retry delay, sec.'**
  String get urlTestSingleRetestTitle;

  /// No description provided for @urlTestSingleRetestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How long to wait before one quick recheck after a proxy fails'**
  String get urlTestSingleRetestSubtitle;

  /// No description provided for @locationLookupTitle.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get locationLookupTitle;

  /// No description provided for @locationLookupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'IP and country through the proxies themselves'**
  String get locationLookupSubtitle;

  /// No description provided for @locationLookupLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Check best proxies'**
  String get locationLookupLimitTitle;

  /// No description provided for @locationLookupLimitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'After URLTest, the app resolves external IP and country for this many fastest outbounds'**
  String get locationLookupLimitSubtitle;

  /// No description provided for @locationLookupTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Request timeout'**
  String get locationLookupTimeoutTitle;

  /// No description provided for @locationLookupTimeoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How long to wait for external IP and country for one server'**
  String get locationLookupTimeoutSubtitle;

  /// No description provided for @locationLookupConcurrencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Parallel requests'**
  String get locationLookupConcurrencyTitle;

  /// No description provided for @locationLookupConcurrencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How many location requests may run at the same time'**
  String get locationLookupConcurrencySubtitle;

  /// No description provided for @settingsSecondsShort.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String settingsSecondsShort(int seconds);

  /// No description provided for @serverRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Server request'**
  String get serverRequestTitle;

  /// No description provided for @sendHwidTitle.
  ///
  /// In en, this message translates to:
  /// **'Send HWID'**
  String get sendHwidTitle;

  /// No description provided for @sendHwidSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Required by some Happ subscriptions'**
  String get sendHwidSubtitle;

  /// No description provided for @useCustomHwidTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a custom HWID'**
  String get useCustomHwidTitle;

  /// No description provided for @useCustomHwidSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use it instead of this device\'s HWID'**
  String get useCustomHwidSubtitle;

  /// No description provided for @customUserAgentTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom User-Agent'**
  String get customUserAgentTitle;

  /// No description provided for @customUserAgentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Overrides the default Etonify user agent for this subscription'**
  String get customUserAgentSubtitle;

  /// No description provided for @customHwidTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom HWID'**
  String get customHwidTitle;

  /// No description provided for @customHwidSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the device HWID'**
  String get customHwidSubtitle;

  /// No description provided for @customRequestHeadersTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom headers'**
  String get customRequestHeadersTitle;

  /// No description provided for @customRequestHeadersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One header per line in Header: value format'**
  String get customRequestHeadersSubtitle;

  /// No description provided for @hwidTitle.
  ///
  /// In en, this message translates to:
  /// **'HWID'**
  String get hwidTitle;

  /// No description provided for @hwidSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your device identifier used by some subscription providers'**
  String get hwidSubtitle;

  /// No description provided for @hwidValueTitle.
  ///
  /// In en, this message translates to:
  /// **'Your HWID'**
  String get hwidValueTitle;

  /// No description provided for @coreStartFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to start core'**
  String get coreStartFailedTitle;

  /// No description provided for @coreStartFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'sing-box failed to start.\n\n{message}'**
  String coreStartFailedMessage(String message);

  /// No description provided for @vpnStopFailed.
  ///
  /// In en, this message translates to:
  /// **'VPN did not stop completely. Open logs and try again.'**
  String get vpnStopFailed;

  /// No description provided for @clearLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear logs'**
  String get clearLogsTitle;

  /// No description provided for @logsFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get logsFilterTitle;

  /// No description provided for @logsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get logsFilterAll;

  /// No description provided for @singBoxLogLevelTitle.
  ///
  /// In en, this message translates to:
  /// **'sing-box log level'**
  String get singBoxLogLevelTitle;

  /// No description provided for @logLevelTrace.
  ///
  /// In en, this message translates to:
  /// **'Trace'**
  String get logLevelTrace;

  /// No description provided for @logLevelDebug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get logLevelDebug;

  /// No description provided for @logLevelInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get logLevelInfo;

  /// No description provided for @logLevelWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get logLevelWarning;

  /// No description provided for @logLevelError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get logLevelError;

  /// No description provided for @noLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get noLogsTitle;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get continueLabel;

  /// No description provided for @subscriptionsTab.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptionsTab;

  /// No description provided for @subscriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptionsTitle;

  /// No description provided for @settingsProfilesChecksTitle.
  ///
  /// In en, this message translates to:
  /// **'Profiles and checks'**
  String get settingsProfilesChecksTitle;

  /// No description provided for @settingsProfilesChecksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Server checks · HWID · profile options'**
  String get settingsProfilesChecksSubtitle;

  /// No description provided for @addSubscription.
  ///
  /// In en, this message translates to:
  /// **'Add subscription'**
  String get addSubscription;

  /// No description provided for @addSubscriptionQuickTitle.
  ///
  /// In en, this message translates to:
  /// **'Add profile'**
  String get addSubscriptionQuickTitle;

  /// No description provided for @addSubscriptionQuickSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how to import a subscription.'**
  String get addSubscriptionQuickSubtitle;

  /// No description provided for @addSubscriptionFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get addSubscriptionFromClipboard;

  /// No description provided for @addSubscriptionManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get addSubscriptionManual;

  /// No description provided for @addSubscriptionReadingClipboard.
  ///
  /// In en, this message translates to:
  /// **'Reading clipboard…'**
  String get addSubscriptionReadingClipboard;

  /// No description provided for @addSubscriptionReadingFile.
  ///
  /// In en, this message translates to:
  /// **'Reading file…'**
  String get addSubscriptionReadingFile;

  /// No description provided for @addSubscriptionImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing subscription…'**
  String get addSubscriptionImporting;

  /// No description provided for @addSubscriptionSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving profile…'**
  String get addSubscriptionSaving;

  /// No description provided for @addSubscriptionDone.
  ///
  /// In en, this message translates to:
  /// **'Subscription added'**
  String get addSubscriptionDone;

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty'**
  String get clipboardEmpty;

  /// No description provided for @scanQrCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get scanQrCode;

  /// No description provided for @showQrCode.
  ///
  /// In en, this message translates to:
  /// **'Show QR'**
  String get showQrCode;

  /// No description provided for @subscriptionQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription QR'**
  String get subscriptionQrTitle;

  /// No description provided for @subscriptionQrHint.
  ///
  /// In en, this message translates to:
  /// **'Scan this code on another device to import the subscription.'**
  String get subscriptionQrHint;

  /// No description provided for @subscriptionQrUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This subscription cannot be shared as QR yet.'**
  String get subscriptionQrUnsupported;

  /// No description provided for @invalidQrSubscription.
  ///
  /// In en, this message translates to:
  /// **'The QR code does not contain a supported subscription link.'**
  String get invalidQrSubscription;

  /// No description provided for @subscriptionUrl.
  ///
  /// In en, this message translates to:
  /// **'Subscription URL'**
  String get subscriptionUrl;

  /// No description provided for @editSubscriptionUrlAction.
  ///
  /// In en, this message translates to:
  /// **'Edit URL'**
  String get editSubscriptionUrlAction;

  /// No description provided for @saveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// No description provided for @subscriptionUrlEditHint.
  ///
  /// In en, this message translates to:
  /// **'A profile can update from one URL. If an old import glued several links together, keep the required line and add the other sources as separate profiles. Refresh the subscription after saving.'**
  String get subscriptionUrlEditHint;

  /// No description provided for @subscriptionUrlSingleSourceRequired.
  ///
  /// In en, this message translates to:
  /// **'Keep one URL. Add the other sources as separate profiles.'**
  String get subscriptionUrlSingleSourceRequired;

  /// No description provided for @subscriptionUrlOrContent.
  ///
  /// In en, this message translates to:
  /// **'URL or content'**
  String get subscriptionUrlOrContent;

  /// No description provided for @subscriptionUrlOrContentHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a URL, vless:// link, link list, or config'**
  String get subscriptionUrlOrContentHint;

  /// No description provided for @importFromFile.
  ///
  /// In en, this message translates to:
  /// **'From file'**
  String get importFromFile;

  /// No description provided for @invalidSubscriptionFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to read the subscription file'**
  String get invalidSubscriptionFile;

  /// No description provided for @backupUseSettingsImport.
  ///
  /// In en, this message translates to:
  /// **'This is an Etonify backup. Import it from Settings → Import.'**
  String get backupUseSettingsImport;

  /// No description provided for @subscriptionName.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get subscriptionName;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @reparseProxies.
  ///
  /// In en, this message translates to:
  /// **'Reparse proxies'**
  String get reparseProxies;

  /// No description provided for @subscriptionLocalImportBadge.
  ///
  /// In en, this message translates to:
  /// **'Local import'**
  String get subscriptionLocalImportBadge;

  /// No description provided for @refreshAll.
  ///
  /// In en, this message translates to:
  /// **'Refresh all'**
  String get refreshAll;

  /// No description provided for @refreshSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Refresh subscriptions'**
  String get refreshSubscriptions;

  /// No description provided for @subscriptionSortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort subscriptions'**
  String get subscriptionSortTitle;

  /// No description provided for @subscriptionSortManual.
  ///
  /// In en, this message translates to:
  /// **'Current order'**
  String get subscriptionSortManual;

  /// No description provided for @subscriptionSortByName.
  ///
  /// In en, this message translates to:
  /// **'By name'**
  String get subscriptionSortByName;

  /// No description provided for @subscriptionSortByUpdated.
  ///
  /// In en, this message translates to:
  /// **'By last update'**
  String get subscriptionSortByUpdated;

  /// No description provided for @subscriptionSortByServers.
  ///
  /// In en, this message translates to:
  /// **'By proxy count'**
  String get subscriptionSortByServers;

  /// No description provided for @subscriptionActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription actions'**
  String get subscriptionActionsTitle;

  /// No description provided for @subscriptionCopyUrl.
  ///
  /// In en, this message translates to:
  /// **'URL to clipboard'**
  String get subscriptionCopyUrl;

  /// No description provided for @subscriptionShowUrlQr.
  ///
  /// In en, this message translates to:
  /// **'Show URL QR code'**
  String get subscriptionShowUrlQr;

  /// No description provided for @subscriptionUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'Subscription URL copied'**
  String get subscriptionUrlCopied;

  /// No description provided for @subscriptionImportHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'How to add a subscription'**
  String get subscriptionImportHelpTitle;

  /// No description provided for @subscriptionImportHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Copy the subscription link from your provider and tap Clipboard, or scan a QR code. If the link is not recognized, open Manual and paste a URL, vless:// link, key list, or sing-box/Xray config. For Happ subscriptions, enable User-Agent or HWID in manual import when your provider requires it.'**
  String get subscriptionImportHelpBody;

  /// No description provided for @subscriptionsRefreshAllComplete.
  ///
  /// In en, this message translates to:
  /// **'Updated {updated} subscriptions, {failed} failed'**
  String subscriptionsRefreshAllComplete(int updated, int failed);

  /// No description provided for @subscriptionsRefreshAllProgress.
  ///
  /// In en, this message translates to:
  /// **'Updating {completed} of {total}'**
  String subscriptionsRefreshAllProgress(int completed, int total);

  /// No description provided for @deleteSubscription.
  ///
  /// In en, this message translates to:
  /// **'Delete subscription?'**
  String get deleteSubscription;

  /// No description provided for @deleteSubscriptionConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will remove all proxies from this subscription.'**
  String get deleteSubscriptionConfirm;

  /// No description provided for @subscriptionDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscriptionDetailsTitle;

  /// No description provided for @subscriptionMovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription moved'**
  String get subscriptionMovedTitle;

  /// No description provided for @ignoreAction.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get ignoreAction;

  /// No description provided for @updateUrlAction.
  ///
  /// In en, this message translates to:
  /// **'Update URL'**
  String get updateUrlAction;

  /// No description provided for @autoUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto update'**
  String get autoUpdateTitle;

  /// No description provided for @disableAutoUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable auto update'**
  String get disableAutoUpdateTitle;

  /// No description provided for @disabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabledLabel;

  /// No description provided for @refreshesEvery.
  ///
  /// In en, this message translates to:
  /// **'Refreshes every: {interval}'**
  String refreshesEvery(String interval);

  /// No description provided for @usageTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usageTitle;

  /// No description provided for @spentTraffic.
  ///
  /// In en, this message translates to:
  /// **'Spent {usage}'**
  String spentTraffic(String usage);

  /// No description provided for @untilDate.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String untilDate(String date);

  /// No description provided for @infoTitle.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get infoTitle;

  /// No description provided for @supportUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supportUrlLabel;

  /// No description provided for @websiteLabel.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get websiteLabel;

  /// No description provided for @newUrlTitle.
  ///
  /// In en, this message translates to:
  /// **'NewURL'**
  String get newUrlTitle;

  /// No description provided for @movedSubscriptionMessage.
  ///
  /// In en, this message translates to:
  /// **'The server reported that this subscription moved to a new URL.'**
  String get movedSubscriptionMessage;

  /// No description provided for @movedSubscriptionPrompt.
  ///
  /// In en, this message translates to:
  /// **'The server reports a new subscription URL. Update it now or keep the current one?'**
  String get movedSubscriptionPrompt;

  /// No description provided for @noSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions yet'**
  String get noSubscriptions;

  /// No description provided for @noProxies.
  ///
  /// In en, this message translates to:
  /// **'No proxies'**
  String get noProxies;

  /// No description provided for @noSubscriptionsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add a subscription URL'**
  String get noSubscriptionsHint;

  /// No description provided for @outboundsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} proxies'**
  String outboundsCount(int count);

  /// No description provided for @subscriptionServersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} proxies'**
  String subscriptionServersCount(int count);

  /// No description provided for @subscriptionReparseRecommended.
  ///
  /// In en, this message translates to:
  /// **'Reparse needed'**
  String get subscriptionReparseRecommended;

  /// No description provided for @subscriptionProxyTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Proxies'**
  String get subscriptionProxyTypeLabel;

  /// No description provided for @moreProxies.
  ///
  /// In en, this message translates to:
  /// **'…{count} more proxies'**
  String moreProxies(int count);

  /// No description provided for @lastUpdatedDateTime.
  ///
  /// In en, this message translates to:
  /// **'Updated {date} at {time}'**
  String lastUpdatedDateTime(String date, String time);

  /// No description provided for @trafficUsage.
  ///
  /// In en, this message translates to:
  /// **'{used} / {total}'**
  String trafficUsage(String used, String total);

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @invalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL'**
  String get invalidUrl;

  /// No description provided for @fetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch subscription'**
  String get fetchFailed;

  /// No description provided for @subscriptionSavedWithFetchWarning.
  ///
  /// In en, this message translates to:
  /// **'The subscription was saved, but the server did not respond. You can change HWID or headers and refresh it later.'**
  String get subscriptionSavedWithFetchWarning;

  /// No description provided for @subscriptionSavedWithFetchWarningReason.
  ///
  /// In en, this message translates to:
  /// **'The subscription was saved without servers. Reason: {reason} Fix the link, HWID, or headers, then refresh it.'**
  String subscriptionSavedWithFetchWarningReason(String reason);

  /// No description provided for @subscriptionErrorInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'The subscription link is invalid. Copy it again and make sure it starts with http:// or https://.'**
  String get subscriptionErrorInvalidUrl;

  /// No description provided for @subscriptionErrorHttpsRequired.
  ///
  /// In en, this message translates to:
  /// **'This subscription sends an HWID or credentials, so it can only be loaded over HTTPS.'**
  String get subscriptionErrorHttpsRequired;

  /// No description provided for @subscriptionErrorUnsafeRedirect.
  ///
  /// In en, this message translates to:
  /// **'The subscription server tried to redirect from HTTPS to insecure HTTP. Etonify blocked the redirect.'**
  String get subscriptionErrorUnsafeRedirect;

  /// No description provided for @subscriptionErrorRedirect.
  ///
  /// In en, this message translates to:
  /// **'The subscription link redirects incorrectly or too many times. Ask the provider for a direct link.'**
  String get subscriptionErrorRedirect;

  /// No description provided for @subscriptionErrorHttp400.
  ///
  /// In en, this message translates to:
  /// **'The server rejected the request (HTTP 400). Check the link and its parameters.'**
  String get subscriptionErrorHttp400;

  /// No description provided for @subscriptionErrorHttp401.
  ///
  /// In en, this message translates to:
  /// **'Authorization failed (HTTP 401). The token, login, or HWID may be invalid.'**
  String get subscriptionErrorHttp401;

  /// No description provided for @subscriptionErrorHttp402.
  ///
  /// In en, this message translates to:
  /// **'Payment is required (HTTP 402). Renew the subscription or contact the provider.'**
  String get subscriptionErrorHttp402;

  /// No description provided for @subscriptionErrorHttp403.
  ///
  /// In en, this message translates to:
  /// **'Access is denied (HTTP 403). The subscription may be expired, blocked, or require the correct HWID.'**
  String get subscriptionErrorHttp403;

  /// No description provided for @subscriptionErrorHttp404.
  ///
  /// In en, this message translates to:
  /// **'Subscription not found (HTTP 404). The link may have been removed or copied incorrectly.'**
  String get subscriptionErrorHttp404;

  /// No description provided for @subscriptionErrorHttp408.
  ///
  /// In en, this message translates to:
  /// **'The subscription server timed out (HTTP 408). Try again later.'**
  String get subscriptionErrorHttp408;

  /// No description provided for @subscriptionErrorHttp410.
  ///
  /// In en, this message translates to:
  /// **'The subscription has expired or was removed (HTTP 410). Request a new link from the provider.'**
  String get subscriptionErrorHttp410;

  /// No description provided for @subscriptionErrorHttp429.
  ///
  /// In en, this message translates to:
  /// **'Too many requests (HTTP 429). Wait a little before trying again.'**
  String get subscriptionErrorHttp429;

  /// No description provided for @subscriptionErrorHttp500.
  ///
  /// In en, this message translates to:
  /// **'The subscription server has an internal error (HTTP 500). This is a provider-side problem.'**
  String get subscriptionErrorHttp500;

  /// No description provided for @subscriptionErrorHttp502.
  ///
  /// In en, this message translates to:
  /// **'The subscription gateway is unavailable (HTTP 502). The provider cannot reach its upstream server right now.'**
  String get subscriptionErrorHttp502;

  /// No description provided for @subscriptionErrorHttp503.
  ///
  /// In en, this message translates to:
  /// **'The subscription service is temporarily unavailable (HTTP 503), possibly due to maintenance.'**
  String get subscriptionErrorHttp503;

  /// No description provided for @subscriptionErrorHttp504.
  ///
  /// In en, this message translates to:
  /// **'The provider\'s upstream server did not respond in time (HTTP 504). Try again later.'**
  String get subscriptionErrorHttp504;

  /// No description provided for @subscriptionErrorHttpStatus.
  ///
  /// In en, this message translates to:
  /// **'The subscription server returned HTTP {status}. Check the provider status or ask for a new link.'**
  String subscriptionErrorHttpStatus(int status);

  /// No description provided for @subscriptionErrorDns.
  ///
  /// In en, this message translates to:
  /// **'The subscription host could not be found. Check the domain, DNS, and internet connection.'**
  String get subscriptionErrorDns;

  /// No description provided for @subscriptionErrorConnection.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the subscription server. Check your internet connection or try again later.'**
  String get subscriptionErrorConnection;

  /// No description provided for @subscriptionErrorTls.
  ///
  /// In en, this message translates to:
  /// **'A secure connection to the subscription server failed. Its TLS certificate may be invalid or expired.'**
  String get subscriptionErrorTls;

  /// No description provided for @subscriptionErrorEmptyResponse.
  ///
  /// In en, this message translates to:
  /// **'The subscription server returned an empty response. The link may be expired or the provider may be having problems.'**
  String get subscriptionErrorEmptyResponse;

  /// No description provided for @subscriptionErrorHtmlResponse.
  ///
  /// In en, this message translates to:
  /// **'The server returned a web page instead of a subscription. The link may open a login or error page.'**
  String get subscriptionErrorHtmlResponse;

  /// No description provided for @subscriptionErrorResponseTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The subscription response is too large and was blocked to protect the app.'**
  String get subscriptionErrorResponseTooLarge;

  /// No description provided for @subscriptionErrorNoUsableProxies.
  ///
  /// In en, this message translates to:
  /// **'No supported proxy servers were found in the subscription. It may be empty, expired, or use an unsupported format.'**
  String get subscriptionErrorNoUsableProxies;

  /// No description provided for @subscriptionErrorInvalidContent.
  ///
  /// In en, this message translates to:
  /// **'The server response is not a valid subscription. Check that the link points directly to a subscription file.'**
  String get subscriptionErrorInvalidContent;

  /// No description provided for @subscriptionErrorHappInvalid.
  ///
  /// In en, this message translates to:
  /// **'The Happ link could not be decrypted or contains an invalid subscription URL. Copy a fresh link and try again.'**
  String get subscriptionErrorHappInvalid;

  /// No description provided for @subscriptionErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'The subscription could not be processed. Check the link and open Diagnostics for the technical reason.'**
  String get subscriptionErrorUnknown;

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get sourceLabel;

  /// No description provided for @importedFromFileLabel.
  ///
  /// In en, this message translates to:
  /// **'Imported from file: {name}'**
  String importedFromFileLabel(String name);

  /// No description provided for @deepLinkImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import subscription'**
  String get deepLinkImportTitle;

  /// No description provided for @deepLinkImportMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to import this subscription?'**
  String get deepLinkImportMessage;

  /// No description provided for @deepLinkImportNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get deepLinkImportNameLabel;

  /// No description provided for @deepLinkImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get deepLinkImportAction;

  /// No description provided for @deepLinkImportSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source link'**
  String get deepLinkImportSourceLabel;

  /// No description provided for @deepLinkImportResolvedUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Resolved subscription URL'**
  String get deepLinkImportResolvedUrlLabel;

  /// No description provided for @deepLinkImportHappBadge.
  ///
  /// In en, this message translates to:
  /// **'Happ subscription'**
  String get deepLinkImportHappBadge;

  /// No description provided for @deepLinkImportHappNotice.
  ///
  /// In en, this message translates to:
  /// **'Some Happ subscriptions require an HWID. Etonify sends it only after you confirm.'**
  String get deepLinkImportHappNotice;

  /// No description provided for @deepLinkImportHappSendHwidAction.
  ///
  /// In en, this message translates to:
  /// **'Send HWID and import'**
  String get deepLinkImportHappSendHwidAction;

  /// No description provided for @deepLinkImportHappWithoutHwidAction.
  ///
  /// In en, this message translates to:
  /// **'Import without HWID'**
  String get deepLinkImportHappWithoutHwidAction;

  /// No description provided for @deepLinkImportHappCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Do not import'**
  String get deepLinkImportHappCancelAction;

  /// No description provided for @deepLinkImportUserAgentLabel.
  ///
  /// In en, this message translates to:
  /// **'User-Agent'**
  String get deepLinkImportUserAgentLabel;

  /// No description provided for @deepLinkImportHwidLabel.
  ///
  /// In en, this message translates to:
  /// **'HWID'**
  String get deepLinkImportHwidLabel;

  /// No description provided for @deepLinkImportHwidValue.
  ///
  /// In en, this message translates to:
  /// **'Will be sent only after confirmation'**
  String get deepLinkImportHwidValue;

  /// No description provided for @deepLinkImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Subscription \"{name}\" imported'**
  String deepLinkImportSuccess(String name);

  /// No description provided for @happCryptoLinkImportedLabel.
  ///
  /// In en, this message translates to:
  /// **'Imported from a Happ link'**
  String get happCryptoLinkImportedLabel;

  /// No description provided for @happCryptoLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Happ link'**
  String get happCryptoLinkTitle;

  /// No description provided for @happCryptUnsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Happ crypt5'**
  String get happCryptUnsupportedTitle;

  /// No description provided for @happCryptUnsupportedMessage.
  ///
  /// In en, this message translates to:
  /// **'This Happ link is not supported yet.'**
  String get happCryptUnsupportedMessage;

  /// No description provided for @happImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Happ subscription'**
  String get happImportTitle;

  /// No description provided for @happImportMessage.
  ///
  /// In en, this message translates to:
  /// **'This Happ subscription may require an HWID. Send it now or try importing without it.'**
  String get happImportMessage;

  /// No description provided for @subscriptionOperationSlowWarning.
  ///
  /// In en, this message translates to:
  /// **'The subscription server is taking longer than usual. Check the link or network if this keeps happening.'**
  String get subscriptionOperationSlowWarning;

  /// No description provided for @subscriptionOperationTimeout.
  ///
  /// In en, this message translates to:
  /// **'The subscription server did not respond in time. Check the link or network and try again.'**
  String get subscriptionOperationTimeout;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @routingTitle.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get routingTitle;

  /// No description provided for @routingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Traffic routing rules'**
  String get routingSubtitle;

  /// No description provided for @bypassLocalNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Bypass local network'**
  String get bypassLocalNetworkTitle;

  /// No description provided for @bypassLocalNetworkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Route private and LAN addresses directly'**
  String get bypassLocalNetworkSubtitle;

  /// No description provided for @russiaRoutesTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart routing'**
  String get russiaRoutesTitle;

  /// No description provided for @russiaRoutesRunetFreedomBadge.
  ///
  /// In en, this message translates to:
  /// **'runetfreedom'**
  String get russiaRoutesRunetFreedomBadge;

  /// No description provided for @russiaRoutesDomainListBadge.
  ///
  /// In en, this message translates to:
  /// **'domain-list-community'**
  String get russiaRoutesDomainListBadge;

  /// No description provided for @russiaRoutesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Russian services go direct while blocked resources stay on VPN.'**
  String get russiaRoutesSubtitle;

  /// No description provided for @russiaRoutesInstallAction.
  ///
  /// In en, this message translates to:
  /// **'Download rules'**
  String get russiaRoutesInstallAction;

  /// No description provided for @russiaRoutesReinstallAction.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get russiaRoutesReinstallAction;

  /// No description provided for @russiaRoutesUpdateAction.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get russiaRoutesUpdateAction;

  /// No description provided for @russiaRoutesUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'A new rules version is available: {version}'**
  String russiaRoutesUpdateAvailable(String version);

  /// No description provided for @russiaRoutesLatest.
  ///
  /// In en, this message translates to:
  /// **'The latest rules version is installed.'**
  String get russiaRoutesLatest;

  /// No description provided for @russiaRoutesEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable smart routing'**
  String get russiaRoutesEnableTitle;

  /// No description provided for @russiaRoutesEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Apply the prepared rules to the VPN connection.'**
  String get russiaRoutesEnabledSubtitle;

  /// No description provided for @russiaRoutesMissingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The bundled database works offline and is connected when enabled.'**
  String get russiaRoutesMissingSubtitle;

  /// No description provided for @russiaRoutesPreparingStatus.
  ///
  /// In en, this message translates to:
  /// **'Updating rules...'**
  String get russiaRoutesPreparingStatus;

  /// No description provided for @russiaRoutesPreparingHint.
  ///
  /// In en, this message translates to:
  /// **'Downloading the latest database, verifying SRS files, and safely replacing local rules.'**
  String get russiaRoutesPreparingHint;

  /// No description provided for @russiaRoutesStageChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking rule version…'**
  String get russiaRoutesStageChecking;

  /// No description provided for @russiaRoutesStageDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading rule archive…'**
  String get russiaRoutesStageDownloading;

  /// No description provided for @russiaRoutesStageVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying archive integrity…'**
  String get russiaRoutesStageVerifying;

  /// No description provided for @russiaRoutesStageExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting SRS files…'**
  String get russiaRoutesStageExtracting;

  /// No description provided for @russiaRoutesStageCategories.
  ///
  /// In en, this message translates to:
  /// **'Updating service lists…'**
  String get russiaRoutesStageCategories;

  /// No description provided for @russiaRoutesStageCompiling.
  ///
  /// In en, this message translates to:
  /// **'Compiling local rules…'**
  String get russiaRoutesStageCompiling;

  /// No description provided for @russiaRoutesStageActivating.
  ///
  /// In en, this message translates to:
  /// **'Replacing rules safely…'**
  String get russiaRoutesStageActivating;

  /// No description provided for @russiaRoutesStageComplete.
  ///
  /// In en, this message translates to:
  /// **'Rules updated'**
  String get russiaRoutesStageComplete;

  /// No description provided for @russiaRoutesDownloadProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {completed} of {total}.'**
  String russiaRoutesDownloadProgress(String completed, String total);

  /// No description provided for @russiaRoutesItemsProgress.
  ///
  /// In en, this message translates to:
  /// **'Processed lists: {completed} of {total}.'**
  String russiaRoutesItemsProgress(int completed, int total);

  /// No description provided for @russiaRoutesItemsProcessed.
  ///
  /// In en, this message translates to:
  /// **'Processed lists: {completed}.'**
  String russiaRoutesItemsProcessed(int completed);

  /// No description provided for @russiaRoutesMissingStatus.
  ///
  /// In en, this message translates to:
  /// **'Rules are not installed yet'**
  String get russiaRoutesMissingStatus;

  /// No description provided for @russiaRoutesMissingHint.
  ///
  /// In en, this message translates to:
  /// **'The bundled database is connected first, then a fresh version is checked and downloaded in the background.'**
  String get russiaRoutesMissingHint;

  /// No description provided for @russiaRoutesReadyHint.
  ///
  /// In en, this message translates to:
  /// **'Rules are stored locally. New versions are checked on startup, at most once a day.'**
  String get russiaRoutesReadyHint;

  /// No description provided for @russiaRoutesReadyStatus.
  ///
  /// In en, this message translates to:
  /// **'Ready · {versionTag}'**
  String russiaRoutesReadyStatus(String versionTag);

  /// No description provided for @russiaRoutesLiveSource.
  ///
  /// In en, this message translates to:
  /// **'runetfreedom'**
  String get russiaRoutesLiveSource;

  /// No description provided for @russiaRoutesBundledSource.
  ///
  /// In en, this message translates to:
  /// **'bundled database'**
  String get russiaRoutesBundledSource;

  /// No description provided for @russiaRoutesSourceMeta.
  ///
  /// In en, this message translates to:
  /// **'Source: {source} · {verifiedAt} · files: {fileCount}'**
  String russiaRoutesSourceMeta(
    String source,
    String verifiedAt,
    int fileCount,
  );

  /// No description provided for @russiaRoutesMeta.
  ///
  /// In en, this message translates to:
  /// **'runetfreedom: {installedAt} · domain-list-community: {domainListUpdatedAt} · categories: {categoryCount} · domains: {domainCount}'**
  String russiaRoutesMeta(
    String installedAt,
    String domainListUpdatedAt,
    int categoryCount,
    int domainCount,
  );

  /// No description provided for @adBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Ad blocking'**
  String get adBlockTitle;

  /// No description provided for @adBlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The client downloads a local rule-set itself and wires it into routing.'**
  String get adBlockSubtitle;

  /// No description provided for @adBlockDownloadAction.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get adBlockDownloadAction;

  /// No description provided for @adBlockUpdateAction.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get adBlockUpdateAction;

  /// No description provided for @adBlockEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable local blocking'**
  String get adBlockEnableTitle;

  /// No description provided for @adBlockEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the downloaded local rule-set for DNS and route reject.'**
  String get adBlockEnabledSubtitle;

  /// No description provided for @adBlockMissingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download the filter package first in order to use it.'**
  String get adBlockMissingSubtitle;

  /// No description provided for @adBlockDownloadingStatus.
  ///
  /// In en, this message translates to:
  /// **'Downloading and building the local filter...'**
  String get adBlockDownloadingStatus;

  /// No description provided for @adBlockStageConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to AdGuard…'**
  String get adBlockStageConnecting;

  /// No description provided for @adBlockStageDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading the filter list…'**
  String get adBlockStageDownloading;

  /// No description provided for @adBlockStageCompiling.
  ///
  /// In en, this message translates to:
  /// **'Building the local rule set…'**
  String get adBlockStageCompiling;

  /// No description provided for @adBlockStageActivating.
  ///
  /// In en, this message translates to:
  /// **'Replacing the rule set safely…'**
  String get adBlockStageActivating;

  /// No description provided for @adBlockStageComplete.
  ///
  /// In en, this message translates to:
  /// **'Filter updated'**
  String get adBlockStageComplete;

  /// No description provided for @adBlockPreparingHint.
  ///
  /// In en, this message translates to:
  /// **'Preparing the download…'**
  String get adBlockPreparingHint;

  /// No description provided for @adBlockDownloadedProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {completed}'**
  String adBlockDownloadedProgress(String completed);

  /// No description provided for @adBlockDownloadProgress.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total}'**
  String adBlockDownloadProgress(String completed, String total);

  /// No description provided for @adBlockDownloadProgressEta.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} · about {seconds}s left'**
  String adBlockDownloadProgressEta(
    String completed,
    String total,
    int seconds,
  );

  /// No description provided for @adBlockMissingStatus.
  ///
  /// In en, this message translates to:
  /// **'Filter is not downloaded yet'**
  String get adBlockMissingStatus;

  /// No description provided for @adBlockMissingHint.
  ///
  /// In en, this message translates to:
  /// **'We download the list from AdGuard and keep it locally for sing-box.'**
  String get adBlockMissingHint;

  /// No description provided for @adBlockReadyStatus.
  ///
  /// In en, this message translates to:
  /// **'Filter is ready, domains: {blockedCount}'**
  String adBlockReadyStatus(int blockedCount);

  /// No description provided for @adBlockMeta.
  ///
  /// In en, this message translates to:
  /// **'Updated: {updatedAt} · exceptions: {allowedCount}'**
  String adBlockMeta(String updatedAt, int allowedCount);

  /// No description provided for @splitRoutingTitle.
  ///
  /// In en, this message translates to:
  /// **'Split routing'**
  String get splitRoutingTitle;

  /// No description provided for @splitRoutingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which apps use the VPN and which connect directly.'**
  String get splitRoutingSubtitle;

  /// No description provided for @splitRoutingUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Temporarily unavailable'**
  String get splitRoutingUnavailableTitle;

  /// No description provided for @splitRoutingUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Split tunneling does not work correctly right now. We are working on a fix. Follow updates.'**
  String get splitRoutingUnavailableMessage;

  /// No description provided for @splitRoutingTunOnly.
  ///
  /// In en, this message translates to:
  /// **'Available only in VPN mode. Local proxy mode cannot manage apps.'**
  String get splitRoutingTunOnly;

  /// No description provided for @splitRoutingModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get splitRoutingModeTitle;

  /// No description provided for @splitRoutingModeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get splitRoutingModeDisabled;

  /// No description provided for @splitRoutingModeDisabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Split routing is not used'**
  String get splitRoutingModeDisabledSubtitle;

  /// No description provided for @splitRoutingModeProxySelected.
  ///
  /// In en, this message translates to:
  /// **'Through VPN'**
  String get splitRoutingModeProxySelected;

  /// No description provided for @splitRoutingModeProxySelectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only selected apps use the VPN'**
  String get splitRoutingModeProxySelectedSubtitle;

  /// No description provided for @splitRoutingModeBypassSelected.
  ///
  /// In en, this message translates to:
  /// **'Outside VPN'**
  String get splitRoutingModeBypassSelected;

  /// No description provided for @splitRoutingModeBypassSelectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Selected apps connect directly'**
  String get splitRoutingModeBypassSelectedSubtitle;

  /// No description provided for @splitRoutingLockdownWarning.
  ///
  /// In en, this message translates to:
  /// **'Android Always-on VPN with \'Block connections without VPN\' can block network access for apps selected outside the VPN.'**
  String get splitRoutingLockdownWarning;

  /// No description provided for @splitRoutingAppsTitle.
  ///
  /// In en, this message translates to:
  /// **'Applications'**
  String get splitRoutingAppsTitle;

  /// No description provided for @splitRoutingAppVisibilityNotice.
  ///
  /// In en, this message translates to:
  /// **'Android gives Etonify the installed-app list only for selection. The list stays on this device.'**
  String get splitRoutingAppVisibilityNotice;

  /// No description provided for @splitRoutingPackagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Package names'**
  String get splitRoutingPackagesTitle;

  /// No description provided for @splitRoutingPackagesHint.
  ///
  /// In en, this message translates to:
  /// **'com.termux\norg.mozilla.firefox'**
  String get splitRoutingPackagesHint;

  /// No description provided for @splitRoutingPackagesHelper.
  ///
  /// In en, this message translates to:
  /// **'Package name, for example org.telegram.messenger'**
  String get splitRoutingPackagesHelper;

  /// No description provided for @splitRoutingPickAppsAction.
  ///
  /// In en, this message translates to:
  /// **'Choose apps'**
  String get splitRoutingPickAppsAction;

  /// No description provided for @splitRoutingPickAppsTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose apps'**
  String get splitRoutingPickAppsTitle;

  /// No description provided for @splitRoutingSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by app or package name'**
  String get splitRoutingSearchHint;

  /// No description provided for @splitRoutingAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'App picker is available on Android only'**
  String get splitRoutingAndroidOnly;

  /// No description provided for @splitRoutingLoadAppsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load installed apps'**
  String get splitRoutingLoadAppsFailed;

  /// No description provided for @splitRoutingSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String splitRoutingSelectedCount(int count);

  /// No description provided for @splitRoutingNoAppsTitle.
  ///
  /// In en, this message translates to:
  /// **'No apps selected yet'**
  String get splitRoutingNoAppsTitle;

  /// No description provided for @splitRoutingNoAppsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose apps for this mode'**
  String get splitRoutingNoAppsSubtitle;

  /// No description provided for @splitRoutingManualEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual package list'**
  String get splitRoutingManualEditorTitle;

  /// No description provided for @splitRoutingManualEditorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter package names manually'**
  String get splitRoutingManualEditorSubtitle;

  /// No description provided for @refreshIntervalDaysShort.
  ///
  /// In en, this message translates to:
  /// **'{count} d'**
  String refreshIntervalDaysShort(int count);

  /// No description provided for @refreshIntervalHoursShort.
  ///
  /// In en, this message translates to:
  /// **'{count} h'**
  String refreshIntervalHoursShort(int count);

  /// No description provided for @refreshIntervalMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String refreshIntervalMinutesShort(int count);

  /// No description provided for @happCrypt5Supported.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get happCrypt5Supported;

  /// No description provided for @happCrypt5Unsupported.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get happCrypt5Unsupported;

  /// No description provided for @happCrypt5Checking.
  ///
  /// In en, this message translates to:
  /// **'Checking Happ crypt5...'**
  String get happCrypt5Checking;

  /// No description provided for @happCrypt5SupportedDescription.
  ///
  /// In en, this message translates to:
  /// **'This build can open Happ crypt5 links.'**
  String get happCrypt5SupportedDescription;

  /// No description provided for @happCrypt5UnsupportedDescription.
  ///
  /// In en, this message translates to:
  /// **'This build has no Happ crypt5 files. Regular subscriptions still work.'**
  String get happCrypt5UnsupportedDescription;

  /// No description provided for @subscriptionLikelyRequiresHwidTitle.
  ///
  /// In en, this message translates to:
  /// **'HWID may be required'**
  String get subscriptionLikelyRequiresHwidTitle;

  /// No description provided for @subscriptionLikelyRequiresHwidWarning.
  ///
  /// In en, this message translates to:
  /// **'This subscription probably requires HWID. The server returned only one outbound with app/HWID in its name. Open the subscription settings and enable HWID sending.'**
  String get subscriptionLikelyRequiresHwidWarning;

  /// No description provided for @subscriptionLikelyRequiresHwidMessage.
  ///
  /// In en, this message translates to:
  /// **'The server returned only one outbound, and its name looks like a placeholder related to app or HWID.\n\nThis usually means the subscription expects the device HWID in the request.\n\nEnable HWID sending now and update the subscription again?'**
  String get subscriptionLikelyRequiresHwidMessage;

  /// No description provided for @subscriptionLikelyRequiresHwidAction.
  ///
  /// In en, this message translates to:
  /// **'Enable HWID'**
  String get subscriptionLikelyRequiresHwidAction;

  /// No description provided for @subscriptionHwidEnabledAndUpdated.
  ///
  /// In en, this message translates to:
  /// **'HWID sending enabled. The subscription was updated.'**
  String get subscriptionHwidEnabledAndUpdated;

  /// No description provided for @noValidOutboundsTitle.
  ///
  /// In en, this message translates to:
  /// **'No working nodes'**
  String get noValidOutboundsTitle;

  /// No description provided for @noValidOutboundsWarning.
  ///
  /// In en, this message translates to:
  /// **'There are no working outbounds left in this subscription. They were filtered out during validation. Check the subscription or update it.'**
  String get noValidOutboundsWarning;

  /// No description provided for @noValidOutboundsMessage.
  ///
  /// In en, this message translates to:
  /// **'This subscription does not have any working outbounds left.\n\nAll nodes were filtered out during validation before startup, so the client will not try to launch sing-box with an empty proxy set.\n\nCheck the subscription, refresh it, or import a valid one.'**
  String get noValidOutboundsMessage;

  /// No description provided for @noValidOutboundsAfterDropInvalidWarning.
  ///
  /// In en, this message translates to:
  /// **'There are no working outbounds left in the selected subscription after invalid nodes were dropped. Check the subscription, something looks wrong with it.'**
  String get noValidOutboundsAfterDropInvalidWarning;

  /// No description provided for @noValidOutboundsAfterDropInvalidMessage.
  ///
  /// In en, this message translates to:
  /// **'All remaining nodes in the selected subscription were dropped as invalid during startup.\n\nThe client stopped before handing a broken config to sing-box.\n\nCheck the subscription content and update or replace it.'**
  String get noValidOutboundsAfterDropInvalidMessage;

  /// No description provided for @experimentalTcpFastOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'TCP Fast Open'**
  String get experimentalTcpFastOpenTitle;

  /// No description provided for @experimentalTcpFastOpenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'May reduce TCP handshake time, but support depends on the network and server.'**
  String get experimentalTcpFastOpenSubtitle;

  /// No description provided for @experimentalTcpMultiPathTitle.
  ///
  /// In en, this message translates to:
  /// **'TCP Multipath'**
  String get experimentalTcpMultiPathTitle;

  /// No description provided for @experimentalTcpMultiPathSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tries multiple network paths. Can help handoff, but may heat the phone or behave unstably.'**
  String get experimentalTcpMultiPathSubtitle;

  /// No description provided for @experimentalInterruptConnectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Interrupt active connections on node change'**
  String get experimentalInterruptConnectionsTitle;

  /// No description provided for @experimentalInterruptConnectionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Applies proxy changes faster, but old app connections can be dropped.'**
  String get experimentalInterruptConnectionsSubtitle;

  /// No description provided for @experimentalUrlTestStrictToleranceTitle.
  ///
  /// In en, this message translates to:
  /// **'URLTest 1 ms tolerance'**
  String get experimentalUrlTestStrictToleranceTitle;

  /// No description provided for @experimentalUrlTestStrictToleranceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Selects the lowest-latency proxy more strictly, but may switch servers more often.'**
  String get experimentalUrlTestStrictToleranceSubtitle;

  /// No description provided for @experimentalFakeIpTitle.
  ///
  /// In en, this message translates to:
  /// **'Rewrite DNS answers (FakeIP)'**
  String get experimentalFakeIpTitle;

  /// No description provided for @experimentalFakeIpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Speeds up domain handling inside VPN TUN. Some applications may be incompatible.'**
  String get experimentalFakeIpSubtitle;

  /// No description provided for @experimentalFakeIpUnavailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Available only with VPN TUN and split routing turned off.'**
  String get experimentalFakeIpUnavailableSubtitle;

  /// No description provided for @tlsFragmentationTitle.
  ///
  /// In en, this message translates to:
  /// **'TLS fragmentation'**
  String get tlsFragmentationTitle;

  /// No description provided for @tlsFragmentationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fragments TLS handshakes for proxy outbounds. It can help with DPI, but may slow connection setup.'**
  String get tlsFragmentationSubtitle;

  /// No description provided for @tlsFragmentationModeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get tlsFragmentationModeDisabled;

  /// No description provided for @tlsFragmentationModeDisabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Does not change server TLS settings.'**
  String get tlsFragmentationModeDisabledSubtitle;

  /// No description provided for @tlsFragmentationModeRecord.
  ///
  /// In en, this message translates to:
  /// **'TLS record fragment'**
  String get tlsFragmentationModeRecord;

  /// No description provided for @tlsFragmentationModeRecordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Softer mode. Try this first.'**
  String get tlsFragmentationModeRecordSubtitle;

  /// No description provided for @tlsFragmentationModeFragment.
  ///
  /// In en, this message translates to:
  /// **'TLS fragment'**
  String get tlsFragmentationModeFragment;

  /// No description provided for @tlsFragmentationModeFragmentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'More aggressive mode with a 300 ms fallback delay.'**
  String get tlsFragmentationModeFragmentSubtitle;

  /// No description provided for @blockLeaksTitle.
  ///
  /// In en, this message translates to:
  /// **'Fix some leaks'**
  String get blockLeaksTitle;

  /// No description provided for @blockLeaksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Blocks only STUN/WebRTC traffic that may bypass the proxy'**
  String get blockLeaksSubtitle;

  /// No description provided for @addSubscriptionCaption.
  ///
  /// In en, this message translates to:
  /// **'Add a subscription from a link or file'**
  String get addSubscriptionCaption;

  /// No description provided for @pasteSubscriptionLink.
  ///
  /// In en, this message translates to:
  /// **'Paste subscription link'**
  String get pasteSubscriptionLink;

  /// No description provided for @orManually.
  ///
  /// In en, this message translates to:
  /// **'Or manually'**
  String get orManually;

  /// No description provided for @pasteAction.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get pasteAction;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @settingsMenuImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get settingsMenuImport;

  /// No description provided for @settingsMenuExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get settingsMenuExport;

  /// No description provided for @settingsResetAction.
  ///
  /// In en, this message translates to:
  /// **'Reset settings'**
  String get settingsResetAction;

  /// No description provided for @settingsResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset settings?'**
  String get settingsResetTitle;

  /// No description provided for @settingsResetMessage.
  ///
  /// In en, this message translates to:
  /// **'All client settings will return to their defaults. Subscriptions and the selected server will be kept.'**
  String get settingsResetMessage;

  /// No description provided for @settingsResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Settings reset to defaults'**
  String get settingsResetSuccess;

  /// No description provided for @backupExportSettings.
  ///
  /// In en, this message translates to:
  /// **'Export settings'**
  String get backupExportSettings;

  /// No description provided for @backupExportProfileEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Export subscriptions with password'**
  String get backupExportProfileEncrypted;

  /// No description provided for @backupExportProfilePlain.
  ///
  /// In en, this message translates to:
  /// **'Export subscriptions without encryption'**
  String get backupExportProfilePlain;

  /// No description provided for @backupPlainWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'The file will contain VPN keys'**
  String get backupPlainWarningTitle;

  /// No description provided for @backupPlainWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Plain export is readable by anyone who gets the file. Use encrypted export unless you fully trust the storage and transfer path.'**
  String get backupPlainWarningMessage;

  /// No description provided for @backupPlainImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Plain profile file'**
  String get backupPlainImportTitle;

  /// No description provided for @backupPlainImportMessage.
  ///
  /// In en, this message translates to:
  /// **'This file contains subscriptions and VPN keys without encryption. Import it only if you trust the source.'**
  String get backupPlainImportMessage;

  /// No description provided for @backupPasswordCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create export password'**
  String get backupPasswordCreateTitle;

  /// No description provided for @backupPasswordEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter profile password'**
  String get backupPasswordEnterTitle;

  /// No description provided for @backupPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get backupPasswordHint;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup file saved'**
  String get backupSaved;

  /// No description provided for @backupImported.
  ///
  /// In en, this message translates to:
  /// **'Import completed'**
  String get backupImported;

  /// No description provided for @backupUnsupportedVersion.
  ///
  /// In en, this message translates to:
  /// **'This backup format is not supported by this client version.'**
  String get backupUnsupportedVersion;

  /// No description provided for @backupNewerVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup from a newer client'**
  String get backupNewerVersionTitle;

  /// No description provided for @backupNewerVersionMessage.
  ///
  /// In en, this message translates to:
  /// **'This file was created by Etonify {version}. Some settings may not apply correctly. Continue?'**
  String backupNewerVersionMessage(String version);

  /// No description provided for @splitRoutingEmptyWhitelist.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one app or disable split tunneling before starting VPN.'**
  String get splitRoutingEmptyWhitelist;

  /// No description provided for @splitRoutingUnknownAppLabel.
  ///
  /// In en, this message translates to:
  /// **'App not found'**
  String get splitRoutingUnknownAppLabel;

  /// No description provided for @splitRoutingLoadingAppLabel.
  ///
  /// In en, this message translates to:
  /// **'Looking up app…'**
  String get splitRoutingLoadingAppLabel;

  /// No description provided for @connectionStagePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing VPN'**
  String get connectionStagePreparing;

  /// No description provided for @connectionStageConfiguring.
  ///
  /// In en, this message translates to:
  /// **'Building config'**
  String get connectionStageConfiguring;

  /// No description provided for @connectionStageStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting core'**
  String get connectionStageStarting;

  /// No description provided for @connectionStageStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping VPN'**
  String get connectionStageStopping;

  /// No description provided for @connectionStageRecovering.
  ///
  /// In en, this message translates to:
  /// **'Recovering'**
  String get connectionStageRecovering;

  /// No description provided for @connectionStageSelectingProxy.
  ///
  /// In en, this message translates to:
  /// **'Selecting server'**
  String get connectionStageSelectingProxy;

  /// No description provided for @vpnStartTimedOut.
  ///
  /// In en, this message translates to:
  /// **'VPN did not start within 15 seconds. Startup was stopped.'**
  String get vpnStartTimedOut;

  /// No description provided for @vpnStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start VPN.'**
  String get vpnStartFailed;

  /// No description provided for @trafficRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Traffic rules'**
  String get trafficRulesTitle;

  /// No description provided for @trafficRulesSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Traffic rules'**
  String get trafficRulesSettingsTitle;

  /// No description provided for @trafficRulesSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose one verified rule for domains and IP routes.'**
  String get trafficRulesSettingsSubtitle;

  /// No description provided for @trafficRulesCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Active rule'**
  String get trafficRulesCurrentLabel;

  /// No description provided for @trafficRulesNone.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get trafficRulesNone;

  /// No description provided for @trafficRulesUsePresetTitle.
  ///
  /// In en, this message translates to:
  /// **'Use traffic rules'**
  String get trafficRulesUsePresetTitle;

  /// No description provided for @trafficRulesUsePresetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a ready-made preset for domain and IP routing.'**
  String get trafficRulesUsePresetSubtitle;

  /// No description provided for @trafficRulesUsePresetAction.
  ///
  /// In en, this message translates to:
  /// **'Use preset'**
  String get trafficRulesUsePresetAction;

  /// No description provided for @trafficRulesDisablePreset.
  ///
  /// In en, this message translates to:
  /// **'Disable preset'**
  String get trafficRulesDisablePreset;

  /// No description provided for @trafficRulesQuickSelection.
  ///
  /// In en, this message translates to:
  /// **'Quick selection'**
  String get trafficRulesQuickSelection;

  /// No description provided for @trafficRulesDeveloperSection.
  ///
  /// In en, this message translates to:
  /// **'Developer rules'**
  String get trafficRulesDeveloperSection;

  /// No description provided for @trafficRulesDeveloperSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verified presets with a detailed breakdown.'**
  String get trafficRulesDeveloperSubtitle;

  /// No description provided for @trafficRulesVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get trafficRulesVerified;

  /// No description provided for @trafficRulesVerifiedInfo.
  ///
  /// In en, this message translates to:
  /// **'Verified by MeowTeam. Created by the official developer.'**
  String get trafficRulesVerifiedInfo;

  /// No description provided for @trafficRulesOnlyOne.
  ///
  /// In en, this message translates to:
  /// **'Only one traffic rule can be active at a time to avoid conflicts.'**
  String get trafficRulesOnlyOne;

  /// No description provided for @trafficRulesAvailableOffline.
  ///
  /// In en, this message translates to:
  /// **'After preparation, the rule works without an internet connection.'**
  String get trafficRulesAvailableOffline;

  /// No description provided for @trafficRulesDataReady.
  ///
  /// In en, this message translates to:
  /// **'Rule data is ready'**
  String get trafficRulesDataReady;

  /// No description provided for @trafficRulesDataMissing.
  ///
  /// In en, this message translates to:
  /// **'Rule data has not been prepared yet'**
  String get trafficRulesDataMissing;

  /// No description provided for @trafficRulesUpdateData.
  ///
  /// In en, this message translates to:
  /// **'Update rule data'**
  String get trafficRulesUpdateData;

  /// No description provided for @trafficRulesDeleteData.
  ///
  /// In en, this message translates to:
  /// **'Delete rule data'**
  String get trafficRulesDeleteData;

  /// No description provided for @trafficRulesRussianTitle.
  ///
  /// In en, this message translates to:
  /// **'.RU without VPN'**
  String get trafficRulesRussianTitle;

  /// No description provided for @trafficRulesRussianSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Russian services and local addresses bypass the VPN.'**
  String get trafficRulesRussianSubtitle;

  /// No description provided for @trafficRulesAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI services through VPN'**
  String get trafficRulesAiTitle;

  /// No description provided for @trafficRulesAiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Popular AI services are routed through the VPN; everything else is direct.'**
  String get trafficRulesAiSubtitle;

  /// No description provided for @trafficRulesSocialTitle.
  ///
  /// In en, this message translates to:
  /// **'Social networks through VPN'**
  String get trafficRulesSocialTitle;

  /// No description provided for @trafficRulesSocialSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Popular social networks and messengers are routed through the VPN; everything else is direct.'**
  String get trafficRulesSocialSubtitle;

  /// No description provided for @trafficRulesDetails.
  ///
  /// In en, this message translates to:
  /// **'Rule details'**
  String get trafficRulesDetails;

  /// No description provided for @trafficRulesDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get trafficRulesDescription;

  /// No description provided for @trafficRulesAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get trafficRulesAuthor;

  /// No description provided for @trafficRulesRoutingDomains.
  ///
  /// In en, this message translates to:
  /// **'Domain routing'**
  String get trafficRulesRoutingDomains;

  /// No description provided for @trafficRulesSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get trafficRulesSettings;

  /// No description provided for @trafficRulesRuDnsTitle.
  ///
  /// In en, this message translates to:
  /// **'DNS for .RU without VPN'**
  String get trafficRulesRuDnsTitle;

  /// No description provided for @trafficRulesRuDnsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used only for Russian domains that this rule sends directly. Default: udp://77.88.8.8.'**
  String get trafficRulesRuDnsSubtitle;

  /// No description provided for @trafficRulesDefaultRoute.
  ///
  /// In en, this message translates to:
  /// **'Everything else'**
  String get trafficRulesDefaultRoute;

  /// No description provided for @trafficRulesDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get trafficRulesDirect;

  /// No description provided for @trafficRulesVpn.
  ///
  /// In en, this message translates to:
  /// **'Through VPN'**
  String get trafficRulesVpn;

  /// No description provided for @trafficRulesIncludes.
  ///
  /// In en, this message translates to:
  /// **'Includes'**
  String get trafficRulesIncludes;

  /// No description provided for @trafficRulesLocalNetwork.
  ///
  /// In en, this message translates to:
  /// **'Local network always stays direct'**
  String get trafficRulesLocalNetwork;

  /// No description provided for @trafficRulesChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose rule'**
  String get trafficRulesChoose;

  /// No description provided for @trafficRulesChosen.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get trafficRulesChosen;

  /// No description provided for @trafficRulesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get trafficRulesDisabled;

  /// No description provided for @trafficRulesPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing rule data…'**
  String get trafficRulesPreparing;

  /// No description provided for @trafficRulesPrepareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare rule data. Check your connection and try again.'**
  String get trafficRulesPrepareFailed;

  /// No description provided for @remoteDownloadConnectTimeout.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the server within 5 seconds. Check your connection or active VPN and try again.'**
  String get remoteDownloadConnectTimeout;

  /// No description provided for @remoteDownloadResponseTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server did not start responding within 5 seconds. Check your connection or active VPN and try again.'**
  String get remoteDownloadResponseTimeout;

  /// No description provided for @remoteDownloadRetryWithoutVpn.
  ///
  /// In en, this message translates to:
  /// **'Trying without VPN'**
  String get remoteDownloadRetryWithoutVpn;

  /// No description provided for @remoteDownloadRetryWithoutVpnHint.
  ///
  /// In en, this message translates to:
  /// **'The VPN route did not respond. Retrying over Wi-Fi or mobile data.'**
  String get remoteDownloadRetryWithoutVpnHint;

  /// No description provided for @remoteDownloadIdleTimeout.
  ///
  /// In en, this message translates to:
  /// **'The download stopped because the server sent no data for 7 seconds. Try again.'**
  String get remoteDownloadIdleTimeout;

  /// No description provided for @routingRuleFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Rule files'**
  String get routingRuleFilesTitle;

  /// No description provided for @routingRuleFilesSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Rule files'**
  String get routingRuleFilesSettingsTitle;

  /// No description provided for @routingRuleFilesSettingsReady.
  ///
  /// In en, this message translates to:
  /// **'{count} files ready'**
  String routingRuleFilesSettingsReady(int count);

  /// No description provided for @routingRuleFilesSettingsPreparing.
  ///
  /// In en, this message translates to:
  /// **'Bundled files are prepared when you open this screen'**
  String get routingRuleFilesSettingsPreparing;

  /// No description provided for @routingRuleFilesReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Rule files are ready'**
  String get routingRuleFilesReadyTitle;

  /// No description provided for @routingRuleFilesReadySubtitle.
  ///
  /// In en, this message translates to:
  /// **'SRS files are stored on this device and work offline.'**
  String get routingRuleFilesReadySubtitle;

  /// No description provided for @routingRuleFilesPreparingTitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing bundled files'**
  String get routingRuleFilesPreparingTitle;

  /// No description provided for @routingRuleFilesPreparingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing local SRS files for traffic rules.'**
  String get routingRuleFilesPreparingSubtitle;

  /// No description provided for @routingRuleFilesSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get routingRuleFilesSourceTitle;

  /// No description provided for @routingRuleFilesVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get routingRuleFilesVersionTitle;

  /// No description provided for @routingRuleFilesCountTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get routingRuleFilesCountTitle;

  /// No description provided for @routingRuleFilesTotalSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Total size'**
  String get routingRuleFilesTotalSizeTitle;

  /// No description provided for @routingRuleFilesScopeTitle.
  ///
  /// In en, this message translates to:
  /// **'Russia is the current priority'**
  String get routingRuleFilesScopeTitle;

  /// No description provided for @routingRuleFilesScopeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The current set focuses on Russian networks and services. More regions will be added in future updates.'**
  String get routingRuleFilesScopeSubtitle;

  /// No description provided for @routingRuleFilesOpenSourceFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the source page. Try again.'**
  String get routingRuleFilesOpenSourceFailed;

  /// No description provided for @routingRuleFilesSourceMeta.
  ///
  /// In en, this message translates to:
  /// **'Source: {source} · version: {version} · files: {count}'**
  String routingRuleFilesSourceMeta(String source, String version, int count);

  /// No description provided for @routingRuleFilesUpdateAction.
  ///
  /// In en, this message translates to:
  /// **'Update files'**
  String get routingRuleFilesUpdateAction;

  /// No description provided for @routingRuleFilesUpdatingAction.
  ///
  /// In en, this message translates to:
  /// **'Updating files…'**
  String get routingRuleFilesUpdatingAction;

  /// No description provided for @routingRuleFilesEta.
  ///
  /// In en, this message translates to:
  /// **'About {duration} remaining'**
  String routingRuleFilesEta(String duration);

  /// No description provided for @routingRuleFilesSecondsShort.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String routingRuleFilesSecondsShort(int seconds);

  /// No description provided for @routingRuleFilesMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String routingRuleFilesMinutesShort(int minutes);

  /// No description provided for @routingRuleFilesListTitle.
  ///
  /// In en, this message translates to:
  /// **'Rule files'**
  String get routingRuleFilesListTitle;

  /// No description provided for @routingRuleFilesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Files are not ready yet'**
  String get routingRuleFilesEmptyTitle;

  /// No description provided for @routingRuleFilesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open this screen again or tap Update files.'**
  String get routingRuleFilesEmptySubtitle;

  /// No description provided for @trafficRulesRuleCount.
  ///
  /// In en, this message translates to:
  /// **'{count} categories'**
  String trafficRulesRuleCount(int count);

  /// No description provided for @coreIntegrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Core and configuration'**
  String get coreIntegrationTitle;

  /// No description provided for @coreIntegrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shows the actual bundled core and last applied configuration state, not just the switches displayed by the app.'**
  String get coreIntegrationSubtitle;

  /// No description provided for @coreApiLabel.
  ///
  /// In en, this message translates to:
  /// **'Core API'**
  String get coreApiLabel;

  /// No description provided for @coreCompatibilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Compatibility'**
  String get coreCompatibilityLabel;

  /// No description provided for @coreCompatible.
  ///
  /// In en, this message translates to:
  /// **'Compatible'**
  String get coreCompatible;

  /// No description provided for @coreIncompatible.
  ///
  /// In en, this message translates to:
  /// **'Incompatible'**
  String get coreIncompatible;

  /// No description provided for @coreConfigStateLabel.
  ///
  /// In en, this message translates to:
  /// **'Configuration state'**
  String get coreConfigStateLabel;

  /// No description provided for @coreConfigApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get coreConfigApplied;

  /// No description provided for @coreConfigValidated.
  ///
  /// In en, this message translates to:
  /// **'Validated'**
  String get coreConfigValidated;

  /// No description provided for @coreConfigFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get coreConfigFailed;

  /// No description provided for @coreConfigSuperseded.
  ///
  /// In en, this message translates to:
  /// **'Superseded'**
  String get coreConfigSuperseded;

  /// No description provided for @coreConfigNotApplied.
  ///
  /// In en, this message translates to:
  /// **'Not applied yet'**
  String get coreConfigNotApplied;

  /// No description provided for @coreConfigPending.
  ///
  /// In en, this message translates to:
  /// **'Applying…'**
  String get coreConfigPending;

  /// No description provided for @coreRuntimeStateLabel.
  ///
  /// In en, this message translates to:
  /// **'VPN state'**
  String get coreRuntimeStateLabel;

  /// No description provided for @coreRuntimeRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get coreRuntimeRunning;

  /// No description provided for @coreRuntimeStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get coreRuntimeStopped;

  /// No description provided for @coreRuntimeGenerationLabel.
  ///
  /// In en, this message translates to:
  /// **'Runtime generation'**
  String get coreRuntimeGenerationLabel;

  /// No description provided for @coreConfigSchemaLabel.
  ///
  /// In en, this message translates to:
  /// **'Configuration schema'**
  String get coreConfigSchemaLabel;

  /// No description provided for @coreLastChangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Last applied'**
  String get coreLastChangeLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
