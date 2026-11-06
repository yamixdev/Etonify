part of 'proxies_page.dart';

typedef _ProxyListEntryType = ProxyListEntryType;
typedef _ProxyListEntry = ProxyListEntry;

class _ProxyChainLatency extends StatelessWidget {
  const _ProxyChainLatency({
    required this.proxy,
    required this.runtimeTag,
    required this.runtimeStates,
    required this.checkLatency,
  });

  final AppProxySummary proxy;
  final String? runtimeTag;
  final ProxyRuntimeVisualStore? runtimeStates;
  final Future<void> Function(String)? checkLatency;

  @override
  Widget build(BuildContext context) {
    final tag = runtimeTag;
    final check = checkLatency;
    Widget label(ProxyRuntimeVisualState? state) {
      if (tag != null &&
          check != null &&
          !proxy.isGroup &&
          !isSyntheticProxyTag(tag)) {
        return _ProxyLatencyAction(
          proxy: proxy,
          state: state,
          onPressed: () => unawaited(check(tag)),
        );
      }
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);
      final latency = state == null ? proxy.latency : state.latency;
      return Text(
        _proxyLatencyText(l10n, latency),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final listenable = tag == null ? null : runtimeStates?.listenableFor(tag);
    return listenable == null
        ? label(null)
        : ValueListenableBuilder<ProxyRuntimeVisualState?>(
            valueListenable: listenable,
            builder: (_, state, _) => label(state),
          );
  }
}

class _ProxyChainSelection {
  const _ProxyChainSelection({
    required this.detourTag,
    required this.targetTag,
  });

  final String detourTag;
  final String targetTag;
}

class _ChangeProxyChainDetourSheet extends StatelessWidget {
  const _ChangeProxyChainDetourSheet({
    required this.detours,
    required this.runtimeStates,
    required this.checkLatency,
  });

  final List<AppProxySummary> detours;
  final ProxyRuntimeVisualStore? runtimeStates;
  final Future<void> Function(String)? checkLatency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        itemCount: detours.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                l10n.proxyChainChangeFirstHop,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            );
          }
          final proxy = detours[index - 1];
          return ListTile(
            leading: CountryFlagBadge(countryCode: proxy.countryCode),
            title: Text(
              _localizedProxyTitle(l10n, proxy),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _localizedProxyDetail(l10n, proxy),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _ProxyChainLatency(
              proxy: proxy,
              runtimeTag: proxy.tag,
              runtimeStates: runtimeStates,
              checkLatency: checkLatency,
            ),
            onTap: () => Navigator.of(context).pop(proxy.tag),
          );
        },
      ),
    );
  }
}

class _AddProxyChainSheet extends StatefulWidget {
  const _AddProxyChainSheet({
    required this.profileId,
    required this.detours,
    required this.sources,
    required this.loadTargetsForSource,
    required this.runtimeStates,
    required this.checkLatency,
  }) : staticTargets = const [];

  const _AddProxyChainSheet.staticTargets({
    required this.profileId,
    required this.detours,
    required List<AppProxySummary> targets,
    required this.runtimeStates,
    required this.checkLatency,
  }) : sources = const [],
       staticTargets = targets,
       loadTargetsForSource = null;

  final String profileId;
  final List<AppProxySummary> detours;
  final List<AppProfileSummary> sources;
  final List<AppProxySummary> staticTargets;
  final Future<List<AppProxySummary>> Function(String subscriptionId)?
  loadTargetsForSource;
  final ProxyRuntimeVisualStore? runtimeStates;
  final Future<void> Function(String)? checkLatency;

  @override
  State<_AddProxyChainSheet> createState() => _AddProxyChainSheetState();
}

class _AddProxyChainSheetState extends State<_AddProxyChainSheet> {
  static const int _visibleTargetLimit = 160;

  late String _detourTag = widget.detours.first.tag;
  late String _sourceId = widget.sources.isEmpty ? '' : widget.sources.first.id;
  final TextEditingController _searchController = TextEditingController();
  List<AppProxySummary> _targets = const [];
  String? _targetTag;
  bool _loading = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (widget.staticTargets.isNotEmpty) {
      _targets = widget.staticTargets;
    } else {
      _loadTargets();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTargets() async {
    final loader = widget.loadTargetsForSource;
    final sourceId = _sourceId;
    if (loader == null || sourceId.isEmpty) {
      return;
    }
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _targets = const [];
      _targetTag = null;
    });
    final targets = await loader(sourceId);
    if (!mounted || generation != _loadGeneration) {
      return;
    }
    setState(() {
      _targets = targets;
      _loading = false;
    });
  }

  bool _isAvailableTarget(AppProxySummary proxy) {
    final firstHop = widget.loadTargetsForSource == null
        ? _detourTag
        : proxyChainTargetRef(widget.profileId, _detourTag);
    return proxy.tag != firstHop;
  }

  String? _targetRuntimeTag(AppProxySummary proxy) {
    if (widget.loadTargetsForSource == null) return proxy.tag;
    final prefix = proxyChainTargetRef(widget.profileId, '');
    return _sourceId == widget.profileId && proxy.tag.startsWith(prefix)
        ? proxy.tag.substring(prefix.length)
        : null;
  }

  List<AppProxySummary> _visibleTargets() {
    final query = _searchController.text.trim().toLowerCase();
    final result = <AppProxySummary>[];
    for (final proxy in _targets.where(_isAvailableTarget)) {
      if (query.isNotEmpty &&
          !proxy.displayName.toLowerCase().contains(query) &&
          !proxy.detailText.toLowerCase().contains(query) &&
          !proxy.countryCode.toLowerCase().contains(query) &&
          !proxy.server.toLowerCase().contains(query)) {
        continue;
      }
      result.add(proxy);
      if (result.length >= _visibleTargetLimit) {
        break;
      }
    }
    return result;
  }

  Widget _buildControls(
    BuildContext context,
    AppProxySummary first,
    AppProxySummary? exit,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.proxyChainAddTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(l10n.proxyChainRouteHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _detourTag,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.proxyChainFirstHopLabel,
                ),
                items: widget.detours
                    .map(
                      (proxy) => DropdownMenuItem(
                        value: proxy.tag,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _localizedProxyTitle(l10n, proxy),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _ProxyChainLatency(
                              proxy: proxy,
                              runtimeTag: proxy.tag,
                              runtimeStates: widget.runtimeStates,
                              checkLatency: null,
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
                selectedItemBuilder: (context) => [
                  for (final proxy in widget.detours)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        _localizedProxyTitle(l10n, proxy),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _detourTag = value;
                      if (exit != null && !_isAvailableTarget(exit)) {
                        _targetTag = null;
                      }
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            _ProxyChainLatency(
              proxy: first,
              runtimeTag: first.tag,
              runtimeStates: widget.runtimeStates,
              checkLatency: widget.checkLatency,
            ),
          ],
        ),
        if (widget.sources.isNotEmpty) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _sourceId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.proxyChainExitSourceLabel,
            ),
            items: widget.sources
                .map(
                  (source) => DropdownMenuItem(
                    value: source.id,
                    child: Text(source.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null || value == _sourceId) {
                return;
              }
              setState(() {
                _sourceId = value;
                _searchController.clear();
              });
              _loadTargets();
            },
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: l10n.proxyChainExitLabel,
            prefixIcon: const Icon(FluentIcons.search_24_regular),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (widget.loadTargetsForSource != null &&
            _sourceId != widget.profileId)
          Text(
            l10n.proxyChainSavedLatencyHint,
            style: theme.textTheme.bodySmall,
          )
        else if (widget.checkLatency != null)
          Text(l10n.proxyChainCheckHint, style: theme.textTheme.bodySmall),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final visibleTargets = _visibleTargets();
    final first = widget.detours.firstWhere((proxy) => proxy.tag == _detourTag);
    final exit = _targets.where((proxy) => proxy.tag == _targetTag).firstOrNull;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: CustomScrollView(
                  shrinkWrap: true,
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildControls(context, first, exit),
                    ),
                    if (_loading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (visibleTargets.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              _targets.any(_isAvailableTarget)
                                  ? l10n.proxyChainNothingFound
                                  : l10n.proxyChainNoAvailableTargets,
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: visibleTargets.length,
                        itemBuilder: (context, index) {
                          final proxy = visibleTargets[index];
                          final selected = proxy.tag == _targetTag;
                          return ListTile(
                            selected: selected,
                            onTap: () => setState(() => _targetTag = proxy.tag),
                            leading: CountryFlagBadge(
                              countryCode: proxy.countryCode,
                            ),
                            title: Text(
                              _localizedProxyTitle(l10n, proxy),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _localizedProxyDetail(l10n, proxy),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ProxyChainLatency(
                                  proxy: proxy,
                                  runtimeTag: _targetRuntimeTag(proxy),
                                  runtimeStates: widget.runtimeStates,
                                  checkLatency: widget.checkLatency,
                                ),
                                if (selected)
                                  Icon(
                                    FluentIcons.checkmark_circle_24_filled,
                                    color: theme.colorScheme.primary,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (exit != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${_localizedProxyTitle(l10n, first)} → ${_localizedProxyTitle(l10n, exit)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              FilledButton(
                onPressed: exit == null
                    ? null
                    : () => Navigator.of(context).pop(
                        _ProxyChainSelection(
                          detourTag: _detourTag,
                          targetTag: exit.tag,
                        ),
                      ),
                child: Text(l10n.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
