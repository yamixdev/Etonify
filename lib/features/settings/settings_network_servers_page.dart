import 'package:material_ui/material_ui.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/platform/network_server_settings.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class SettingsNetworkServersPage extends StatefulWidget {
  const SettingsNetworkServersPage({super.key, required this.loadProfile});

  final Future<({String id, String name, List<Outbound> servers})?> Function()
  loadProfile;

  @override
  State<SettingsNetworkServersPage> createState() =>
      _SettingsNetworkServersPageState();
}

class _SettingsNetworkServersPageState
    extends State<SettingsNetworkServersPage> {
  String _profileId = '';
  String _profileName = '';
  List<Outbound> _servers = const [];
  Map<String, String> _names = const {};
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
      setState(() {
        _profileId = profile?.id ?? '';
        _profileName = profile?.name ?? '';
        _servers = profile?.servers ?? const [];
        _names = {for (final server in _servers) server.tag: server.name};
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

  Future<void> _update(String field, Object? value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final settings = await NetworkServerSettings.update(
        _profileId,
        field,
        value,
      );
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
      await _update(network.name, result.isEmpty ? null : result);
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
                        : (value) => _update('enabled', value),
                  ),
                  SwitchListTile(
                    title: Text(l10n.networkServersRemember),
                    subtitle: Text(l10n.networkServersRememberDescription),
                    value: settings.remember,
                    onChanged: _busy || !settings.enabled
                        ? null
                        : (value) => _update('remember', value),
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
    final name = _names[remembered] ?? _names[configured];
    return ListTile(
      key: ValueKey('network-servers-${network.name}'),
      leading: Icon(
        network == ServerNetwork.wifi
            ? Icons.wifi_rounded
            : Icons.signal_cellular_alt_rounded,
      ),
      title: Text(_networkName(l10n, network)),
      subtitle: Text(
        name ??
            (configured == null
                ? l10n.networkServersKeepCurrent
                : l10n.networkServersUnavailable),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: _busy ? null : () => _pick(network),
    );
  }
}

class _NetworkServerPicker extends StatefulWidget {
  const _NetworkServerPicker({
    required this.title,
    required this.servers,
    required this.selected,
  });

  final String title;
  final List<Outbound> servers;
  final String selected;

  @override
  State<_NetworkServerPicker> createState() => _NetworkServerPickerState();
}

class _NetworkServerPickerState extends State<_NetworkServerPicker> {
  late final _searchIndex = [
    for (final server in widget.servers)
      '${server.name} ${server.type} ${server.server}'.toLowerCase(),
  ];
  late List<Outbound> _visible = widget.servers;

  void _filter(String value) {
    final query = value.trim().toLowerCase();
    setState(() {
      _visible = query.isEmpty
          ? widget.servers
          : [
              for (var index = 0; index < _searchIndex.length; index++)
                if (_searchIndex[index].contains(query)) widget.servers[index],
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
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: l10n.subscriptionSearchServers,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
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
                    leading: Radio<String>(value: server.tag),
                    title: Text(
                      server.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(server.type.toUpperCase()),
                    onTap: () => navigator.pop(server.tag),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
