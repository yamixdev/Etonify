part of 'proxies_page.dart';

extension _ProxyBrowser on _ProxiesPageState {
  AppProxySummary? get _browserGroup {
    final group = _browserBaseGroup;
    if (group == null) return null;
    return widget.runtimeStates?.valueFor(group.tag)?.presentation ?? group;
  }

  String get _browserLocation => _browserPath.lastOrNull ?? '';

  void _rememberBrowserLocation() {
    _browserLocations[_browserLocation] = (
      offset: _browserScroll.hasClients ? _browserScroll.offset : 0,
      query: _browserSearch.text,
    );
  }

  void _restoreBrowserLocation() {
    _browserSearchTimer?.cancel();
    final location = _browserLocations[_browserLocation];
    _browserQuery = location?.query.trim().toLowerCase() ?? '';
    _browserSearch.text = location?.query ?? '';
    _browserPendingOffset = location?.offset ?? 0;
    _listScrollActive = false;
    _runtimeResortPending = false;
    _proxyDataRefreshPending = false;
  }

  void _restoreBrowserScrollAfterLayout() {
    if (_browserPendingOffset == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_browserScroll.hasClients || _presentationLoading) {
        return;
      }
      final offset = _browserPendingOffset;
      if (offset == null) return;
      _browserPendingOffset = null;
      _browserScroll.jumpTo(
        offset.clamp(0, _browserScroll.position.maxScrollExtent),
      );
    });
  }

  void _applyBrowserRequest() {
    final tag = widget.browserRequest?.groupTag;
    final group = widget.proxies
        .where((p) => p.tag == tag && p.isGroup)
        .firstOrNull;
    if (tag != null &&
        group == null &&
        (widget.loading || !widget.catalogReady)) {
      return;
    }
    _appliedBrowserRequest = widget.browserRequest;
    _browserPath.clear();
    _browserAncestors.clear();
    _browserBaseGroup = group;
    if (tag != null && group != null) {
      _browserPath.add(tag);
      _browserAncestors[tag] = group;
    }
    _restoreBrowserLocation();
  }

  void _validateBrowserPath() {
    if (!widget.catalogReady || widget.loading) return;
    var items = widget.proxies;
    var valid = 0;
    AppProxySummary? group;
    for (final tag in _browserPath) {
      final next = items.where((p) => p.tag == tag && p.isGroup).firstOrNull;
      if (next == null) break;
      group = next;
      _browserAncestors[tag] = next;
      valid++;
      items = widget.groupChildrenByTag[tag] ?? const [];
    }
    _browserBaseGroup = group;
    _browserAncestors.removeWhere(
      (tag, _) => !_browserPath.take(valid).contains(tag),
    );
    if (valid == _browserPath.length) return;
    _browserPath.removeRange(valid, _browserPath.length);
    _restoreBrowserLocation();
    _rebuildVisibleItems();
  }

  void _openBrowserGroup(AppProxySummary group) {
    if (_browserPath.contains(group.tag) ||
        (widget.groupChildrenByTag[group.tag]?.isEmpty ?? true)) {
      return;
    }
    FocusScope.of(context).unfocus();
    _rememberBrowserLocation();
    _updateBrowser(() {
      _browserPath.add(group.tag);
      _browserAncestors[group.tag] = group;
      _browserBaseGroup = group;
      _restoreBrowserLocation();
      _rebuildVisibleItems();
    });
  }

  void _backBrowser() {
    if (_browserPath.isEmpty) {
      widget.onBackAtRoot?.call();
      return;
    }
    FocusScope.of(context).unfocus();
    _rememberBrowserLocation();
    _updateBrowser(() {
      _browserAncestors.remove(_browserPath.removeLast());
      _browserBaseGroup = _browserAncestors[_browserPath.lastOrNull];
      _validateBrowserPath();
      _restoreBrowserLocation();
      _rebuildVisibleItems();
    });
  }

  void _searchBrowser(String value) {
    _browserSearchTimer?.cancel();
    _browserSearchTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final query = value.trim().toLowerCase();
      if (_browserQuery == query) return;
      _updateBrowser(() {
        _browserQuery = query;
        _browserPendingOffset = 0;
        _rebuildVisibleItems();
      });
    });
  }

  Widget _buildBrowser(BuildContext context, AppLocalizations l10n) {
    final group = _browserGroup;
    final entries = _visibleEntries();
    final list =
        (widget.loading || !widget.catalogReady || _presentationLoading) &&
            entries.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : entries.isEmpty
        ? Center(child: Text(l10n.subscriptionNoServersFound))
        : ListView.builder(
            key: const ValueKey('proxy-browser-list'),
            controller: _browserScroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            scrollCacheExtent: _kProxyListScrollCacheExtent,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            findChildIndexCallback: (key) => _visibleEntryIndexes[key],
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            itemCount: entries.length,
            itemBuilder: (context, index) => KeyedSubtree(
              key: entries[index].key,
              child: _buildEntry(
                context: context,
                l10n: l10n,
                entry: entries[index],
              ),
            ),
          );
    return PopScope<void>(
      canPop: !widget.browserActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.browserActive) _backBrowser();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: group == null
              ? null
              : IconButton(
                  key: const ValueKey('proxy-browser-back'),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: _backBrowser,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
          title: Text(
            group == null
                ? l10n.proxiesTitle
                : _localizedProxyTitle(l10n, group),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (widget.urlTestInFlightListenable case final inFlight?)
              ValueListenableBuilder<bool>(
                valueListenable: inFlight,
                builder: (context, running, _) =>
                    _browserTestButton(l10n, group, running),
              )
            else
              _browserTestButton(l10n, group, widget.urlTestInFlight),
            IconButton(
              tooltip: l10n.sort,
              onPressed: () => _showProxySortPicker(
                context,
                l10n: l10n,
                current: _sort,
                onSelected: _setSort,
              ),
              icon: const Icon(FluentIcons.arrow_sort_24_regular),
            ),
          ],
        ),
        body: Column(
          children: [
            if (widget.urlTestProgressListenable case final progress?)
              ValueListenableBuilder<UrlTestProgressState>(
                valueListenable: progress,
                builder: (context, value, _) => _browserStatus(l10n, value),
              )
            else if (widget.serverCount > 0)
              _browserStatus(
                l10n,
                UrlTestProgressState(total: widget.serverCount),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                key: const ValueKey('proxy-browser-search'),
                controller: _browserSearch,
                onChanged: _searchBrowser,
                decoration: InputDecoration(
                  labelText: l10n.subscriptionSearchServers,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: l10n.subscriptionClearSearch,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _browserSearch.clear();
                      _searchBrowser('');
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleProxyListScrollNotification,
                child: list,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _browserTestButton(
    AppLocalizations l10n,
    AppProxySummary? group,
    bool running,
  ) => IconButton(
    key: const ValueKey('proxy-browser-test'),
    tooltip: running ? l10n.cancel : l10n.urlTestTitle,
    onPressed:
        group != null &&
            !running &&
            (!widget.connected || widget.onProxyUrlTest == null)
        ? null
        : () => unawaited(
            running || group == null
                ? widget.onUrlTest()
                : widget.onProxyUrlTest!(group.tag),
          ),
    icon: Icon(
      running ? FluentIcons.dismiss_24_regular : FluentIcons.flash_24_regular,
    ),
  );

  Widget _browserStatus(AppLocalizations l10n, UrlTestProgressState progress) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(
        children: [
          Text(
            progress.hasResults
                ? l10n.proxiesProgressWorking(progress.working, progress.total)
                : l10n.proxiesTotal(progress.total),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (progress.isRunning && progress.showCheckProgress)
            Text(
              progress.isPaused
                  ? l10n.proxiesCheckPaused
                  : l10n.proxiesProgressTested(
                      progress.tested,
                      progress.testable,
                    ),
              style: theme.textTheme.labelSmall,
            ),
          if (progress.skipped > 0)
            Tooltip(
              message: l10n.proxiesProgressSkippedExplanation,
              child: Text(
                l10n.proxiesProgressSkipped(progress.skipped),
                style: theme.textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }
}
