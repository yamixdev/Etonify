import 'dart:collection';

import 'package:meow_client/core/outbound_location.dart';
import 'package:meow_client/data/subscription/location_aliases.dart';
import 'package:meow_client/models/subscription.dart';

String groupCountryCodeFromName(String name) {
  final flags = RegExp(
    r'([\u{1F1E6}-\u{1F1FF}]{2})',
    unicode: true,
  ).allMatches(name);
  final flaggedCountries = {
    for (final flag in flags)
      String.fromCharCodes(
        flag.group(1)!.runes.map((rune) => rune - 0x1F1E6 + 65),
      ),
  };
  if (flaggedCountries.isNotEmpty) {
    return flaggedCountries.length == 1 ? flaggedCountries.single : '';
  }
  final withoutOrdinal = name.replaceFirst(RegExp(r'\s*#\d+\s*$'), '');
  final segments = withoutOrdinal.split(RegExp(r'\s+[-–—:/]\s+|\s*\|\s*'));
  final countries = {
    for (final segment in segments)
      if (kLocationAliases[segment.trim().toLowerCase()] case final String code)
        code,
  };
  return countries.length == 1 ? countries.single : '';
}

Map<String, String> buildProxyGroupCountryCatalog(
  Iterable<Outbound> outbounds,
  Iterable<SubscriptionGroup> groups,
) {
  final nodes = {for (final outbound in outbounds) outbound.tag: outbound};
  final groupsByTag = {for (final group in groups) group.tag: group};
  final children = <String, Set<String>>{};
  for (final node in nodes.values) {
    if (node.type != 'selector' && node.type != 'urltest') continue;
    final references = node.config['outbounds'];
    children[node.tag] = {
      if (references is List) ...references.whereType<String>(),
    };
  }
  for (final group in groupsByTag.values) {
    final references = group.config['outbounds'];
    children[group.tag] = {
      ...group.outboundTags,
      if (references is List) ...references.whereType<String>(),
    };
  }
  final parents = <String, Set<String>>{};
  for (final entry in children.entries) {
    for (final child in entry.value) {
      parents.putIfAbsent(child, () => {}).add(entry.key);
    }
  }

  final countries = <String, String>{};
  final unknown = <String>{};
  final pending = Queue<String>();
  final queued = <String>{};
  void enqueue(String tag) {
    if (queued.add(tag)) pending.add(tag);
  }

  for (final tag in {...children.keys, ...parents.keys}) {
    if (children.containsKey(tag)) {
      if (children[tag]!.isEmpty) {
        unknown.add(tag);
        enqueue(tag);
      }
      continue;
    }
    final node = nodes[tag];
    final country = node != null && isConcreteSubscriptionServer(node)
        ? outboundDisplayCountryCode(node, markAllServersRussia: false)
        : '';
    if (country.isEmpty) {
      unknown.add(tag);
    } else {
      countries[tag] = country;
    }
    enqueue(tag);
  }

  while (pending.isNotEmpty) {
    final tag = pending.removeFirst();
    queued.remove(tag);
    for (final parent in parents[tag] ?? const <String>{}) {
      var changed = false;
      if (unknown.contains(tag)) changed = unknown.add(parent);
      final country = countries[tag];
      if (country != null) {
        final previous = countries[parent];
        final combined = previous == null || previous == country
            ? country
            : '*';
        if (combined != previous) {
          countries[parent] = combined;
          changed = true;
        }
      }
      if (changed) enqueue(parent);
    }
  }

  final result = <String, String>{};
  for (final group in groupsByTag.values) {
    final declared = normalizeOutboundCountryCode(group.country);
    final named = declared.isEmpty ? groupCountryCodeFromName(group.name) : '';
    result[group.tag] = declared.isNotEmpty
        ? declared
        : named.isNotEmpty
        ? named
        : unknown.contains(group.tag) || countries[group.tag] == '*'
        ? ''
        : countries[group.tag] ?? '';
  }
  return result;
}

String groupDisplayCountryCode({
  required String? fallbackCountryCode,
  String? selectedCountryCode,
  required bool markAllServersRussia,
}) {
  if (markAllServersRussia) return 'RU';
  final selected = normalizeOutboundCountryCode(selectedCountryCode);
  return selected.isNotEmpty
      ? selected
      : normalizeOutboundCountryCode(fallbackCountryCode);
}
