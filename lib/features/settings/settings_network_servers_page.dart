import 'package:material_ui/material_ui.dart';
import 'package:meow_client/core/outbound_location.dart';
import 'package:meow_client/core/proxy_group_country.dart';
import 'package:meow_client/core/proxy_selection_catalog.dart';
import 'package:meow_client/data/subscription/location_aliases.dart';
import 'package:meow_client/data/subscription/outbound_support.dart';
import 'package:meow_client/data/subscription/subscription_store.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/platform/network_server_settings.dart';
import 'package:meow_client/widgets/country_flag_badge.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class SettingsNetworkServersPage extends StatefulWidget {
  const SettingsNetworkServersPage({super.key, required this.loadProfile});

  final Future<Subscription?> Function() loadProfile;

  @override
  State<SettingsNetworkServersPage> createState() =>
      _SettingsNetworkServersPageState();
}

class _SettingsNetworkServersPageState
    extends State<SettingsNetworkServersPage> {
  String _profileId = '';
  String _profileName = '';
  List<_NetworkServerChoice> _servers = const [];
  Map<String, _NetworkServerChoice> _serversByTag = const {};
  NetworkServerSettings? _settings;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.loadProfile();
      final settings = await NetworkServerSettings.read(profile?.id ?? '');
      if (!mounted) return;
      final servers = profile == null
          ? const <_NetworkServerChoice>[]
          : _choices(profile);
      setState(() {
        _profileId = profile?.id ?? '';
        _profileName = profile?.name ?? '';
        _servers = servers;
        _serversByTag = {
          // Existing settings can still point at an individually selected
          // member of a group.
          if (profile != null)
            for (final node in profile.outbounds)
              if ((settings.configured.containsValue(node.tag) ||
                      settings.remembered.containsValue(node.tag)) &&
                  isConcreteSubscriptionServer(node) &&
                  node.config['_excluded_by_user'] != true)
                node.tag: _NetworkServerChoice.forOutbound(
                  node,
                  profile.markAllServersRussia,
                ),
          for (final server in servers) server.tag: server,
        };
        _settings = settings;
      });
    } catch (_) {
      if (mounted) _showError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).networkServersSettingsError),
      ),
    );
  }

  Future<void> _update(Future<NetworkServerSettings> Function() save) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final settings = await save();
      if (mounted) setState(() => _settings = settings);
    } catch (_) {
      if (mounted) _showError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _networkName(AppLocalizations l10n, ServerNetwork network) =>
      switch (network) {
        ServerNetwork.wifi => l10n.networkServersWifi,
        ServerNetwork.mobile => l10n.networkServersMobile,
      };

  Future<void> _pick(ServerNetwork network) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => _NetworkServerPicker(
          title: _networkName(AppLocalizations.of(context), network),
          servers: _servers,
          selected: _settings?.configured[network] ?? '',
        ),
      ),
    );
    if (mounted && result != null) {
      await _update(
        () => NetworkServerSettings.setConfigured(
          _profileId,
          network,
          result.isEmpty ? null : result,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = _settings;
    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.networkServersTitle)),
      body: Theme(
        data: settingsTileTheme(context),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            progressiveHeaderTopPadding(context, 12),
            16,
            appBottomSafePadding(context, 24),
          ),
          children: [
            if (settings == null)
              if (_busy)
                const Center(child: CircularProgressIndicator())
              else
                OutlinedButton(
                  onPressed: () {
                    setState(() => _busy = true);
                    _load();
                  },
                  child: Text(l10n.updatesRetryAction),
                )
            else
              SettingsTileGroup(
                children: [
                  SwitchListTile(
                    title: Text(l10n.networkServersEnabled),
                    value: settings.enabled,
                    onChanged: _busy
                        ? null
                        : (value) => _update(
                            () => NetworkServerSettings.setEnabled(
                              _profileId,
                              value,
                            ),
                          ),
                  ),
                  SwitchListTile(
                    title: Text(l10n.networkServersRemember),
                    subtitle: Text(l10n.networkServersRememberDescription),
                    value: settings.remember,
                    onChanged: _busy || !settings.enabled
                        ? null
                        : (value) => _update(
                            () => NetworkServerSettings.setRemember(
                              _profileId,
                              value,
                            ),
                          ),
                  ),
                  if (_profileId.isEmpty)
                    ListTile(title: Text(l10n.noSubscriptions))
                  else
                    for (final network in ServerNetwork.values)
                      _networkTile(context, settings, network),
                ],
              ),
            if (_profileName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _profileName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _networkTile(
    BuildContext context,
    NetworkServerSettings settings,
    ServerNetwork network,
  ) {
    final l10n = AppLocalizations.of(context);
    final configured = settings.configured[network];
    final remembered = settings.remember ? settings.remembered[network] : null;
    final server = _serversByTag[remembered] ?? _serversByTag[configured];
    return ListTile(
      key: ValueKey('network-servers-${network.name}'),
      leading: Icon(
        network == ServerNetwork.wifi
            ? Icons.wifi_rounded
            : Icons.signal_cellular_alt_rounded,
      ),
      title: Text(_networkName(l10n, network)),
      subtitle: Row(
        children: [
          if (server != null && server.country.isNotEmpty) ...[
            CountryFlagBadge(countryCode: server.country, size: 24),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              server?.name ??
                  (configured == null
                      ? l10n.networkServersKeepCurrent
                      : l10n.networkServersUnavailable),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: _busy ? null : () => _pick(network),
    );
  }
}

class _NetworkServerChoice {
  const _NetworkServerChoice({
    required this.tag,
    required this.name,
    required this.type,
    required this.country,
    this.address = '',
    this.memberCount,
  });

  factory _NetworkServerChoice.forOutbound(
    Outbound node,
    bool markAllServersRussia,
  ) {
    final country = outboundDisplayCountryCode(
      node,
      markAllServersRussia: markAllServersRussia,
    );
    return _NetworkServerChoice(
      tag: node.tag,
      name: node.name,
      type: node.type,
      country: country.isEmpty
          ? SubscriptionStore.inferCountryCodeFromName(node.name) ?? ''
          : country,
      address: node.server,
    );
  }

  final String tag;
  final String name;
  final String type;
  final String country;
  final String address;
  final int? memberCount;

  String detail(AppLocalizations l10n) {
    final count = memberCount;
    if (count == null) return type.toUpperCase();
    final mode = type == 'selector'
        ? l10n.subscriptionGroupSelector
        : l10n.subscriptionGroupAutomatic;
    return '$mode · ${l10n.outboundsCount(count)}';
  }
}

List<_NetworkServerChoice> _choices(Subscription profile) {
  final excluded = {
    for (final node in profile.outbounds)
      if (node.config['_excluded_by_user'] == true) node.tag,
  };
  final visible = filterProxyDependencies(
    profile.outbounds
        .where((node) => isSupportedOutboundConfig(node.config))
        .toList(growable: false),
    profile.groups,
  );
  final concrete = concreteSubscriptionServerTags(
    visible.outbounds,
    visible.groups,
  );
  final catalog = ProxySelectionCatalog(visible.outbounds, visible.groups);
  final countries = buildProxyGroupCountryCatalog(
    visible.outbounds,
    visible.groups,
  );
  final choices = <String, _NetworkServerChoice>{};
  final groupedTags = <String>{};
  for (final group in catalog.groups) {
    final members = group.outboundTags
        .where((tag) => concrete.contains(tag) && !excluded.contains(tag))
        .toSet();
    if (members.isEmpty) continue;
    groupedTags.addAll(members);
    groupedTags.addAll(group.fallbackOutboundTags);
    final country = countries[group.tag] ?? '';
    choices[group.tag] = _NetworkServerChoice(
      tag: group.tag,
      name: group.name,
      type: group.type,
      country: profile.markAllServersRussia ? 'RU' : country,
      memberCount: members.length,
    );
  }
  for (final node in catalog.standaloneOutbounds) {
    if (!concrete.contains(node.tag) ||
        excluded.contains(node.tag) ||
        groupedTags.contains(node.tag)) {
      continue;
    }
    choices[node.tag] = _NetworkServerChoice.forOutbound(
      node,
      profile.markAllServersRussia,
    );
  }
  return [for (final tag in catalog.candidateTags) ?choices[tag]];
}

class _NetworkServerPicker extends StatefulWidget {
  const _NetworkServerPicker({
    required this.title,
    required this.servers,
    required this.selected,
  });

  final String title;
  final List<_NetworkServerChoice> servers;
  final String selected;

  @override
  State<_NetworkServerPicker> createState() => _NetworkServerPickerState();
}

class _NetworkServerPickerState extends State<_NetworkServerPicker> {
  final _search = TextEditingController();
  late final _searchIndex = [
    for (final server in widget.servers)
      '${server.name} ${server.type} ${server.address} ${server.country}'
          .toLowerCase(),
  ];
  late List<_NetworkServerChoice> _visible = widget.servers;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter(String value) {
    final query = value.trim().toLowerCase();
    final country = kLocationAliases[query];
    setState(() {
      _visible = query.isEmpty
          ? widget.servers
          : [
              for (var index = 0; index < _searchIndex.length; index++)
                if (_searchIndex[index].contains(query) ||
                    widget.servers[index].country == country)
                  widget.servers[index],
            ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              progressiveHeaderTopPadding(context, 12),
              16,
              8,
            ),
            child: TextField(
              controller: _search,
              onChanged: _filter,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.subscriptionSearchServers,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.subscriptionClearSearch,
                        onPressed: () {
                          _search.clear();
                          _filter('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: RadioGroup<String>(
                groupValue: widget.selected,
                onChanged: (tag) => navigator.pop(tag),
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    appBottomSafePadding(context, 16),
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: _visible.isEmpty ? 2 : _visible.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        dense: true,
                        leading: const Radio<String>(value: ''),
                        title: Text(l10n.networkServersKeepCurrent),
                        onTap: () => navigator.pop(''),
                      );
                    }
                    if (_visible.isEmpty) {
                      return ListTile(
                        title: Text(l10n.subscriptionNoServersFound),
                      );
                    }
                    final server = _visible[index - 1];
                    return ListTile(
                      dense: true,
                      leading: CountryFlagBadge(
                        countryCode: server.country,
                        size: 36,
                      ),
                      title: Text(
                        server.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(server.detail(l10n)),
                      trailing: Radio<String>(value: server.tag),
                      onTap: () => navigator.pop(server.tag),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
