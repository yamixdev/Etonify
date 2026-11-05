import 'package:flutter/material.dart';
import 'package:meow_client/core/outbound_location.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/proxy_exclusion_rules.dart';
import 'package:meow_client/models/subscription.dart';

/// Edits a local draft only. The caller owns persistence and runtime policy.
class ProxyExclusionsPage extends StatefulWidget {
  const ProxyExclusionsPage({
    super.key,
    required this.subscription,
    required this.rules,
  });
  final Subscription subscription;
  final ProxyExclusionRules rules;
  @override
  State<ProxyExclusionsPage> createState() => _ProxyExclusionsPageState();
}

class _ProxyExclusionsPageState extends State<ProxyExclusionsPage> {
  late final List<Outbound> _servers;
  late final Set<String> _tags;
  late final Set<String> _serverIds;
  late final Map<String, String> _identityByTag;
  late final List<ProxyExclusionCondition> _conditions;
  String _query = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _servers = ProxyExclusionRules.concreteServers(widget.subscription);
    final rules = widget.rules.bindLegacyTags(widget.subscription);
    _tags = {...rules.excludedTags};
    _serverIds = {...rules.excludedServerIds};
    _identityByTag = ProxyExclusionRules.manualServerIdsFor(
      widget.subscription,
    );
    _conditions = [...widget.rules.conditions];
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _country(Outbound node) => outboundDisplayCountryCode(
    node,
    markAllServersRussia: widget.subscription.markAllServersRussia,
  );

  String _summary(ProxyExclusionCondition condition) => [
    condition.protocol?.toUpperCase(),
    condition.security?.toUpperCase(),
    condition.transport?.toUpperCase(),
    condition.country,
  ].whereType<String>().join(' + ');

  Future<void> _addCondition() async {
    final l = AppLocalizations.of(context);
    final protocols =
        _servers.map(ProxyExclusionCondition.protocolOf).toSet().toList()
          ..sort();
    final securities =
        _servers.map(ProxyExclusionCondition.securityOf).toSet().toList()
          ..sort();
    final transports =
        _servers.map(ProxyExclusionCondition.transportOf).toSet().toList()
          ..sort();
    final countries =
        _servers
            .map(_country)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    String? protocol, security, transport, country;
    final result = await showDialog<ProxyExclusionCondition>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          Widget field(
            String label,
            List<String> values,
            String? value,
            ValueChanged<String?> change,
          ) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DropdownButtonFormField<String>(
              initialValue: value ?? '',
              decoration: InputDecoration(labelText: label),
              isExpanded: true,
              items: [
                DropdownMenuItem(value: '', child: Text(l.proxyExclusionsAny)),
                for (final option in values)
                  DropdownMenuItem(
                    value: option,
                    child: Text(option.toUpperCase()),
                  ),
              ],
              onChanged: (value) =>
                  update(() => change(value == '' ? null : value)),
            ),
          );
          final condition = ProxyExclusionCondition(
            protocol: protocol,
            security: security,
            transport: transport,
            country: country,
          );
          return AlertDialog(
            title: Text(l.proxyExclusionsAddCondition),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.proxyExclusionsConditionHint),
                  field(
                    l.proxyExclusionsProtocol,
                    protocols,
                    protocol,
                    (v) => protocol = v,
                  ),
                  field(
                    l.proxyExclusionsSecurity,
                    securities,
                    security,
                    (v) => security = v,
                  ),
                  field(
                    l.proxyExclusionsTransport,
                    transports,
                    transport,
                    (v) => transport = v,
                  ),
                  field(
                    l.proxyExclusionsCountry,
                    countries,
                    country,
                    (v) => country = v,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: condition.isEmpty
                    ? null
                    : () => Navigator.pop(context, condition),
                child: Text(l.add),
              ),
            ],
          );
        },
      ),
    );
    if (result != null && mounted) setState(() => _conditions.add(result));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final visible = _servers
        .where(
          (node) => '${node.name} ${node.tag} ${node.type} ${_country(node)}'
              .toLowerCase()
              .contains(_query),
        )
        .toList(growable: false);
    final rules = ProxyExclusionRules(
      excludedTags: _tags,
      excludedServerIds: _serverIds,
      legacyTagsBound: true,
      conditions: _conditions,
    );
    final excludedCount = _servers
        .where(
          (node) =>
              _serverIds.contains(_identityByTag[node.tag]) ||
              _conditions.any(
                (condition) =>
                    condition.matches(node, countryCode: _country(node)),
              ),
        )
        .length;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.proxyExclusionsTitle),
        actions: [
          IconButton(
            tooltip: l.coreSettingsReset,
            icon: const Icon(Icons.restart_alt),
            onPressed: () => setState(() {
              _tags.clear();
              _serverIds.clear();
              _conditions.clear();
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.proxyExclusionsHint),
                    const SizedBox(height: 16),
                    Text(
                      l.proxyExclusionsConditions,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (var i = 0; i < _conditions.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_summary(_conditions[i])),
                        trailing: IconButton(
                          tooltip: l.delete,
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => _conditions.removeAt(i)),
                        ),
                      ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: _servers.isEmpty ? null : _addCondition,
                        icon: const Icon(Icons.add),
                        label: Text(l.proxyExclusionsAddCondition),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.proxyExclusionsManual,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        labelText: l.proxyExclusionsSearch,
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '$excludedCount / ${_servers.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (visible.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.proxyExclusionsEmpty),
                ),
              ),
            SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final node = visible[index];
                final byCondition = _conditions.any(
                  (rule) => rule.matches(node, countryCode: _country(node)),
                );
                return CheckboxListTile(
                  key: ValueKey('proxy-exclusion-${node.tag}'),
                  title: Text(node.name),
                  subtitle: Text(
                    [
                      node.type.toUpperCase(),
                      _country(node),
                      if (byCondition) l.proxyExclusionsConditions,
                    ].where((s) => s.isNotEmpty).join(' · '),
                  ),
                  value: _serverIds.contains(_identityByTag[node.tag]),
                  onChanged: (selected) => setState(() {
                    if (selected == true) {
                      _tags.add(node.tag);
                      _serverIds.add(_identityByTag[node.tag]!);
                    } else {
                      _tags.remove(node.tag);
                      _serverIds.remove(_identityByTag[node.tag]);
                    }
                  }),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          key: const Key('proxy-exclusions-apply'),
          onPressed: () => Navigator.pop(context, rules),
          child: Text(l.proxyListApply),
        ),
      ),
    );
  }
}
