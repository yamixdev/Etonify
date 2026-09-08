import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meow_client/core/proxy_selection_catalog.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/core_settings.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class SettingsCorePage extends StatefulWidget {
  const SettingsCorePage({
    super.key,
    required this.settings,
    required this.vpnInboundEnabled,
    required this.noticeAcknowledged,
    required this.onAcknowledgeNotice,
    required this.onApply,
    this.subscription,
  });

  final CoreSettings settings;
  final bool vpnInboundEnabled;
  final bool noticeAcknowledged;
  final Future<void> Function() onAcknowledgeNotice;
  final Future<bool> Function(CoreSettings) onApply;
  final Subscription? subscription;

  @override
  State<SettingsCorePage> createState() => _SettingsCorePageState();
}

class _SettingsCorePageState extends State<SettingsCorePage> {
  late CoreSettings _draft = widget.settings;
  late CoreSettings _baseline = widget.settings;
  bool _saving = false;
  bool _allowPop = false;
  String? _error;
  Outbound? _muxServer;
  AppLocalizations get l => AppLocalizations.of(context);
  bool get _dirty => _draft != _baseline;

  @override
  void initState() {
    super.initState();
    if (!widget.noticeAcknowledged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _notice());
    }
  }

  Future<void> _notice() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(l.coreSettingsNoticeTitle),
          content: Text(l.coreSettingsNotice),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.coreSettingsContinue),
            ),
          ],
        ),
      ),
    );
    if (mounted) await widget.onAcknowledgeNotice();
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _leave() async {
    if (_saving) return;
    if (!_dirty ||
        await _confirm(
          l.coreSettingsDiscard,
          l.coreSettingsDiscardBody,
          l.coreSettingsDiscardAction,
        )) {
      if (!mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_draft.networkStrategy == CoreNetworkStrategy.fallback &&
        _draft.networkType != CoreNetworkType.defaults &&
        _draft.networkType == _draft.fallbackNetworkType) {
      setState(() => _error = l.coreSettingsSameNetwork);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    var success = false;
    try {
      success = await widget.onApply(_draft);
    } catch (_) {
      /* Keep the draft for retry. */
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (success) {
        _baseline = _draft;
      } else {
        _error = l.coreSettingsFailed;
      }
    });
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.coreSettingsSaved)));
    }
  }

  Future<void> _reset() async {
    if (!await _confirm(
      l.coreSettingsReset,
      l.coreSettingsResetBody,
      l.coreSettingsReset,
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _draft = const CoreSettings());
    await _save();
  }

  void _set(String key, Object value) => setState(() {
    _draft = _draft.withValue(key, value);
    _error = null;
  });

  Widget _tile(
    String key,
    String title,
    String value,
    VoidCallback? onTap, {
    IconData icon = Icons.tune_rounded,
  }) => ListTile(
    key: ValueKey('core-$key'),
    enabled: onTap != null && !_saving,
    leading: SettingsLeadingIcon(
      icon: icon,
      color: Theme.of(context).colorScheme.primary,
    ),
    title: LayoutBuilder(
      builder: (context, constraints) {
        final valueText = Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        );
        if (constraints.maxWidth < 200 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(title), const SizedBox(height: 4), valueText],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: Text(title)),
            const SizedBox(width: 12),
            Flexible(
              flex: 2,
              child: Align(alignment: Alignment.centerRight, child: valueText),
            ),
          ],
        );
      },
    ),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: _saving ? null : onTap,
  );

  Future<String?> _choose(
    String title,
    String help,
    Map<String, String> choices,
    String current,
  ) => showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(help),
            const SizedBox(height: 12),
            for (final entry in choices.entries)
              ListTile(
                title: Text(entry.value),
                selected: current == entry.key,
                trailing: current == entry.key
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _choice(
    String key,
    String title,
    String help,
    Map<String, String> choices, {
    bool enabled = true,
  }) {
    final current = _draft.toMap()[key] as String;
    return _tile(
      key,
      title,
      choices[current] ?? current,
      !enabled
          ? null
          : () async {
              final value = await _choose(title, help, choices, current);
              if (value != null && mounted) _set(key, value);
            },
    );
  }

  Future<int?> _number(
    String title,
    String help,
    int current,
    int min,
    int max,
  ) async {
    var enteredValue = current;
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(help),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: '$current',
                  onSaved: (value) => enteredValue = int.parse(value!),
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(helperText: '$min … $max'),
                  validator: (value) {
                    final n = int.tryParse(value ?? '');
                    return n == null || n < min || n > max
                        ? l.coreSettingsInputRange
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(context, enteredValue);
              }
            },
            child: Text(l.coreSettingsApply),
          ),
        ],
      ),
    );
    return result;
  }

  Widget _numeric(
    String key,
    String title,
    String help,
    int max, {
    int min = 0,
    bool enabled = true,
  }) {
    final current = _draft.toMap()[key] as int;
    return _tile(
      key,
      title,
      current == 0
          ? (key == 'udpNatMax' ? l.coreSettingsAuto : l.coreSettingsDefault)
          : '$current',
      !enabled
          ? null
          : () async {
              final value = await _number(title, help, current, min, max);
              if (value != null && mounted) _set(key, value);
            },
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: settingsSectionGap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SettingsTileGroup(children: children),
      ],
    ),
  );

  Future<void> _pickMuxServer() async {
    final servers =
        ProxySelectionCatalog(
              widget.subscription?.outbounds ?? const [],
              widget.subscription?.groups ?? const [],
            ).standaloneOutbounds
            .where((o) => CoreMuxSettings.supports(o.config))
            .toList(growable: false);
    final selected = await showModalBottomSheet<Outbound>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: servers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l.coreSettingsMuxNoServer),
                  ),
                )
              : ListView.builder(
                  itemCount: servers.length,
                  itemBuilder: (context, index) {
                    final server = servers[index];
                    return ListTile(
                      title: Text(server.name),
                      subtitle: Text(server.type.toUpperCase()),
                      onTap: () => Navigator.pop(context, server),
                    );
                  },
                ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _muxServer = selected);
  }

  CoreMuxSettings get _mux =>
      _draft.multiplex[CoreMuxSettings.key(
        widget.subscription!.id,
        _muxServer!.tag,
      )] ??
      const CoreMuxSettings();
  void _setMux(CoreMuxSettings value) => setState(
    () => _draft = _draft.withMux(
      widget.subscription!.id,
      _muxServer!.tag,
      value,
    ),
  );

  List<Widget> _muxTiles() {
    final server = _muxServer;
    return [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(l.coreSettingsMuxHelp),
      ),
      _tile(
        'mux-server',
        l.coreSettingsMuxServer,
        server?.name ?? l.coreSettingsChooseServer,
        _pickMuxServer,
      ),
      if (server != null) ..._selectedMuxTiles(server),
    ];
  }

  List<Widget> _selectedMuxTiles(Outbound server) {
    final mux = _mux;
    final original = server.config['multiplex'];
    final inherited = original is Map
        ? original['enabled'] == true
              ? l.coreSettingsMuxInheritedOn
              : l.coreSettingsMuxInheritedOff
        : l.coreSettingsMuxNotSet;
    final choices = {
      'auto': l.coreSettingsAuto,
      'disabled': l.coreSettingsOff,
      'manual': l.coreSettingsManual,
    };
    final effective = mux.mode == CoreMuxMode.auto && original is Map
        ? original
        : mux.config;
    return [
      _tile(
        'mux-mode',
        l.coreSettingsMuxMode,
        mux.mode == CoreMuxMode.auto
            ? '${l.coreSettingsAuto} · $inherited'
            : choices[mux.mode.name]!,
        () async {
          final selected = await _choose(
            l.coreSettingsMuxMode,
            l.coreSettingsMuxHelp,
            choices,
            mux.mode.name,
          );
          if (selected == null || !mounted || selected == mux.mode.name) return;
          if (selected != 'auto' && (selected == 'manual' || original is Map)) {
            if (!await _confirm(
                  l.coreSettingsMuxOverrideTitle,
                  l.coreSettingsMuxOverrideBody,
                  l.coreSettingsContinue,
                ) ||
                !mounted) {
              return;
            }
          }
          _setMux(CoreMuxSettings.fromMap({...mux.toMap(), 'mode': selected}));
        },
      ),
      if (mux.mode == CoreMuxMode.manual ||
          (mux.mode == CoreMuxMode.auto &&
              original is Map &&
              original['enabled'] == true)) ...[
        _tile(
          'mux-protocol',
          l.coreSettingsMuxProtocol,
          effective['protocol']?.toString() ?? 'h2mux',
          mux.mode != CoreMuxMode.manual
              ? null
              : () async {
                  final selected = await _choose(
                    l.coreSettingsMuxProtocol,
                    l.coreSettingsMuxOverrideBody,
                    {'h2mux': 'h2mux', 'smux': 'smux', 'yamux': 'yamux'},
                    mux.protocol.name,
                  );
                  if (selected != null && mounted) {
                    _setMux(
                      CoreMuxSettings.fromMap({
                        ...mux.toMap(),
                        'protocol': selected,
                      }),
                    );
                  }
                },
        ),
        if (mux.mode == CoreMuxMode.auto &&
            original is Map &&
            original['max_connections'] != null)
          _tile(
            'mux-connections',
            l.coreSettingsMuxConnections,
            '${original['max_connections']}',
            null,
          ),
        if (mux.mode == CoreMuxMode.auto &&
            original is Map &&
            original['min_streams'] != null)
          _tile(
            'mux-min-streams',
            l.coreSettingsMuxMinStreams,
            '${original['min_streams']}',
            null,
          ),
        _tile(
          'mux-streams',
          l.coreSettingsMuxStreams,
          effective['max_streams']?.toString() ?? l.coreSettingsDefault,
          mux.mode != CoreMuxMode.manual
              ? null
              : () async {
                  final selected = await _number(
                    l.coreSettingsMuxStreams,
                    l.coreSettingsMuxStreamsHelp,
                    mux.maxStreams,
                    1,
                    128,
                  );
                  if (selected != null && mounted) {
                    _setMux(
                      CoreMuxSettings.fromMap({
                        ...mux.toMap(),
                        'maxStreams': selected,
                      }),
                    );
                  }
                },
        ),
        _tile(
          'mux-padding',
          'Padding',
          effective['padding'] == true ? l.coreSettingsOn : l.coreSettingsOff,
          mux.mode != CoreMuxMode.manual
              ? null
              : () async {
                  final selected = await _choose(
                    'Padding',
                    l.coreSettingsMuxPaddingHelp,
                    {'true': l.coreSettingsOn, 'false': l.coreSettingsOff},
                    '${mux.padding}',
                  );
                  if (selected != null && mounted) {
                    _setMux(
                      CoreMuxSettings.fromMap({
                        ...mux.toMap(),
                        'padding': selected == 'true',
                      }),
                    );
                  }
                },
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final defaults = l.coreSettingsDefault;
    final networks = {
      'defaults': l.coreSettingsAuto,
      'wifi': 'Wi-Fi',
      'cellular': l.coreSettingsCellular,
      'ethernet': 'Ethernet',
    };
    final nat = {
      for (final v in CoreNatBehavior.values)
        v.name: switch (v) {
          CoreNatBehavior.defaults => defaults,
          CoreNatBehavior.endpointIndependent => l.coreSettingsNatIndependent,
          CoreNatBehavior.addressDependent => l.coreSettingsNatAddress,
          CoreNatBehavior.addressAndPortDependent =>
            l.coreSettingsNatAddressPort,
        },
    };
    return PopScope(
      canPop: _allowPop || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: ProgressiveBlurScaffold(
        appBar: AppBar(
          title: Text(l.coreSettingsTitle),
          actions: [
            IconButton(
              key: const ValueKey('core-reset'),
              tooltip: l.coreSettingsReset,
              onPressed: _saving ? null : _reset,
              icon: const Icon(Icons.restart_alt_rounded),
            ),
          ],
        ),
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
              _section(l.coreSettingsNetwork, [
                _choice(
                  'networkStrategy',
                  l.coreSettingsStrategy,
                  l.coreSettingsStrategyHelp,
                  {
                    'defaults': defaults,
                    'hybrid': 'Hybrid',
                    'fallback': 'Fallback',
                  },
                ),
                if (_draft.networkStrategy != CoreNetworkStrategy.defaults)
                  _choice(
                    'networkType',
                    l.coreSettingsPrimaryNetwork,
                    l.coreSettingsNetworkHelp,
                    networks,
                  ),
                if (_draft.networkStrategy == CoreNetworkStrategy.fallback) ...[
                  _choice(
                    'fallbackNetworkType',
                    l.coreSettingsFallbackNetwork,
                    l.coreSettingsNetworkHelp,
                    networks,
                  ),
                  _numeric(
                    'fallbackDelayMs',
                    l.coreSettingsFallbackDelay,
                    l.coreSettingsFallbackDelayHelp,
                    30000,
                  ),
                ],
              ]),
              _section(l.coreSettingsConnections, [
                _numeric(
                  'connectTimeoutSeconds',
                  l.coreSettingsConnectTimeout,
                  l.coreSettingsConnectTimeoutHelp,
                  300,
                ),
                _choice(
                  'keepAlive',
                  'TCP Keep Alive',
                  l.coreSettingsKeepAliveHelp,
                  {
                    'defaults': defaults,
                    'disabled': l.coreSettingsOff,
                    'manual': l.coreSettingsManual,
                  },
                ),
                if (_draft.keepAlive == CoreKeepAlive.manual) ...[
                  _numeric(
                    'keepAliveSeconds',
                    l.coreSettingsKeepAlivePeriod,
                    l.coreSettingsKeepAliveHelp,
                    3600,
                    min: 1,
                  ),
                  _numeric(
                    'keepAliveIntervalSeconds',
                    l.coreSettingsKeepAliveInterval,
                    l.coreSettingsKeepAliveHelp,
                    3600,
                    min: 1,
                  ),
                ],
                _choice(
                  'udpFragment',
                  l.coreSettingsUdpFragment,
                  l.coreSettingsUdpFragmentHelp,
                  {
                    'defaults': defaults,
                    'enabled': l.coreSettingsOn,
                    'disabled': l.coreSettingsOff,
                  },
                ),
              ]),
              _section(l.coreSettingsNat, [
                if (!widget.vpnInboundEnabled)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.coreSettingsNatInactive),
                  ),
                _choice(
                  'udpMapping',
                  l.coreSettingsMapping,
                  l.coreSettingsMappingHelp,
                  nat,
                  enabled: widget.vpnInboundEnabled,
                ),
                _choice(
                  'udpFiltering',
                  l.coreSettingsFiltering,
                  l.coreSettingsFilteringHelp,
                  nat,
                  enabled: widget.vpnInboundEnabled,
                ),
                _numeric(
                  'udpNatMax',
                  l.coreSettingsNatMax,
                  l.coreSettingsNatMaxHelp,
                  65536,
                  enabled: widget.vpnInboundEnabled,
                ),
                _numeric(
                  'udpTimeoutSeconds',
                  l.coreSettingsUdpTimeout,
                  l.coreSettingsUdpTimeoutHelp,
                  3600,
                  enabled: widget.vpnInboundEnabled,
                ),
              ]),
              _section(l.coreSettingsMux, _muxTiles()),
              _section(l.coreSettingsAdvanced, [
                _numeric(
                  'tlsHandshakeTimeoutSeconds',
                  l.coreSettingsTlsTimeout,
                  l.coreSettingsTlsTimeoutHelp,
                  300,
                ),
              ]),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                key: const ValueKey('core-apply'),
                onPressed: _dirty && !_saving ? _save : null,
                child: Text(
                  _saving ? l.coreSettingsApplying : l.coreSettingsApply,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
