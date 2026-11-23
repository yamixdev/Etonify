import 'package:gap/gap.dart';
import 'package:material_ui/material_ui.dart';
import 'package:meow_client/data/routing/traffic_route_inspector.dart';
import 'package:meow_client/data/routing/traffic_rule_override.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class TrafficRuleOverridesPage extends StatefulWidget {
  const TrafficRuleOverridesPage({super.key, required this.rules});

  final List<TrafficRuleOverride> rules;

  @override
  State<TrafficRuleOverridesPage> createState() =>
      _TrafficRuleOverridesPageState();
}

class _TrafficRuleOverridesPageState extends State<TrafficRuleOverridesPage> {
  late final _rules = List<TrafficRuleOverride>.of(widget.rules);

  Future<void> _edit([int? index]) async {
    final rule = await showDialog<TrafficRuleOverride>(
      context: context,
      builder: (context) => _TrafficRuleEditor(
        initial: index == null ? null : _rules[index],
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
    return ProgressiveBlurScaffold(
      appBar: AppBar(
        title: Text(l10n.trafficRuleOverridesTitle),
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
            Text(l10n.trafficRuleOverridesHint),
            const Gap(8),
            TextButton.icon(
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
          final viaVpn = rule.action == TrafficRuleAction.vpn;
          return Material(
            key: ObjectKey(rule),
            type: MaterialType.transparency,
            child: ListTile(
              leading: ReorderableDragStartListener(
                index: index,
                child: const SizedBox(
                  width: 40,
                  height: 48,
                  child: Icon(Icons.drag_handle_rounded),
                ),
              ),
              title: Text(rule.value),
              subtitle: Text(
                '${_matchLabel(l10n, rule.matchType)} • '
                '${viaVpn ? l10n.trafficRuleViaVpn : l10n.trafficRuleDirect}',
              ),
              onTap: () => _edit(index),
              trailing: IconButton(
                tooltip: l10n.delete,
                onPressed: () => setState(() => _rules.removeAt(index)),
                icon: const Icon(Icons.close_rounded),
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

class _TrafficRuleEditor extends StatefulWidget {
  const _TrafficRuleEditor({required this.initial, required this.isDuplicate});

  final TrafficRuleOverride? initial;
  final bool Function(TrafficRuleOverride) isDuplicate;

  @override
  State<_TrafficRuleEditor> createState() => _TrafficRuleEditorState();
}

class _TrafficRuleEditorState extends State<_TrafficRuleEditor> {
  late final _value = TextEditingController(text: widget.initial?.value);
  late var _type =
      widget.initial?.matchType ?? TrafficRuleMatchType.domainSuffix;
  late var _action = widget.initial?.action ?? TrafficRuleAction.vpn;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(widget.initial == null ? l10n.add : l10n.trafficRuleEdit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<TrafficRuleMatchType>(
            initialValue: _type,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.trafficRuleMatchType),
            items: [
              for (final type in TrafficRuleMatchType.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(_matchLabel(l10n, type)),
                ),
            ],
            onChanged: (type) {
              if (type == null) return;
              setState(() {
                _type = type;
                _error = null;
              });
            },
          ),
          const Gap(12),
          TextField(
            key: const ValueKey('traffic-rule-override-value'),
            controller: _value,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: _matchLabel(l10n, _type),
              hintText: _type == TrafficRuleMatchType.ipCidr
                  ? '192.0.2.0/24'
                  : 'example.org',
              errorText: _error,
            ),
          ),
          const Gap(12),
          DropdownButtonFormField<TrafficRuleAction>(
            initialValue: _action,
            decoration: InputDecoration(labelText: l10n.trafficRuleRoute),
            items: [
              DropdownMenuItem(
                value: TrafficRuleAction.vpn,
                child: Text(l10n.trafficRuleViaVpn),
              ),
              DropdownMenuItem(
                value: TrafficRuleAction.direct,
                child: Text(l10n.trafficRuleDirect),
              ),
            ],
            onChanged: (action) {
              if (action != null) setState(() => _action = action);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => _submit(l10n),
          child: Text(l10n.saveAction),
        ),
      ],
    );
  }
}

class TrafficRoutePreviewPage extends StatefulWidget {
  const TrafficRoutePreviewPage({super.key, required this.onInspect});

  final Future<TrafficRoutePreview> Function(String) onInspect;

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
            icon: const Icon(Icons.search_rounded),
            label: Text(l10n.trafficRoutePreviewTitle),
          ),
          if (_busy) const LinearProgressIndicator(),
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
