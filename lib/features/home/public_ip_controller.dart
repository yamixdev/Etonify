import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

@immutable
class PublicIpInfo {
  const PublicIpInfo({required this.ip, required this.countryCode});

  final String ip;
  final String countryCode;

  factory PublicIpInfo.fromTrace(String trace) {
    final fields = <String, String>{};
    for (final line in const LineSplitter().convert(trace)) {
      final separator = line.indexOf('=');
      if (separator > 0) {
        fields[line.substring(0, separator).trim()] = line
            .substring(separator + 1)
            .trim();
      }
    }
    final ip = fields['ip'] ?? '';
    if (InternetAddress.tryParse(ip) == null) {
      throw const FormatException('Invalid public IP response');
    }
    final country = (fields['loc'] ?? '').toUpperCase();
    return PublicIpInfo(
      ip: ip,
      countryCode: RegExp(r'^[A-Z]{2}$').hasMatch(country) && country != 'XX'
          ? country
          : '',
    );
  }
}

/// A normal OS-routed request, intentionally not an outbound-specific core RPC.
/// Clients are short-lived so a refresh cannot reuse a pre-switch connection.
class PublicIpLookup {
  PublicIpLookup({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;
  http.Client? _client;
  int _generation = 0;

  Future<PublicIpInfo> load() async {
    final generation = ++_generation;
    Object? lastError;
    for (final host in ['1.1.1.1', 'cloudflare.com']) {
      if (generation != _generation) throw StateError('IP request cancelled');
      final client = _clientFactory();
      _client = client;
      try {
        return await _fetch(
          client,
          Uri.https(host, '/cdn-cgi/trace'),
        ).timeout(const Duration(seconds: 3));
      } catch (error) {
        lastError = error;
      } finally {
        client.close();
        if (identical(_client, client)) _client = null;
      }
    }
    throw lastError ?? StateError('Public IP unavailable');
  }

  Future<PublicIpInfo> _fetch(http.Client client, Uri uri) async {
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers['Accept'] = 'text/plain'
      ..headers['Cache-Control'] = 'no-cache';
    final response = await client.send(request);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Public IP HTTP ${response.statusCode}');
    }
    const maxBytes = 8192;
    if ((response.contentLength ?? 0) > maxBytes) {
      throw const FormatException('Public IP response too large');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const FormatException('Public IP response too large');
      }
      bytes.add(chunk);
    }
    return PublicIpInfo.fromTrace(utf8.decode(bytes.takeBytes()));
  }

  void cancel() {
    _generation++;
    _client?.close();
    _client = null;
  }
}

/// App-owned: memory-only result and cooldown survive closing the sheet.
class PublicIpController extends ChangeNotifier {
  PublicIpController({
    Future<PublicIpInfo> Function()? load,
    VoidCallback? cancel,
  }) {
    if (load == null) {
      final lookup = PublicIpLookup();
      _load = lookup.load;
      _cancel = lookup.cancel;
    } else {
      _load = load;
      _cancel = cancel ?? () {};
    }
  }

  late final Future<PublicIpInfo> Function() _load;
  late final VoidCallback _cancel;
  PublicIpInfo? _info;
  bool _loading = false;
  bool _failed = false;
  bool _disposed = false;
  Timer? _cooldown;
  int _generation = 0;

  PublicIpInfo? get info => _info;
  bool get loading => _loading;
  bool get failed => _failed;
  bool get canRefresh => !_disposed && !_loading && _cooldown == null;

  Future<void> refresh() async {
    if (!canRefresh) return;
    final generation = ++_generation;
    _loading = true;
    _failed = false;
    _cooldown = Timer(const Duration(seconds: 4), () {
      _cooldown = null;
      if (!_disposed) notifyListeners();
    });
    notifyListeners();
    try {
      final result = await _load();
      if (_disposed || generation != _generation) return;
      _info = result;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _failed = true;
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
    if (_loading) {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    cancel();
    _disposed = true;
    _cooldown?.cancel();
    super.dispose();
  }
}
