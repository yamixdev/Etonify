import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/app/providers/app_dependency_providers.dart';
import 'package:meow_client/app/providers/app_settings_commands_provider.dart';
import 'package:meow_client/app/providers/app_settings_provider.dart';
import 'package:meow_client/core/formatting.dart';
import 'package:meow_client/core/network/remote_download_error_message.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/data/adblock/ad_block_rule_set_service.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/traffic_rule_preset.dart';
import 'package:meow_client/features/settings/routing_rule_files_page.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/features/settings/traffic_rules_page.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

part 'settings_split_routing_page.dart';

final _installedAppIconCache = _InstalledAppIconCache(maxEntries: 96);
final _installedAppIconLoads = <String, Future<Uint8List?>>{};
final _appSearchSeparatorsPattern = RegExp(r'[._\-]+');
final _appSearchWhitespacePattern = RegExp(r'\s+');
final _appSearchNonAlphaNumericPattern = RegExp(r'[^a-z0-9а-яё]+');

void clearInstalledAppIconCache() {
  _installedAppIconCache.clear();
  _installedAppIconLoads.clear();
}

String _trafficRulePresetTitle(
  AppLocalizations l10n,
  TrafficRulePreset preset,
) {
  return switch (preset) {
    TrafficRulePreset.none => l10n.trafficRulesNone,
    TrafficRulePreset.russianServicesDirect => l10n.trafficRulesRussianTitle,
    TrafficRulePreset.aiViaVpn => l10n.trafficRulesAiTitle,
    TrafficRulePreset.socialViaVpn => l10n.trafficRulesSocialTitle,
  };
}

class SettingsRoutingPage extends ConsumerStatefulWidget {
  const SettingsRoutingPage({super.key});

  @override
  ConsumerState<SettingsRoutingPage> createState() =>
      _SettingsRoutingPageState();
}

class _SettingsRoutingPageState extends ConsumerState<SettingsRoutingPage> {
  late final AdBlockRuleSetService _adBlockService;
  bool _adBlockBusy = false;
  bool _adBlockDeleting = false;
  AdBlockUpdateProgress? _adBlockProgress;

  @override
  void initState() {
    super.initState();
    _adBlockService = ref.read(adBlockRuleSetServiceProvider);
    _adBlockBusy = _adBlockService.isUpdating;
    _adBlockProgress = _adBlockService.progress.value;
    _adBlockService.progress.addListener(_handleAdBlockProgress);
  }

  @override
  void dispose() {
    _adBlockService.progress.removeListener(_handleAdBlockProgress);
    super.dispose();
  }

  void _handleAdBlockProgress() {
    if (!mounted) return;
    final busy = _adBlockService.isUpdating;
    setState(() {
      _adBlockBusy = busy;
      _adBlockProgress = _adBlockService.progress.value;
    });
    if (!busy) {
      unawaited(_reloadAdBlockStatus());
    }
  }

  Future<void> _reloadAdBlockStatus() async {
    final status = await _adBlockService.loadStatus();
    if (!mounted || _adBlockService.isUpdating) return;
    ref.read(adBlockStatusProvider.notifier).update(status);
  }

  void _showOperationError(Object error) {
    final l10n = AppLocalizations.of(context);
    AppNotice.show(
      context,
      remoteDownloadErrorMessage(l10n, error) ?? error.toString(),
      tone: AppNoticeTone.error,
    );
  }

  Future<void> _openTrafficRules() async {
    final commands = ref.read(appSettingsCommandsProvider);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Consumer(
          builder: (context, ref, _) {
            final liveSettings = ref.watch(appSettingsProvider).controller;
            final liveStatus = ref.watch(russiaRouteDataStatusProvider);
            return TrafficRulesPage(
              currentPreset: liveSettings.trafficRulePreset,
              currentStatus: liveStatus,
              currentRussiaDnsDirectResolver:
                  liveSettings.russiaDnsDirectResolver,
              onPrepareRuleData: commands.prepareTrafficRuleData,
              onPresetChanged: commands.setTrafficRulePreset,
              onRussiaDnsDirectResolverChanged:
                  commands.setRussiaDnsDirectResolver,
            );
          },
        ),
      ),
    );
  }

  Future<void> _openRoutingRuleFiles() async {
    final commands = ref.read(appSettingsCommandsProvider);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Consumer(
          builder: (context, ref, _) {
            final liveStatus = ref.watch(russiaRouteDataStatusProvider);
            return RoutingRuleFilesPage(
              currentStatus: liveStatus,
              onRefresh: commands.refreshRoutingRuleData,
            );
          },
        ),
      ),
    );
  }

  Future<void> _setAdBlock(bool value) async {
    final commands = ref.read(appSettingsCommandsProvider);
    final adBlockStatus = ref.read(adBlockStatusProvider);
    if (!value) {
      commands.setAdBlockEnabled(false);
      return;
    }
    if (adBlockStatus.available) {
      commands.setAdBlockEnabled(true);
      return;
    }
    await _downloadAdBlock(enableAfterDownload: true);
  }

  Future<void> _downloadAdBlock({bool enableAfterDownload = false}) async {
    if (_adBlockBusy) {
      return;
    }
    setState(() {
      _adBlockBusy = true;
    });
    try {
      final commands = ref.read(appSettingsCommandsProvider);
      final status = await commands.downloadAdBlockRuleSet();
      if (!mounted) {
        return;
      }
      ref.read(adBlockStatusProvider.notifier).update(status);
      if (enableAfterDownload && status.available) {
        commands.setAdBlockEnabled(true);
      }
    } catch (error) {
      if (mounted) {
        _showOperationError(error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _adBlockBusy = false;
        });
      }
    }
  }

  Future<void> _deleteAdBlock() async {
    if (_adBlockBusy) {
      return;
    }
    setState(() {
      _adBlockBusy = true;
      _adBlockDeleting = true;
    });
    try {
      final commands = ref.read(appSettingsCommandsProvider);
      final status = await commands.deleteAdBlockRuleSet();
      if (!mounted) {
        return;
      }
      ref.read(adBlockStatusProvider.notifier).update(status);
      commands.setAdBlockEnabled(false);
    } catch (error) {
      if (mounted) {
        _showOperationError(error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _adBlockBusy = false;
          _adBlockDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final settingsSnapshot = ref.watch(appSettingsProvider);
    final settings = settingsSnapshot.controller;
    final blockLeaks = settings.blockLeaks;
    final bypassLocalNetwork = settings.bypassLocalNetwork;
    final trafficRulePreset = settings.trafficRulePreset;
    final splitRoutingMode = settings.splitRoutingMode;
    final adBlockEnabled = settings.adBlockEnabled;

    final adBlockStatus = ref.watch(adBlockStatusProvider);
    final russiaRouteDataStatus = ref.watch(russiaRouteDataStatusProvider);
    final commands = ref.read(appSettingsCommandsProvider);

    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.routingTitle)),
      body: Theme(
        data: settingsTileTheme(context),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            settingsScreenPadding.left,
            progressiveHeaderTopPadding(context, settingsScreenPadding.top),
            settingsScreenPadding.right,
            appBottomSafePadding(context, settingsScreenPadding.bottom),
          ),
          children: [
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: SettingsLeadingIcon(
                  icon: Icons.apps_rounded,
                  color: cs.primary,
                ),
                title: Text(l10n.splitRoutingTitle),
                subtitle: Text(switch (splitRoutingMode) {
                  SplitRoutingMode.disabled => l10n.splitRoutingModeDisabled,
                  SplitRoutingMode.proxySelected =>
                    l10n.splitRoutingModeProxySelected,
                  SplitRoutingMode.bypassSelected =>
                    l10n.splitRoutingModeBypassSelected,
                }),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const SettingsSplitRoutingPage(),
                  ),
                ),
              ),
            ),
            const Gap(settingsIslandGap),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    secondary: SettingsLeadingIcon(
                      icon: Icons.shield_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(l10n.routingBlockLeaksCompact),
                    subtitle: Text(l10n.routingBlockLeaksSummary),
                    value: blockLeaks,
                    onChanged: commands.setBlockLeaks,
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    secondary: SettingsLeadingIcon(
                      icon: Icons.lan_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(l10n.bypassLocalNetworkTitle),
                    subtitle: Text(l10n.routingBypassLocalSummary),
                    value: bypassLocalNetwork,
                    onChanged: commands.setBypassLocalNetwork,
                  ),
                ],
              ),
            ),
            const Gap(settingsIslandGap),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: SettingsLeadingIcon(
                  icon: Icons.alt_route_rounded,
                  color: cs.primary,
                ),
                title: Text(l10n.trafficRulesSettingsTitle),
                subtitle: Text(
                  trafficRulePreset == TrafficRulePreset.none
                      ? l10n.trafficRulesNone
                      : _trafficRulePresetTitle(l10n, trafficRulePreset),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openTrafficRules,
              ),
            ),
            const Gap(settingsIslandGap),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: SettingsLeadingIcon(
                  icon: Icons.folder_copy_rounded,
                  color: cs.primary,
                ),
                title: Text(l10n.routingRuleFilesSettingsTitle),
                subtitle: Text(
                  russiaRouteDataStatus.available
                      ? l10n.routingRuleFilesSettingsReady(
                          russiaRouteDataStatus.verifiedFiles.length,
                        )
                      : l10n.routingRuleFilesSettingsPreparing,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openRoutingRuleFiles,
              ),
            ),
            const Gap(settingsIslandGap),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SettingsLeadingIcon(
                          icon: Icons.block_rounded,
                          color: cs.primary,
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.adBlockTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                l10n.routingAdBlockSummary,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Gap(16),
                    _AdBlockStatusPanel(
                      status: adBlockStatus,
                      busy: _adBlockBusy,
                      deleting: _adBlockDeleting,
                      progress: _adBlockProgress,
                      l10n: l10n,
                    ),
                    const Gap(12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _adBlockBusy
                                ? null
                                : () => _downloadAdBlock(
                                    enableAfterDownload:
                                        !adBlockStatus.available,
                                  ),
                            icon: _adBlockBusy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    adBlockStatus.available
                                        ? Icons.refresh_rounded
                                        : Icons.download_rounded,
                                  ),
                            label: Text(
                              _adBlockBusy && !_adBlockDeleting
                                  ? l10n.adBlockDownloadingStatus
                                  : adBlockStatus.available
                                  ? l10n.adBlockUpdateAction
                                  : l10n.adBlockDownloadAndEnableAction,
                            ),
                          ),
                        ),
                        if (adBlockStatus.available) ...[
                          const Gap(10),
                          OutlinedButton(
                            onPressed: _adBlockBusy ? null : _deleteAdBlock,
                            child: Text(l10n.delete),
                          ),
                        ],
                      ],
                    ),
                    if (adBlockStatus.available) ...[
                      const Gap(12),
                      _CompactSwitchRow(
                        icon: Icons.shield_moon_rounded,
                        title: l10n.adBlockEnableTitle,
                        subtitle: l10n.adBlockEnabledSubtitle,
                        value: adBlockEnabled,
                        onChanged: _adBlockBusy ? null : _setAdBlock,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstalledApp {
  factory _InstalledApp({
    required String packageName,
    required String label,
    required bool system,
    required bool launchable,
  }) {
    final preparedLabel = _prepareAppSearchText(label);
    final preparedPackage = _prepareAppSearchText(packageName);
    return _InstalledApp._(
      packageName: packageName,
      label: label,
      system: system,
      launchable: launchable,
      normalizedLabel: preparedLabel.normalized,
      normalizedPackage: preparedPackage.normalized,
      compactLabel: preparedLabel.compact,
      compactPackage: preparedPackage.compact,
      searchWords: List<String>.unmodifiable(<String>[
        ...preparedLabel.words,
        ...preparedPackage.words,
      ]),
      compactSearchWords: List<String>.unmodifiable(<String>[
        ...preparedLabel.compactWords,
        ...preparedPackage.compactWords,
      ]),
    );
  }

  const _InstalledApp._({
    required this.packageName,
    required this.label,
    required this.system,
    required this.launchable,
    required this.normalizedLabel,
    required this.normalizedPackage,
    required this.compactLabel,
    required this.compactPackage,
    required this.searchWords,
    required this.compactSearchWords,
  });

  final String packageName;
  final String label;
  final bool system;
  final bool launchable;
  final String normalizedLabel;
  final String normalizedPackage;
  final String compactLabel;
  final String compactPackage;
  final List<String> searchWords;
  final List<String> compactSearchWords;

  String displayLabel(String fallback) {
    final normalized = label.trim();
    if (normalized.isEmpty ||
        normalized.toLowerCase() == packageName.trim().toLowerCase()) {
      return fallback;
    }
    return normalized;
  }

  factory _InstalledApp.fromMap(Map<String, dynamic> map) {
    return _InstalledApp(
      packageName: map['packageName']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      system: map['system'] == true,
      launchable: map['launchable'] == true,
    );
  }
}

class _InstalledAppIconCache {
  _InstalledAppIconCache({required this.maxEntries});

  final int maxEntries;
  final LinkedHashMap<String, Uint8List> _entries =
      LinkedHashMap<String, Uint8List>();

  Uint8List? get(String key) {
    final value = _entries.remove(key);
    if (value == null) {
      return null;
    }
    _entries[key] = value;
    return value;
  }

  void put(String key, Uint8List value) {
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();
}

class _InstalledAppIcon extends StatefulWidget {
  const _InstalledAppIcon({
    required this.packageName,
    required this.system,
    this.size = 38,
  });

  final String packageName;
  final bool system;
  final double size;

  @override
  State<_InstalledAppIcon> createState() => _InstalledAppIconState();
}

class _InstalledAppIconState extends State<_InstalledAppIcon> {
  Uint8List? _bytes;
  int _generation = 0;
  int _pixelSize = 0;

  String get _cacheKey => '${widget.packageName}|$_pixelSize';

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPixelSize = (widget.size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(48, 96);
    if (nextPixelSize != _pixelSize) {
      _pixelSize = nextPixelSize;
      _loadIcon();
    }
  }

  @override
  void didUpdateWidget(covariant _InstalledAppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName ||
        oldWidget.size != widget.size) {
      _pixelSize = (widget.size * MediaQuery.devicePixelRatioOf(context))
          .round()
          .clamp(48, 96);
      _loadIcon();
    }
  }

  Future<void> _loadIcon() async {
    final key = _cacheKey;
    final cached = _installedAppIconCache.get(key);
    final generation = ++_generation;
    if (cached != null) {
      setState(() {
        _bytes = cached;
      });
      return;
    }
    setState(() {
      _bytes = null;
    });
    final bytes = await _loadInstalledAppIcon(
      key,
      widget.packageName,
      _pixelSize,
    );
    if (!mounted || generation != _generation) {
      return;
    }
    if (bytes != null && bytes.isNotEmpty) {
      _installedAppIconCache.put(key, bytes);
    }
    setState(() {
      _bytes = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null || bytes.isEmpty) {
      return SettingsLeadingIcon(
        icon: widget.system ? Icons.memory_rounded : Icons.android_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: widget.size,
        iconSize: 18,
      );
    }
    return SizedBox.square(
      dimension: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          bytes,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

Future<Uint8List?> _loadInstalledAppIcon(
  String key,
  String packageName,
  int sizePx,
) {
  final inFlight = _installedAppIconLoads[key];
  if (inFlight != null) {
    return inFlight;
  }
  late final Future<Uint8List?> tracked;
  tracked = SingboxRuntime.instance
      .getInstalledAppIcon(packageName, sizePx: sizePx)
      .whenComplete(() {
        if (identical(_installedAppIconLoads[key], tracked)) {
          _installedAppIconLoads.remove(key);
        }
      });
  _installedAppIconLoads[key] = tracked;
  return tracked;
}

class _ScoredInstalledApp {
  const _ScoredInstalledApp(this.app, this.score, this.index);

  final _InstalledApp app;
  final int score;
  final int index;
}

class _InstalledAppSearchQuery {
  factory _InstalledAppSearchQuery(String rawValue) {
    final prepared = _prepareAppSearchText(rawValue);
    return _InstalledAppSearchQuery._(
      normalized: prepared.normalized,
      compact: prepared.compact,
      tokens: prepared.words,
    );
  }

  const _InstalledAppSearchQuery._({
    required this.normalized,
    required this.compact,
    required this.tokens,
  });

  final String normalized;
  final String compact;
  final List<String> tokens;
}

class _PreparedAppSearchText {
  const _PreparedAppSearchText({
    required this.normalized,
    required this.compact,
    required this.words,
    required this.compactWords,
  });

  final String normalized;
  final String compact;
  final List<String> words;
  final List<String> compactWords;
}

_PreparedAppSearchText _prepareAppSearchText(String value) {
  final lowercase = value.toLowerCase();
  final normalized = lowercase
      .replaceAll(_appSearchSeparatorsPattern, ' ')
      .replaceAll(_appSearchWhitespacePattern, ' ')
      .trim();
  final words = normalized.isEmpty
      ? const <String>[]
      : List<String>.unmodifiable(normalized.split(' '));
  final compactWords = List<String>.unmodifiable(
    words
        .map((word) => word.replaceAll(_appSearchNonAlphaNumericPattern, ''))
        .where((word) => word.isNotEmpty),
  );
  return _PreparedAppSearchText(
    normalized: normalized,
    compact: lowercase.replaceAll(_appSearchNonAlphaNumericPattern, ''),
    words: words,
    compactWords: compactWords,
  );
}

int _installedAppSearchScore(_InstalledApp app, String rawQuery) {
  return _installedAppSearchScorePrepared(
    app,
    _InstalledAppSearchQuery(rawQuery),
  );
}

int _installedAppSearchScorePrepared(
  _InstalledApp app,
  _InstalledAppSearchQuery search,
) {
  final query = search.normalized;
  if (query.isEmpty) {
    return 0;
  }
  final queryCompact = search.compact;
  final label = app.normalizedLabel;
  final packageName = app.normalizedPackage;
  final labelCompact = app.compactLabel;
  final packageCompact = app.compactPackage;
  final tokens = search.tokens;
  final words = app.searchWords;

  if (label == query || packageName == query) return 0;
  if (label.startsWith(query)) return 4;
  if (packageName.startsWith(query)) return 6;
  if (label.contains(query)) return 10;
  if (packageName.contains(query)) return 12;
  if (queryCompact.isNotEmpty &&
      (labelCompact.contains(queryCompact) ||
          packageCompact.contains(queryCompact))) {
    return 14;
  }
  if (tokens.isNotEmpty && _allTokensStartWithWords(tokens, words)) {
    return 18;
  }
  if (tokens.isNotEmpty && _allTokensContained(tokens, label, packageName)) {
    return 24;
  }
  if (queryCompact.length >= 3) {
    for (final word in app.compactSearchWords) {
      if (_isCloseAppSearchMatch(queryCompact, word)) {
        return 34;
      }
    }
  }
  return -1;
}

bool _allTokensStartWithWords(List<String> tokens, List<String> words) {
  for (final token in tokens) {
    var matched = false;
    for (final word in words) {
      if (word.startsWith(token)) {
        matched = true;
        break;
      }
    }
    if (!matched) {
      return false;
    }
  }
  return true;
}

bool _allTokensContained(
  List<String> tokens,
  String label,
  String packageName,
) {
  for (final token in tokens) {
    if (!label.contains(token) && !packageName.contains(token)) {
      return false;
    }
  }
  return true;
}

@visibleForTesting
int installedAppSearchScoreForTest({
  required String label,
  required String packageName,
  required String query,
}) {
  return _installedAppSearchScore(
    _InstalledApp(
      packageName: packageName,
      label: label,
      system: false,
      launchable: true,
    ),
    query,
  );
}

bool _isCloseAppSearchMatch(String query, String compactWord) {
  if (compactWord.length < 3) {
    return false;
  }
  if (compactWord.startsWith(query) || compactWord.contains(query)) {
    return true;
  }
  final lengthDelta = (compactWord.length - query.length).abs();
  if (lengthDelta > 2) {
    return false;
  }
  return _boundedEditDistance(query, compactWord, 2) <= 2;
}

int _boundedEditDistance(String a, String b, int maxDistance) {
  if ((a.length - b.length).abs() > maxDistance) {
    return maxDistance + 1;
  }
  var previous = List<int>.generate(b.length + 1, (index) => index);
  var current = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    var rowMin = i;
    for (var j = 1; j <= b.length; j++) {
      final substitutionCost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1)
          ? 0
          : 1;
      final deletion = previous[j] + 1;
      final insertion = current[j - 1] + 1;
      final substitution = previous[j - 1] + substitutionCost;
      var value = deletion < insertion ? deletion : insertion;
      if (substitution < value) {
        value = substitution;
      }
      current[j] = value;
      if (value < rowMin) {
        rowMin = value;
      }
    }
    if (rowMin > maxDistance) {
      return maxDistance + 1;
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}

class _CompactSwitchRow extends StatelessWidget {
  const _CompactSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .72)),
      ),
      child: Row(
        children: [
          SettingsLeadingIcon(icon: icon, color: cs.primary),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Gap(8),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _AdBlockStatusPanel extends StatelessWidget {
  const _AdBlockStatusPanel({
    required this.status,
    required this.busy,
    required this.deleting,
    required this.progress,
    required this.l10n,
  });

  final AdBlockRuleSetStatus status;
  final bool busy;
  final bool deleting;
  final AdBlockUpdateProgress? progress;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final updatedAt = status.downloadedAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status.providerName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Gap(10),
          Text(
            busy
                ? deleting
                      ? l10n.adBlockDeletingStatus
                      : _stageLabel(l10n, progress?.stage)
                : status.available
                ? l10n.adBlockReadyStatus(status.blockedDomainCount)
                : l10n.adBlockMissingStatus,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!deleting) ...[
            const Gap(4),
            Text(
              busy
                  ? _progressHint(l10n, progress)
                  : status.available
                  ? l10n.adBlockMeta(
                      updatedAt == null ? '—' : formatLocalDateTime(updatedAt),
                      status.allowedDomainCount,
                    )
                  : l10n.adBlockMissingHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ],
          if (busy) ...[
            const Gap(12),
            LinearProgressIndicator(minHeight: 4, value: progress?.fraction),
          ],
        ],
      ),
    );
  }

  static String _stageLabel(AppLocalizations l10n, AdBlockUpdateStage? stage) =>
      switch (stage) {
        AdBlockUpdateStage.connecting => l10n.adBlockStageConnecting,
        AdBlockUpdateStage.retryingWithoutVpn =>
          l10n.remoteDownloadRetryWithoutVpn,
        AdBlockUpdateStage.downloading => l10n.adBlockStageDownloading,
        AdBlockUpdateStage.compiling => l10n.adBlockStageCompiling,
        AdBlockUpdateStage.activating => l10n.adBlockStageActivating,
        AdBlockUpdateStage.complete => l10n.adBlockStageComplete,
        null => l10n.adBlockDownloadingStatus,
      };

  static String _progressHint(
    AppLocalizations l10n,
    AdBlockUpdateProgress? progress,
  ) {
    if (progress == null || progress.completedBytes <= 0) {
      if (progress?.stage == AdBlockUpdateStage.retryingWithoutVpn) {
        return l10n.remoteDownloadRetryWithoutVpnHint;
      }
      return l10n.adBlockPreparingHint;
    }
    final completed = formatRuleSetBytes(progress.completedBytes);
    if (progress.totalBytes <= 0) {
      return l10n.adBlockDownloadedProgress(completed);
    }
    final total = formatRuleSetBytes(progress.totalBytes);
    final eta = progress.estimatedSecondsRemaining;
    return eta == null
        ? l10n.adBlockDownloadProgress(completed, total)
        : l10n.adBlockDownloadProgressEta(completed, total, eta);
  }
}
