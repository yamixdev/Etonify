import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

@immutable
class ServerIpMetadata {
  const ServerIpMetadata({
    required this.ip,
    this.organization = '',
    this.asn,
    this.network = '',
    this.countryName = '',
    this.city = '',
    this.timezone = '',
  });

  final String ip;
  final String organization;
  final int? asn;
  final String network;
  final String countryName;
  final String city;
  final String timezone;
}

class ServerIpMetadataLookup {
  ServerIpMetadataLookup({
    http.Client Function()? clientFactory,
    DateTime Function()? now,
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _now = now ?? DateTime.now;

  final http.Client Function() _clientFactory;
  final DateTime Function() _now;
  final _cache = <String, ({ServerIpMetadata info, DateTime expires})>{};
  http.Client? _client;
  int _generation = 0;

  Future<ServerIpMetadata> load(String ip) async {
    final address = InternetAddress.tryParse(ip.trim());
    if (address == null ||
        address.isLoopback ||
        address.isLinkLocal ||
        address.isMulticast) {
      throw const FormatException('Invalid server IP');
    }
    final normalized = address.address;
    final cached = _cache.remove(normalized);
    if (cached != null && _now().isBefore(cached.expires)) {
      _cache[normalized] = cached;
      return cached.info;
    }
    cancel();
    final generation = _generation;
    final client = _clientFactory();
    _client = client;
    try {
      final result = await _fetch(
        client,
        normalized,
      ).timeout(const Duration(seconds: 5));
      if (generation != _generation) {
        throw StateError('IP metadata lookup cancelled');
      }
      _cache[normalized] = (
        info: result,
        expires: _now().add(const Duration(hours: 6)),
      );
      while (_cache.length > 32) {
        _cache.remove(_cache.keys.first);
      }
      return result;
    } finally {
      client.close();
      if (identical(client, _client)) _client = null;
    }
  }

  Future<ServerIpMetadata> _fetch(http.Client client, String ip) async {
    final request = http.Request('GET', Uri.https('ip.guide', '/$ip'))
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    final response = await client.send(request);
    if (response.statusCode != 200) {
      throw HttpException('IP metadata HTTP ${response.statusCode}');
    }
    const limit = 64 * 1024;
    if ((response.contentLength ?? 0) > limit) {
      throw const FormatException('IP metadata too large');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > limit) {
        throw const FormatException('IP metadata too large');
      }
      bytes.add(chunk);
    }
    final json = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (json is! Map<String, dynamic> ||
        !listEquals(
          InternetAddress.tryParse(json['ip']?.toString() ?? '')?.rawAddress,
          InternetAddress.tryParse(ip)!.rawAddress,
        )) {
      throw const FormatException(
        'IP metadata does not match requested address',
      );
    }
    final network = json['network'];
    final autonomous = network is Map ? network['autonomous_system'] : null;
    final location = json['location'];
    String text(Object? value) =>
        value is String && value.length <= 512 ? value.trim() : '';
    final asnValue = autonomous is Map ? autonomous['asn'] : null;
    return ServerIpMetadata(
      ip: ip,
      organization: autonomous is Map ? text(autonomous['organization']) : '',
      asn: asnValue is int && asnValue > 0 && asnValue <= 4294967295
          ? asnValue
          : null,
      network: network is Map ? text(network['cidr']) : '',
      countryName: location is Map ? text(location['country']) : '',
      city: location is Map ? text(location['city']) : '',
      timezone: location is Map ? text(location['timezone']) : '',
    );
  }

  void cancel() {
    _generation++;
    _client?.close();
    _client = null;
  }
}

class ServerIpMetadataController extends ChangeNotifier {
  ServerIpMetadataController({
    Future<ServerIpMetadata> Function(String ip)? load,
    VoidCallback? cancel,
  }) {
    final lookup = load == null ? ServerIpMetadataLookup() : null;
    _load = load ?? lookup!.load;
    _cancel = cancel ?? lookup?.cancel ?? () {};
  }

  late final Future<ServerIpMetadata> Function(String ip) _load;
  late final VoidCallback _cancel;
  String _key = '';
  String _ip = '';
  int _generation = 0;
  bool _disposed = false;
  ServerIpMetadata? _info;
  bool _loading = false;
  bool _failed = false;
  ServerIpMetadata? get info => _info;
  bool get loading => _loading;
  bool get failed => _failed;

  void select(String key, String ip) {
    if (_disposed || (_key == key && _ip == ip)) return;
    _generation++;
    _cancel();
    _key = key;
    _ip = ip;
    _info = null;
    _loading = false;
    _failed = false;
    if (ip.isNotEmpty) {
      unawaited(refresh());
    } else {
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_disposed || _loading || _ip.isEmpty) return;
    final generation = ++_generation;
    final ip = _ip;
    _loading = true;
    _failed = false;
    notifyListeners();
    try {
      final result = await _load(ip);
      if (_disposed || generation != _generation) return;
      if (result.ip != ip) {
        throw const FormatException('Unexpected metadata IP');
      }
      _info = result;
    } catch (_) {
      if (!_disposed && generation == _generation) _failed = true;
    } finally {
      if (!_disposed && generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void cancel() {
    if (_disposed) return;
    _generation++;
    _cancel();
    _key = '';
    _ip = '';
    _info = null;
    _loading = false;
    _failed = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cancel();
    super.dispose();
  }
}
