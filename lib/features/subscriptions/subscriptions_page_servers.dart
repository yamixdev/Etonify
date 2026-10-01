part of 'subscriptions_page.dart';

class _SubscriptionServersPage extends StatefulWidget {
  const _SubscriptionServersPage({
    required this.subscriptionName,
    required this.outbounds,
    required this.onShare,
    required this.catalog,
    this.groupTag,
    this.ancestorTags = const {},
  });

  final String subscriptionName;
  final List<Outbound> outbounds;
  final Future<void> Function(String tag) onShare;
  final SubscriptionServerCatalog catalog;
  final String? groupTag;
  final Set<String> ancestorTags;

  @override
  State<_SubscriptionServersPage> createState() =>
      _SubscriptionServersPageState();
}

class _SubscriptionServersPageState extends State<_SubscriptionServersPage> {
  final _search = TextEditingController();
  Timer? _searchTimer;
  late final List<String> _searchIndex;
  late List<Outbound> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = _items;
    _searchIndex = [
      for (final outbound in _items) widget.catalog.searchText(outbound),
    ];
  }

  List<Outbound> get _items =>
      widget.groupTag == null ? widget.catalog.roots : widget.outbounds;

  void _open(Outbound node) {
    if (!SubscriptionServerCatalog.isGroup(node)) {
      unawaited(widget.onShare(node.tag));
      return;
    }
    final ancestors = {
      ...widget.ancestorTags,
      if (widget.groupTag != null) widget.groupTag!,
    };
    if (ancestors.contains(node.tag)) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _SubscriptionServersPage(
          subscriptionName: node.name,
          outbounds: widget.catalog.members(node.tag),
          catalog: widget.catalog,
          groupTag: node.tag,
          ancestorTags: ancestors,
          onShare: widget.onShare,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _filter(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final query = value.trim().toLowerCase();
      setState(() {
        _filtered = query.isEmpty
            ? _items
            : [
                for (var index = 0; index < _searchIndex.length; index++)
                  if (_searchIndex[index].contains(query)) _items[index],
              ];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.proxiesTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  progressiveHeaderTopPadding(context, 8),
                  16,
                  8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.subscriptionName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(8),
                    if (widget.groupTag case final tag?) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey('subscription_share_group'),
                          style: _subscriptionActionStyle(context),
                          onPressed: () => widget.onShare(tag),
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: Text(l10n.subscriptionShareGroup),
                        ),
                      ),
                      const Gap(12),
                    ],
                    TextField(
                      key: const ValueKey('subscription_server_search'),
                      controller: _search,
                      onChanged: _filter,
                      decoration: InputDecoration(
                        hintText: l10n.subscriptionSearchServers,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          tooltip: l10n.subscriptionClearSearch,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            _filter('');
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(child: Text(l10n.subscriptionNoServersFound))
                    : ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          appBottomSafePadding(context, 16),
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (_, index) {
                          final outbound = _filtered[index];
                          return _OutboundRow(
                            key: ValueKey(outbound.tag),
                            outbound: outbound,
                            memberCount:
                                SubscriptionServerCatalog.isGroup(outbound)
                                ? widget.catalog.memberCount(outbound.tag)
                                : null,
                            onTap: () => _open(outbound),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
