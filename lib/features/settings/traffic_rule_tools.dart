import 'package:gap/gap.dart';
import 'package:material_ui/material_ui.dart';
import 'package:meow_client/core/widgets/input_formatters.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/data/routing/traffic_route_inspector.dart';
import 'package:meow_client/data/routing/traffic_rule_override.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/app_loading_indicator.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class TrafficRuleOverridesPage extends StatefulWidget {
  const TrafficRuleOverridesPage({
    super.key,
    required this.rules,
    this.splitRoutingMode = SplitRoutingMode.disabled,
  });

  final List<TrafficRuleOverride> rules;
  final SplitRoutingMode splitRoutingMode;

  @override
  State<TrafficRuleOverridesPage> createState() =>
      _TrafficRuleOverridesPageState();
}

class _TrafficRuleOverridesPageState extends State<TrafficRuleOverridesPage> {
  late final _rules = List<TrafficRuleOverride>.of(widget.rules);

  Future<void> _edit([int? index]) async {
    final rule = await showModalBottomSheet<TrafficRuleOverride>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 520),
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (context) => _TrafficRuleEditor(
        initial: index == null ? null : _rules[index],
        splitRoutingMode: widget.splitRoutingMode,
        isDuplicate: (candidate) => _rules.indexed.any(
          (item) =>
              item.$1 != index &&
              item.$2.matchType == candidate.matchType &&
              item.$2.value == candidate.value,
        ),
      ),
    );
    if (!mounted || rule == null) return;
    setState(() {
      if (index == null) {
        _rules.add(rule);
      } else {
        _rules[index] = rule;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ProgressiveBlurScaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Text(
          l10n.trafficRuleOverridesTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, List.of(_rules)),
            child: Text(l10n.saveAction),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: EdgeInsets.fromLTRB(
          settingsScreenPadding.left,
          progressiveHeaderTopPadding(context, settingsScreenPadding.top),
          settingsScreenPadding.right,
          appBottomSafePadding(context, settingsScreenPadding.bottom),
        ),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.trafficRuleOverridesHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.splitRoutingMode != SplitRoutingMode.disabled) ...[
              const Gap(12),
              _SplitRoutingRuleScope(mode: widget.splitRoutingMode),
            ],
            const Gap(12),
            FilledButton.tonalIcon(
              onPressed: _edit,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.add),
            ),
            const Gap(8),
          ],
        ),
        itemCount: _rules.length,
        onReorderItem: (from, to) => setState(() {
          _rules.insert(to, _rules.removeAt(from));
        }),
        itemBuilder: (context, index) {
          final rule = _rules[index];
          final colors = theme.colorScheme;
          return Card(
            key: ObjectKey(rule),
            margin: const EdgeInsets.only(bottom: 6),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: ReorderableDragStartListener(
                index: index,
                child: const SizedBox(
                  width: 36,
                  height: 48,
                  child: Icon(Icons.drag_handle_rounded),
                ),
              ),
              title: Text(rule.value),
              subtitle: Text(
                '${_matchLabel(l10n, rule.matchType)} • '
                '${_routeLabel(l10n, rule.action)}',
              ),
              onTap: () => _edit(index),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.trafficRuleEdit,
                    onPressed: () => _edit(index),
                    icon: Icon(Icons.edit_outlined, color: colors.primary),
                  ),
                  IconButton(
                    tooltip: l10n.delete,
                    onPressed: () => setState(() => _rules.removeAt(index)),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

String _matchLabel(AppLocalizations l10n, TrafficRuleMatchType type) =>
    switch (type) {
      TrafficRuleMatchType.domain => l10n.trafficRuleExactDomain,
      TrafficRuleMatchType.domainSuffix => l10n.trafficRuleDomainSuffix,
      TrafficRuleMatchType.ipCidr => l10n.trafficRuleIpCidr,
    };

String _routeLabel(AppLocalizations l10n, TrafficRuleAction action) =>
    action == TrafficRuleAction.vpn
    ? l10n.trafficRuleViaVpn
    : l10n.trafficRuleDirect;

class _SplitRoutingRuleScope extends StatelessWidget {
  const _SplitRoutingRuleScope({required this.mode});

  final SplitRoutingMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final modeLabel = switch (mode) {
      SplitRoutingMode.proxySelected =>
        l10n.splitRoutingModeProxySelectedSubtitle,
      SplitRoutingMode.bypassSelected =>
        l10n.splitRoutingModeBypassSelectedSubtitle,
      SplitRoutingMode.disabled => l10n.splitRoutingModeDisabledSubtitle,
    };
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.alt_route_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.splitRoutingTitle,
                    style: theme.textTheme.labelLarge,
                  ),
                  Text(modeLabel),
                  Text(l10n.splitRoutingRulesHint),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficRuleEditor extends StatefulWidget {
  const _TrafficRuleEditor({
    required this.initial,
    required this.splitRoutingMode,
    required this.isDuplicate,
  });

  final TrafficRuleOverride? initial;
  final SplitRoutingMode splitRoutingMode;
  final bool Function(TrafficRuleOverride) isDuplicate;

  @override
  State<_TrafficRuleEditor> createState() => _TrafficRuleEditorState();
}

class _TrafficRuleEditorState extends State<_TrafficRuleEditor> {
  late final _value = TextEditingController(text: widget.initial?.value);
  late var _type =
      widget.initial?.matchType ?? TrafficRuleMatchType.domainSuffix;
  late var _action = widget.initial?.action ?? TrafficRuleAction.vpn;
  late var _suggestMatchType = widget.initial == null;
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _submit(AppLocalizations l10n) {
    final result = TrafficRuleOverride.tryParse(
      matchType: _type,
      value: _value.text,
      action: _action,
    );
    if (result == null || widget.isDuplicate(result)) {
      setState(() {
        _error = result == null
            ? l10n.trafficRuleInvalid
            : l10n.trafficRuleDuplicate;
      });
      return;
    }
    Navigator.pop(context, result);
  }

  void _onValueChanged(String value) {
    var type = _type;
    if (_suggestMatchType) {
      final ipRule = TrafficRuleOverride.tryParse(
        matchType: TrafficRuleMatchType.ipCidr,
        value: value,
        action: _action,
      );
      type = ipRule?.matchType ?? TrafficRuleMatchType.domainSuffix;
    }
    if (type == _type && _error == null) return;
    setState(() {
      _type = type;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.initial == null ? l10n.add : l10n.trafficRuleEdit,
                style: theme.textTheme.titleLarge,
              ),
              const Gap(14),
              TextField(
                key: const ValueKey('traffic-rule-override-value'),
                controller: _value,
                autofocus: widget.initial == null,
                autocorrect: false,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                inputFormatters: [noNewlineInputFormatter],
                onChanged: _onValueChanged,
                onSubmitted: (_) => _submit(l10n),
                decoration: InputDecoration(
                  labelText: l10n.trafficRouteTarget,
                  hintText: _type == TrafficRuleMatchType.ipCidr
                      ? '192.0.2.0/24'
                      : 'example.org',
                  errorText: _error,
                ),
              ),
              const Gap(14),
              Text(
                l10n.trafficRuleMatchType,
                style: theme.textTheme.labelLarge,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final type in TrafficRuleMatchType.values)
                    ChoiceChip(
                      label: Text(_matchLabel(l10n, type)),
                      selected: _type == type,
                      onSelected: (_) => setState(() {
                        _suggestMatchType = false;
                        _type = type;
                        _error = null;
                      }),
                    ),
                ],
              ),
              const Gap(8),
              Text(l10n.trafficRuleRoute, style: theme.textTheme.labelLarge),
              Wrap(
                spacing: 8,
                children: [
                  for (final action in const [
                    TrafficRuleAction.vpn,
                    TrafficRuleAction.direct,
                  ])
                    ChoiceChip(
                      label: Text(_routeLabel(l10n, action)),
                      selected: _action == action,
                      onSelected: (_) => setState(() => _action = action),
                    ),
                ],
              ),
              if (widget.splitRoutingMode != SplitRoutingMode.disabled) ...[
                const Gap(8),
                Text(
                  l10n.splitRoutingRulesHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const Gap(16),
              FilledButton(
                onPressed: () => _submit(l10n),
                child: Text(l10n.saveAction),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrafficRoutePreviewPage extends StatefulWidget {
  const TrafficRoutePreviewPage({
    super.key,
    required this.onInspect,
    this.splitRoutingMode = SplitRoutingMode.disabled,
  });

  final Future<TrafficRoutePreview> Function(String) onInspect;
  final SplitRoutingMode splitRoutingMode;

  @override
  State<TrafficRoutePreviewPage> createState() =>
      _TrafficRoutePreviewPageState();
}

class _TrafficRoutePreviewPageState extends State<TrafficRoutePreviewPage> {
  final _target = TextEditingController();
  TrafficRoutePreview? _result;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _inspect() async {
    final l10n = AppLocalizations.of(context);
    final target = _target.text.trim();
    if (_busy) return;
    if (target.isEmpty) {
      setState(() => _error = l10n.trafficRouteInvalidTarget);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.onInspect(target);
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is FormatException
              ? l10n.trafficRouteInvalidTarget
              : l10n.trafficRoutePreviewFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = _result;
    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.trafficRoutePreviewTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          settingsScreenPadding.left,
          progressiveHeaderTopPadding(context, settingsScreenPadding.top),
          settingsScreenPadding.right,
          appBottomSafePadding(context, settingsScreenPadding.bottom),
        ),
        children: [
          Text(l10n.trafficRoutePreviewHint),
          const Gap(12),
          TextField(
            key: const ValueKey('traffic-route-preview-target'),
            controller: _target,
            enabled: !_busy,
            autocorrect: false,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _inspect(),
            onChanged: (_) {
              if (_error != null || _result != null) {
                setState(() {
                  _error = null;
                  _result = null;
                });
              }
            },
            decoration: InputDecoration(
              labelText: l10n.trafficRouteTarget,
              hintText: 'example.org',
              errorText: _error,
            ),
          ),
          const Gap(12),
          FilledButton.icon(
            onPressed: _busy ? null : _inspect,
            icon: SizedBox.square(
              dimension: 24,
              child: _busy
                  ? AppLoadingIndicator(
                      size: 24,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )
                  : const Icon(Icons.search_rounded),
            ),
            label: Text(l10n.trafficRoutePreviewTitle),
          ),
          if (widget.splitRoutingMode != SplitRoutingMode.disabled) ...[
            const Gap(settingsIslandGap),
            _SplitRoutingRuleScope(mode: widget.splitRoutingMode),
          ],
          if (result != null) ...[
            const Gap(settingsIslandGap),
            SettingsTileGroup(
              children: [
                _RouteMatchTile(
                  title: l10n.trafficRuleRoute,
                  match: result.route,
                ),
                if (result.dns case final dns?)
                  _RouteMatchTile(title: 'DNS (A)', match: dns),
                if (result.dnsIpv6 case final dns?)
                  _RouteMatchTile(title: 'DNS (AAAA)', match: dns),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteMatchTile extends StatelessWidget {
  const _RouteMatchTile({required this.title, required this.match});

  final String title;
  final TrafficRuleMatch match;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detour = switch (match.detour) {
      'select' => l10n.trafficRuleViaVpn,
      'direct' => l10n.trafficRuleDirect,
      final tag => tag,
    };
    final value = switch (match.tag) {
      'select' => l10n.trafficRuleViaVpn,
      'direct' => l10n.trafficRuleDirect,
      'reject' => l10n.trafficRouteBlocked,
      final tag? => switch (match.resolverType) {
        'local' => l10n.trafficRouteLocalDns,
        _ => [match.resolver ?? tag, ?detour].join(' • '),
      },
      _ => l10n.trafficRouteUndetermined,
    };
    final custom = match.customRule;
    final reason = custom == null
        ? match.label
        : '${_matchLabel(l10n, custom.matchType)} · ${custom.value}';
    final rule = match.ruleIndex == null
        ? l10n.trafficRouteDefault
        : '#${match.ruleIndex! + 1} • $reason';
    return ListTile(
      title: Text(title),
      subtitle: Text(
        match.isUnknown && match.ruleIndex == null ? value : '$value\n$rule',
      ),
    );
  }
}
