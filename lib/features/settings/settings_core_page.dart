import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/core/proxy_selection_catalog.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/core_settings.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/widgets/app_bottom_sheet_surface.dart';
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

  static IconData _iconForKey(String key) => switch (key) {
    'networkStrategy' => Icons.alt_route_rounded,
    'networkType' => Icons.network_check_rounded,
    'fallbackNetworkType' => Icons.sync_alt_rounded,
    'fallbackDelayMs' => Icons.hourglass_top_rounded,
    'connectTimeoutSeconds' => Icons.timer_rounded,
    'keepAlive' => Icons.monitor_heart_rounded,
    'keepAliveSeconds' => Icons.timelapse_rounded,
    'keepAliveIntervalSeconds' => Icons.repeat_rounded,
    'udpFragment' => Icons.splitscreen_rounded,
    'udpMapping' => Icons.transform_rounded,
    'udpFiltering' => Icons.filter_alt_rounded,
    'udpNatMax' => Icons.table_rows_rounded,
    'udpTimeoutSeconds' => Icons.more_time_rounded,
    'mux-server' => Icons.dns_rounded,
    'mux-mode' => Icons.layers_rounded,
    'mux-protocol' => Icons.cable_rounded,
    'mux-connections' => Icons.multiple_stop_rounded,
    'mux-min-streams' => Icons.density_small_rounded,
    'mux-streams' => Icons.stream_rounded,
    'mux-padding' => Icons.space_bar_rounded,
    'tlsHandshakeTimeoutSeconds' => Icons.lock_clock_rounded,
    _ => Icons.tune_rounded,
  };

  Widget _tile(
    String key,
    String title,
    String value,
    VoidCallback? onTap, {
    IconData? icon,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final enabled = onTap != null && !_saving;

    final trailing = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .44,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Tooltip(
              message: value,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: enabled
                      ? cs.onSurfaceVariant
                      : cs.onSurfaceVariant.withValues(alpha: .5),
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          if (onTap != null) ...[
            const Gap(6),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: enabled
                  ? cs.onSurfaceVariant
                  : cs.onSurfaceVariant.withValues(alpha: .38),
            ),
          ],
        ],
      ),
    );

    return ListTile(
      key: ValueKey('core-$key'),
      enabled: enabled,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.fromLTRB(
        16,
        subtitle == null ? 4 : 8,
        16,
        subtitle == null ? 4 : 8,
      ),
      leading: SettingsLeadingIcon(
        icon: icon ?? _iconForKey(key),
        color: enabled ? cs.primary : cs.primary.withValues(alpha: .5),
        size: 36,
        iconSize: 18,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
      trailing: trailing,
      onTap: _saving ? null : onTap,
    );
  }

  Future<String?> _choose(
    String title,
    String help,
    Map<String, String> choices,
    String current,
  ) => showModalBottomSheet<String>(
    context: context,
    enableDrag: false,
    showDragHandle: false,
    isScrollControlled: true,
    builder: (context) => _CoreChoiceSheet(
      title: title,
      help: help,
      choices: choices,
      current: current,
    ),
  );

  Widget _choice(
    String key,
    String title,
    String help,
    Map<String, String> choices, {
    bool enabled = true,
    IconData? icon,
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
      icon: icon,
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
    IconData? icon,
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
      icon: icon,
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: settingsSectionGap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, settingsSectionLabelGap),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SettingsTileGroup(dividerIndent: 64, children: children),
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
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(
                        server.name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        server.type.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Text(
          l.coreSettingsMuxHelp,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Text(
                      l.coreSettingsNatInactive,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
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

class _CoreChoiceSheet extends StatefulWidget {
  const _CoreChoiceSheet({
    required this.title,
    required this.help,
    required this.choices,
    required this.current,
  });

  final String title;
  final String help;
  final Map<String, String> choices;
  final String current;

  @override
  State<_CoreChoiceSheet> createState() => _CoreChoiceSheetState();
}

class _CoreChoiceSheetState extends State<_CoreChoiceSheet> {
  static const _tapTravelTolerance = 8.0;

  double _downwardDrag = 0;
  Offset? _pointerStart;
  double _pointerTravel = 0;

  void _startPointer(PointerDownEvent details) {
    _pointerStart = details.position;
    _pointerTravel = 0;
  }

  void _trackPointer(PointerMoveEvent details) {
    final start = _pointerStart;
    if (start == null) return;
    final travel = (details.position - start).distance;
    if (travel > _pointerTravel) _pointerTravel = travel;
  }

  void _select(String value) {
    if (_pointerTravel > _tapTravelTolerance) return;
    Navigator.pop(context, value);
  }

  void _updateDrag(DragUpdateDetails details) {
    _downwardDrag += details.delta.dy;
    if (_downwardDrag < 0) _downwardDrag = 0;
  }

  void _finishDrag(DragEndDetails details) {
    final shouldDismiss = _downwardDrag >= appBottomSheetDragThreshold;
    _downwardDrag = 0;
    if (shouldDismiss) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Listener(
      onPointerDown: _startPointer,
      onPointerMove: _trackPointer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: _updateDrag,
        onVerticalDragEnd: _finishDrag,
        onVerticalDragCancel: () => _downwardDrag = 0,
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .85,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(child: AppBottomSheetDragHandle()),
                  const Gap(18),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Gap(10),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: .62),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Text(
                        widget.help,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                  const Gap(14),
                  Material(
                    color: cs.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: .45),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (
                            var index = 0;
                            index < widget.choices.length;
                            index++
                          ) ...[
                            if (index > 0)
                              Divider(
                                height: 1,
                                indent: 14,
                                endIndent: 14,
                                color: cs.outlineVariant.withValues(alpha: .35),
                              ),
                            Builder(
                              builder: (context) {
                                final entry = widget.choices.entries.elementAt(
                                  index,
                                );
                                final selected = entry.key == widget.current;
                                return Semantics(
                                  selected: selected,
                                  button: true,
                                  child: ListTile(
                                    key: ValueKey('core-choice-${entry.key}'),
                                    minTileHeight: 50,
                                    dense: true,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    selected: selected,
                                    selectedTileColor: cs.primaryContainer
                                        .withValues(alpha: .64),
                                    title: Text(
                                      entry.value,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: selected
                                                ? cs.onPrimaryContainer
                                                : cs.onSurface,
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                    ),
                                    trailing: selected
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 20,
                                            color: cs.primary,
                                          )
                                        : null,
                                    onTap: () => _select(entry.key),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
