part of 'settings_routing_page.dart';

class SettingsSplitRoutingPage extends ConsumerStatefulWidget {
  const SettingsSplitRoutingPage({
    super.key,
    this.showResetExplanation = false,
  });
  final bool showResetExplanation;

  @override
  ConsumerState<SettingsSplitRoutingPage> createState() =>
      _SettingsSplitRoutingPageState();
}

class _SettingsSplitRoutingPageState
    extends ConsumerState<SettingsSplitRoutingPage> {
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  late bool _enabled;
  late SplitRoutingMode _mode;
  late Set<String> _included;
  late Set<String> _excluded;
  List<_InstalledApp> _apps = const [];
  List<_InstalledApp> _visible = const [];
  String _query = '';
  bool _system = false;
  bool _onlySelected = false;
  bool _loading = false;
  bool _saving = false;
  bool _dirty = false;
  bool _canPop = false;
  bool _confirming = false;
  Object? _loadError;

  Set<String> get _selected =>
      _mode == SplitRoutingMode.proxySelected ? _included : _excluded;
  bool get _available =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      ref.read(appSettingsProvider).controller.vpnInboundEnabled;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider).controller;
    _enabled = settings.splitRoutingMode != SplitRoutingMode.disabled;
    _mode = _enabled
        ? settings.splitRoutingMode
        : SplitRoutingMode.proxySelected;
    _included = settings.splitRoutingIncludedPackages.toSet();
    _excluded = settings.splitRoutingExcludedPackages.toSet();
    // Compatibility for callers restoring an active legacy state directly.
    if (_enabled && _selected.isEmpty) {
      _selected.addAll(settings.splitRoutingPackages);
    }
    final cachedApps = ref.read(installedAppsCacheProvider);
    _setApps(cachedApps);
    if (cachedApps.isEmpty &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setApps(List<Map<String, dynamic>> values) {
    final byPackage = <String, _InstalledApp>{};
    for (final value in values) {
      final app = _InstalledApp.fromMap(value);
      if (app.packageName.isNotEmpty) byPackage[app.packageName] = app;
    }
    for (final package in {..._included, ..._excluded}) {
      byPackage.putIfAbsent(
        package,
        () => _InstalledApp(
          packageName: package,
          label: '',
          system: false,
          launchable: false,
        ),
      );
    }
    _apps = byPackage.values.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    _filter();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final values = await ref
          .read(appSettingsCommandsProvider)
          .preloadInstalledApps();
      if (!mounted) return;
      setState(() => _setApps(values));
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final search = _query.isEmpty ? null : _InstalledAppSearchQuery(_query);
    final scored = <_ScoredInstalledApp>[];
    for (var i = 0; i < _apps.length; i++) {
      final app = _apps[i];
      final selected = _selected.contains(app.packageName);
      if (!_system && app.system && !selected) continue;
      if (_onlySelected && !selected) continue;
      final score = search == null
          ? 0
          : _installedAppSearchScorePrepared(app, search);
      if (score >= 0) scored.add(_ScoredInstalledApp(app, score, i));
    }
    if (search != null) {
      scored.sort((a, b) {
        final c = a.score.compareTo(b.score);
        return c == 0 ? a.index.compareTo(b.index) : c;
      });
    }
    _visible = scored.map((e) => e.app).toList(growable: false);
  }

  void _search(String value) {
    _searchTimer?.cancel();
    final next = value.trim();
    if (next.isEmpty) {
      setState(() {
        _query = '';
        _filter();
      });
    } else {
      _searchTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _query = next;
            _filter();
          });
        }
      });
    }
  }

  void _toggle(String package) {
    if (_saving) return;
    if (!_selected.contains(package) && _selected.length >= 128) {
      AppNotice.show(context, AppLocalizations.of(context).splitRoutingLimit);
      return;
    }
    setState(() {
      if (!_selected.remove(package)) _selected.add(package);
      _dirty = true;
      if (_onlySelected) _filter();
    });
  }

  Future<bool> _apply() async {
    final l10n = AppLocalizations.of(context);
    if (_saving) return false;
    if (_enabled && _selected.isEmpty) {
      AppNotice.show(
        context,
        l10n.splitRoutingEmptyWhitelist,
        tone: AppNoticeTone.error,
      );
      return false;
    }
    setState(() => _saving = true);
    try {
      final ok = await ref
          .read(appSettingsCommandsProvider)
          .applySplitRoutingSettings(
            _enabled ? _mode : SplitRoutingMode.disabled,
            _included.toList()..sort(),
            _excluded.toList()..sort(),
          );
      if (!mounted) return false;
      if (!ok) {
        AppNotice.show(
          context,
          l10n.splitRoutingApplyFailed,
          tone: AppNoticeTone.error,
        );
        return false;
      }
      setState(() => _dirty = false);
      return true;
    } catch (_) {
      if (mounted) {
        AppNotice.show(
          context,
          l10n.splitRoutingApplyFailed,
          tone: AppNoticeTone.error,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    if (_saving || _confirming) return;
    _confirming = true;
    try {
      if (_dirty) {
        final l10n = AppLocalizations.of(context);
        final choice = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l10n.splitRoutingUnsavedTitle),
            content: Text(l10n.splitRoutingUnsavedMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.splitRoutingDiscard),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(l10n.splitRoutingApply),
              ),
            ],
          ),
        );
        if (choice == null || (choice && !await _apply())) return;
      }
      if (!mounted) return;
      setState(() => _canPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } finally {
      _confirming = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final available = _available;
    final rowHeight = (72 * MediaQuery.textScalerOf(context).scale(1)).clamp(
      72.0,
      120.0,
    );
    return PopScope(
      canPop: _canPop || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.splitRoutingTitle),
          actions: [
            IconButton(
              tooltip: l10n.splitRoutingTitle,
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(l10n.splitRoutingTitle),
                  content: SingleChildScrollView(
                    child: Text(
                      '${l10n.splitRoutingResetPageMessage}\n\n${l10n.splitRoutingRulesHint}\n\n${l10n.splitRoutingLockdownWarning}\n\n${l10n.splitRoutingAppVisibilityNotice}',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: Text(l10n.continueAction),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  key: const ValueKey('split-routing-app-list'),
                  scrollCacheExtent: const ScrollCacheExtent.viewport(0.5),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          if (widget.showResetExplanation)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                l10n.splitRoutingResetPageMessage,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          SwitchListTile(
                            title: Text(l10n.splitRoutingEnabled),
                            value: _enabled,
                            onChanged: available && !_saving
                                ? (v) => setState(() {
                                    _enabled = v;
                                    _dirty = true;
                                  })
                                : null,
                          ),
                          if (!available)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                l10n.splitRoutingTunOnly,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<SplitRoutingMode>(
                                showSelectedIcon: false,
                                segments: [
                                  ButtonSegment(
                                    value: SplitRoutingMode.proxySelected,
                                    label: Text(
                                      l10n.splitRoutingModeProxySelected,
                                    ),
                                    icon: const Icon(
                                      Icons.north_east_rounded,
                                      size: 18,
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: SplitRoutingMode.bypassSelected,
                                    label: Text(
                                      l10n.splitRoutingModeBypassSelected,
                                    ),
                                    icon: const Icon(
                                      Icons.south_east_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ],
                                selected: {_mode},
                                onSelectionChanged: !_saving
                                    ? (v) => setState(() {
                                        _mode = v.single;
                                        _dirty = true;
                                        _filter();
                                      })
                                    : null,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _search,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search_rounded),
                                hintText: l10n.splitRoutingSearchHint,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _searchController.clear();
                                    _search('');
                                  },
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                FilterChip(
                                  label: Text(l10n.splitRoutingSystemApps),
                                  selected: _system,
                                  onSelected: (v) => setState(() {
                                    _system = v;
                                    _filter();
                                  }),
                                ),
                                FilterChip(
                                  label: Text(l10n.splitRoutingOnlySelected),
                                  selected: _onlySelected,
                                  onSelected: (v) => setState(() {
                                    _onlySelected = v;
                                    _filter();
                                  }),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    l10n.splitRoutingSelectedCount(
                                      _selected.length,
                                    ),
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_loading && _apps.isEmpty ||
                        _loadError != null ||
                        _visible.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _loading && _apps.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : _loadError != null
                            ? Center(
                                child: TextButton(
                                  onPressed: _load,
                                  child: Text(l10n.splitRoutingLoadAppsFailed),
                                ),
                              )
                            : _visible.isEmpty
                            ? Center(child: Text(l10n.splitRoutingNoAppsTitle))
                            : const SizedBox.shrink(),
                      )
                    else
                      SliverFixedExtentList.builder(
                        itemExtent: rowHeight,
                        itemCount: _visible.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        itemBuilder: (context, i) {
                          final app = _visible[i];
                          return ListTile(
                            key: ValueKey('split-app-${app.packageName}'),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            leading: _InstalledAppIcon(
                              packageName: app.packageName,
                              system: app.system,
                              size: 40,
                            ),
                            title: Text(
                              app.displayLabel(
                                l10n.splitRoutingUnknownAppLabel,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              app.packageName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            trailing: Checkbox(
                              value: _selected.contains(app.packageName),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              onChanged: available && !_saving
                                  ? (_) => _toggle(app.packageName)
                                  : null,
                            ),
                            onTap: available && !_saving
                                ? () => _toggle(app.packageName)
                                : null,
                          );
                        },
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('split-routing-apply'),
                    onPressed: _dirty && !_saving && available ? _apply : null,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.splitRoutingApply),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
