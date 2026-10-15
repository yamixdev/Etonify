import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'desktop_contract.dart';
import 'desktop_runtime_client.dart';
import 'desktop_preferences.dart';
import 'package:meow_client/singbox/singbox_config_builder.dart';

class WindowsRuntimeAdapter {
  WindowsRuntimeAdapter({
    required this.client,
    required DesktopModePreferences Function() modes,
  }) : _modes = modes;
  final DesktopRuntimeClient client;
  final DesktopModePreferences Function() _modes;
  void bindModes(DesktopModePreferences Function() modes) {
    _modesSupplier = modes;
  }

  DesktopModePreferences Function()? _modesSupplier;
  DesktopModePreferences get modes => (_modesSupplier ?? _modes)();

  static const _rpcMethods = {
    'selectOutbound',
    'urlTest',
    'cancelUrlTest',
    'prepareStartupUrlTest',
    'groups',
    'traffic',
    'lookupOutboundExternalInfo',
    'fetchUrlViaOutbound',
    'getConfigPath',
    'checkConfig',
    'startProbe',
    'stopProbe',
    'reload',
    'getNetworkInterfaceState',
    'getCoreCapabilities',
    'getCoreVersion',
  };

  late final Stream<Map<String, dynamic>> events = client.events
      .where((event) {
        if (event.method != 'snapshot') return true;
        final payload = objectMap(event.payload);
        return const [
              'connected',
              'stopped',
              'failed',
            ].contains(payload['phase']) ||
            payload['error'] != null;
      })
      .map((event) {
        final payload = objectMap(event.payload);
        if (event.method == 'snapshot') {
          return _legacySnapshot(
            DesktopRuntimeSnapshot.fromMap(payload),
            type: 'state',
          );
        }
        return <String, dynamic>{
          ...payload,
          'type': event.method == 'traffic' ? 'status' : event.method,
          'runtimeGeneration': event.configGeneration,
          'networkGeneration': event.networkGeneration,
        };
      })
      .transform(
        StreamTransformer.fromHandlers(
          handleError:
              (
                Object error,
                StackTrace stack,
                EventSink<Map<String, dynamic>> sink,
              ) {
                sink.add({
                  'type': 'state',
                  'running': false,
                  'error': error.toString(),
                });
              },
        ),
      )
      .asBroadcastStream();

  Map<String, dynamic> _legacySnapshot(
    DesktopRuntimeSnapshot snapshot, {
    String? type,
  }) => {
    ...snapshot.toMap(),
    'type': ?type,
    'running': snapshot.phase == DesktopRuntimePhase.connected,
    'runtimeGeneration': snapshot.configGeneration,
    'mode': snapshot.modes.tunEnabled ? 'vpn' : 'proxy',
    if (snapshot.error != null) 'error': snapshot.error!.message,
  };

  String _config(String value, DesktopModePreferences modes) => jsonEncode(
    SingboxConfigBuilder.adaptForWindows(objectMap(jsonDecode(value)), modes),
  );

  Future<String> _preparedConfig() async {
    final result = await client.call('getConfigPath', {});
    final path = result['path'];
    if (path is! String || path.isEmpty) {
      throw const DesktopRuntimeException(
        'unavailable',
        'Windows prepared config path is unavailable',
      );
    }
    return File(path).readAsString();
  }

  Future<Map<String, Object?>> invoke(
    String method,
    Map<String, Object?> payload,
  ) async {
    final desired = modes;
    switch (method) {
      case 'start':
      case 'startPrepared':
        final config = method == 'start'
            ? payload['config'] as String
            : await _preparedConfig();
        return (await client.start(
          config: _config(config, desired),
          modes: desired,
        )).toMap();
      case 'applyConfig':
      case 'applyPreparedConfig':
        final config = method == 'applyConfig'
            ? payload['config'] as String
            : await _preparedConfig();
        return (await client.applyModes(
          config: _config(config, desired),
          modes: desired,
        )).toMap();
      case 'stop':
        await client.stop(
          reason: payload['reason'] as String? ?? 'unspecified',
        );
        return {};
      case 'status':
        return _legacySnapshot(await client.snapshot());
      case 'startProbe':
        // Probes must never enable TUN or change the user's system proxy.
        final probeModes = desired.copyWith(
          tunEnabled: false,
          systemProxyEnabled: false,
        );
        return client.call(method, {
          'config': _config(payload['config'] as String, probeModes),
          'modes': DesktopRuntimeClient.wireModes(probeModes),
        });
      case 'checkConfig':
        return client.call(method, {
          'config': _config(payload['config'] as String, desired),
        });
      case 'fetchUrlViaOutbound':
        final limit = payload['maxBytes'];
        if (limit is! int || limit < 0) {
          throw const FormatException('Invalid download byte limit');
        }
        final response = await client.call(method, payload);
        final body = response['body'];
        if (body is! List<Object?> || body.length > limit) {
          throw const FormatException('Invalid download body length');
        }
        // The native decoder already validates/materializes bytes off-isolate.
        if (body is Uint8List) return response;
        // JSON arrays are List<dynamic>, not the typed bytes consumed by the
        // shared downloader. Validate before Uint8List can truncate values.
        for (final byte in body) {
          if (byte is! int || byte < 0 || byte > 255) {
            throw const FormatException('Invalid download byte');
          }
        }
        return {...response, 'body': Uint8List.fromList(body.cast<int>())};
      default:
        if (!_rpcMethods.contains(method)) {
          throw UnsupportedError('Unsupported Windows runtime method: $method');
        }
        return client.call(method, payload);
    }
  }
}
