part of 'proxies_page.dart';

enum _ProxyListEntryType { tile, addChain, divider }

class _ProxyChainSelection {
  const _ProxyChainSelection({
    required this.detourTag,
    required this.targetTag,
  });

  final String detourTag;
  final String targetTag;
}

class _ChangeProxyChainDetourSheet extends StatelessWidget {
  const _ChangeProxyChainDetourSheet({required this.detours});

  final List<AppProxySummary> detours;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              l10n.proxyChainChangeFirstHop,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final proxy in detours)
            ListTile(
              leading: CountryFlagBadge(countryCode: proxy.countryCode),
              title: Text(
                _localizedProxyTitle(l10n, proxy),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _localizedProxyDetail(l10n, proxy),
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(context).pop(proxy.tag),
            ),
        ],
      ),
    );
  }
}

class _AddProxyChainSheet extends StatefulWidget {
  const _AddProxyChainSheet({
    required this.detours,
    required this.sources,
    required this.loadTargetsForSource,
  }) : staticTargets = const [];

  const _AddProxyChainSheet.staticTargets({
    required this.detours,
    required List<AppProxySummary> targets,
  }) : sources = const [],
       staticTargets = targets,
       loadTargetsForSource = null;

  final List<AppProxySummary> detours;
  final List<AppProfileSummary> sources;
  final List<AppProxySummary> staticTargets;
  final Future<List<AppProxySummary>> Function(String subscriptionId)?
  loadTargetsForSource;

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
      _targetTag = _targets.first.tag;
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
      _targetTag = targets.isEmpty ? null : targets.first.tag;
      _loading = false;
    });
  }

  List<AppProxySummary> _visibleTargets() {
    final query = _searchController.text.trim().toLowerCase();
    final result = <AppProxySummary>[];
    for (final proxy in _targets) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final visibleTargets = _visibleTargets();
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
              Text(l10n.proxyChainAddTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _detourTag,
                decoration: InputDecoration(
                  labelText: l10n.proxyChainFirstHopLabel,
                ),
                items: widget.detours
                    .map(
                      (proxy) => DropdownMenuItem(
                        value: proxy.tag,
                        child: Text(
                          _localizedProxyTitle(l10n, proxy),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _detourTag = value);
                  }
                },
              ),
              if (widget.sources.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _sourceId,
                  decoration: InputDecoration(
                    labelText: l10n.subscriptionsTitle,
                  ),
                  items: widget.sources
                      .map(
                        (source) => DropdownMenuItem(
                          value: source.id,
                          child: Text(
                            source.name,
                            overflow: TextOverflow.ellipsis,
                          ),
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
              Flexible(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : visibleTargets.isEmpty
                    ? Center(
                        child: Text(
                          l10n.proxyChainNothingFound,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: visibleTargets.length,
                        itemBuilder: (context, index) {
                          final proxy = visibleTargets[index];
                          final selected = proxy.tag == _targetTag;
                          return ListTile(
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
                            trailing: selected
                                ? Icon(
                                    FluentIcons.checkmark_circle_24_filled,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _targetTag == null
                    ? null
                    : () => Navigator.of(context).pop(
                        _ProxyChainSelection(
                          detourTag: _detourTag,
                          targetTag: _targetTag!,
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

class _ProxyListEntry {
  const _ProxyListEntry._(this.type, [this.proxy]);

  const _ProxyListEntry.tile(AppProxySummary proxy)
    : this._(_ProxyListEntryType.tile, proxy);
  const _ProxyListEntry.addChain() : this._(_ProxyListEntryType.addChain);
  const _ProxyListEntry.divider() : this._(_ProxyListEntryType.divider);

  final _ProxyListEntryType type;
  final AppProxySummary? proxy;

  Key get key => switch (type) {
    _ProxyListEntryType.tile => ValueKey('proxy-row-${proxy!.tag}'),
    _ProxyListEntryType.addChain => const ValueKey('proxy-add-chain-row'),
    _ProxyListEntryType.divider => const ValueKey('proxy-divider-row'),
  };
}
