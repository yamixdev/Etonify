import 'dart:async';
import 'dart:math';
import 'desktop_contract.dart';
import 'desktop_preferences.dart';
import 'desktop_transport.dart';

class DesktopRuntimeException implements Exception {
  const DesktopRuntimeException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'Desktop runtime $code: $message';
}

/// Owns one framed source and bounded request completion. B2 supplies transport.
class DesktopRuntimeClient {
  DesktopRuntimeClient({
    required DesktopTransport transport,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _transport = transport;
  DesktopRuntimeClient.unavailable()
    : _transport = null,
      requestTimeout = const Duration(seconds: 15);

  final DesktopTransport? _transport;
  final Duration requestTimeout;
  final _events = StreamController<RuntimeEnvelope>.broadcast();
  final _pending = <String, _PendingRequest>{};
  final _decoder = DesktopFrameDecoder();
  StreamSubscription<Object?>? _subscription;
  Future<void>? _opening;
  Future<void>? _closingTransport;
  bool _transportOpened = false;
  DesktopRuntimeException? _terminal;
  String _sessionId = '';
  int _configGeneration = 0;
  int _networkGeneration = 0;
  // Network epochs are shared across actual and proposed config identities.
  // Keep the lower bound separate: raising it must not relabel either tuple.
  int _networkFloor = 0;
  int _requestId = 0;
  int _issuedConfigGeneration = 0;
  int _revision = 0;
  _TransitionAttempt? _activeTransition;
  final _discardedProposals = <(String, int)>{};

  Stream<RuntimeEnvelope> get events => _events.stream;

  // Storage preserves unknown fields; v1 Modes deliberately does not send UI
  // presentation or unadvertised future settings to the runtime.
  static Map<String, Object?> wireModes(DesktopModePreferences modes) =>
      modes.toMap()..removeWhere(
        (key, _) => !const {
          'tunEnabled',
          'systemProxyEnabled',
          'launchAtLogin',
          'launchMinimized',
          'connectOnLaunch',
          'processRoutingMode',
          'processPaths',
        }.contains(key),
      );

  Future<void> _open() => _opening ??= _openTransport();
  Future<void> _openTransport() async {
    if (_terminal != null) throw _terminal!;
    final transport = _transport;
    if (transport == null) {
      _fail(
        'unavailable',
        'Windows native bridge is not installed (B2 pending)',
      );
      throw _terminal!;
    }
    try {
      // A timeout/close does not cancel the native open itself. Retain a
      // completion observer that releases a resource acquired after disposal.
      final opening = transport.open().then((_) async {
        _transportOpened = true;
        if (_terminal != null) await _closeTransport();
      });
      await opening.timeout(requestTimeout);
      if (_terminal != null) throw _terminal!;
      if (transport is DecodedDesktopTransport) {
        _subscription = transport.envelopes.listen(
          (envelope) {
            try {
              _receive(envelope);
            } on Object catch (error) {
              _fail('protocol_error', error.toString());
            }
          },
          onError: (Object error) => _fail(
            error is FormatException ? 'protocol_error' : 'transport_lost',
            error.toString(),
          ),
          // Decoded transports validate EOF/unfinished assembly themselves.
          onDone: () => _fail('transport_lost', 'Windows transport closed'),
        );
        return;
      }
      _subscription = transport.frames.listen(
        (chunk) {
          try {
            for (final envelope in _decoder.add(chunk)) {
              _receive(envelope);
            }
          } on Object catch (error) {
            _fail('protocol_error', error.toString());
          }
        },
        onError: (Object error) => _fail('transport_lost', error.toString()),
        onDone: () {
          try {
            _decoder.finish();
          } on Object catch (error) {
            _fail('protocol_error', error.toString());
            return;
          }
          _fail('transport_lost', 'Windows transport closed');
        },
      );
    } on Object catch (error) {
      if (error is DesktopRuntimeException) rethrow;
      _fail('unavailable', error.toString());
      throw _terminal!;
    }
  }

  Future<Map<String, Object?>> call(
    String method,
    Map<String, Object?> payload,
  ) => _call(method, payload);

  Future<Map<String, Object?>> _call(
    String method,
    Map<String, Object?> payload, {
    _TransitionAttempt? attempt,
    _RuntimeIdentity? identity,
  }) async {
    if (_terminal != null) throw _terminal!;
    await _open();
    if (_terminal != null) throw _terminal!;
    if (attempt?.cancelled != null) throw attempt!.cancelled!;
    final tuple = identity ?? _confirmed;
    final request = RuntimeEnvelope(
      kind: RuntimeEnvelopeKind.request,
      id: (++_requestId).toString(),
      sessionId: tuple.sessionId,
      configGeneration: tuple.configGeneration,
      networkGeneration: tuple.networkGeneration,
      method: method,
      payload: payload,
    );
    final pending = _PendingRequest(request, attempt);
    _pending[request.id] = pending;
    // Attach the deadline/error handler before send; synchronous transports may reply.
    final response = pending.completer.future.timeout(requestTimeout);
    try {
      unawaited(_send(request));
      return await response;
    } finally {
      _pending.remove(request.id);
    }
  }

  Future<void> _send(RuntimeEnvelope request) async {
    try {
      await _transport!.send(DesktopFrameCodec.encode(request));
    } on Object catch (error) {
      _fail('transport_lost', error.toString());
    }
  }

  void _receive(RuntimeEnvelope envelope) {
    if (_terminal != null) return;
    if (envelope.kind == RuntimeEnvelopeKind.response) {
      final pending = _pending[envelope.id];
      if (pending == null || pending.completer.isCompleted) return;
      final request = pending.envelope;
      if (envelope.sessionId != request.sessionId ||
          envelope.configGeneration != request.configGeneration ||
          envelope.networkGeneration != request.networkGeneration ||
          envelope.method != request.method) {
        return;
      }
      final error = envelope.error;
      if (error != null) {
        pending.completer.completeError(
          DesktopRuntimeException(error.code, error.message),
        );
      } else {
        pending.completer.complete(
          envelope.payload == null
              ? <String, Object?>{}
              : objectMap(envelope.payload),
        );
      }
    } else if (envelope.kind == RuntimeEnvelopeKind.event) {
      if (envelope.networkGeneration < _networkFloor) return;
      final proposal = _activeTransition?.proposal;
      if (!_confirmed.accepts(envelope) &&
          !(proposal?.accepts(envelope) ?? false)) {
        return;
      }
      if (envelope.method == 'snapshot') {
        final value = _matchingSnapshot(objectMap(envelope.payload), envelope);
        if (_discardedProposals.contains((
              envelope.sessionId,
              envelope.configGeneration,
            )) &&
            (value.phase == DesktopRuntimePhase.connected ||
                value.phase == DesktopRuntimePhase.starting)) {
          return;
        }
        _confirm(value);
      } else {
        if (_discardedProposals.contains((
          envelope.sessionId,
          envelope.configGeneration,
        ))) {
          return;
        }
        if (_networkFloor != envelope.networkGeneration) _revision++;
        _networkFloor = envelope.networkGeneration;
        if (_confirmed.accepts(envelope)) {
          if (_networkGeneration != envelope.networkGeneration) _revision++;
          _networkGeneration = envelope.networkGeneration;
        }
        if (proposal?.accepts(envelope) ?? false) {
          _activeTransition!.proposal = _RuntimeIdentity(
            envelope.sessionId,
            envelope.configGeneration,
            envelope.networkGeneration,
          );
        }
      }
      _events.add(envelope);
    } else {
      throw const FormatException('Unexpected desktop request from host');
    }
  }

  _RuntimeIdentity get _confirmed =>
      _RuntimeIdentity(_sessionId, _configGeneration, _networkGeneration);

  DesktopRuntimeSnapshot _matchingSnapshot(
    Map<String, Object?> data,
    RuntimeEnvelope request,
  ) {
    final value = DesktopRuntimeSnapshot.fromMap(data);
    if (value.sessionId != request.sessionId ||
        value.configGeneration != request.configGeneration ||
        value.networkGeneration <
            max(request.networkGeneration, _networkFloor)) {
      throw const FormatException('Snapshot identity does not match request');
    }
    return value;
  }

  void _confirm(DesktopRuntimeSnapshot value, {bool authoritative = false}) {
    final networkFloor = authoritative
        ? value.networkGeneration
        : max(_networkFloor, value.networkGeneration);
    if (value.sessionId != _sessionId ||
        value.configGeneration != _configGeneration ||
        value.networkGeneration != _networkGeneration ||
        networkFloor != _networkFloor) {
      _revision++;
    }
    _sessionId = value.sessionId;
    _configGeneration = value.configGeneration;
    _networkGeneration = value.networkGeneration;
    _networkFloor = networkFloor;
    _issuedConfigGeneration = max(_issuedConfigGeneration, _configGeneration);
    final proposal = _activeTransition?.proposal;
    if (proposal != null &&
        proposal.sessionId == value.sessionId &&
        proposal.configGeneration == value.configGeneration) {
      _activeTransition!.proposal = _confirmed;
    }
  }

  Future<DesktopRuntimeSnapshot> snapshot() => _snapshot();

  Future<DesktopRuntimeSnapshot> _snapshot({
    _TransitionAttempt? attempt,
  }) async {
    final revision = _revision;
    final data = await _call('snapshot', {}, attempt: attempt);
    if (revision != _revision) {
      throw const DesktopRuntimeException(
        'superseded',
        'Snapshot superseded by a newer runtime operation',
      );
    }
    // Only the explicit snapshot RPC may resynchronize to the host's actual
    // tuple. Its response envelope still has to match the request exactly.
    final value = DesktopRuntimeSnapshot.fromMap(data);
    _confirm(value, authoritative: true);
    // A fresh authoritative read establishes the only accepted actual tuple.
    // Older proposals cannot match it or a retry's never-reused generation.
    _discardedProposals.clear();
    return value;
  }

  void _requireModes(
    DesktopCapabilities capabilities,
    DesktopModePreferences modes,
  ) {
    for (final name in [
      'localProxy',
      if (modes.tunEnabled) 'tun',
      if (modes.systemProxyEnabled) 'systemProxy',
      if (modes.processPaths.isNotEmpty ||
          modes.processRoutingMode == ProcessRoutingMode.onlySelected)
        'processRouting',
    ]) {
      if (!capabilities.supports(name)) {
        throw UnsupportedError('Windows runtime does not support $name');
      }
    }
  }

  Future<DesktopRuntimeSnapshot> start({
    required String config,
    required DesktopModePreferences modes,
  }) => _transition('start', config, modes);
  Future<DesktopRuntimeSnapshot> applyModes({
    required String config,
    required DesktopModePreferences modes,
  }) => _transition('applyModes', config, modes);

  Future<DesktopRuntimeSnapshot> _transition(
    String method,
    String config,
    DesktopModePreferences modes,
  ) async {
    if (_activeTransition != null) {
      throw StateError('Windows runtime transition already in progress');
    }
    final attempt = _activeTransition = _TransitionAttempt();
    _revision++;
    StreamSubscription<RuntimeEnvelope>? listener;
    var succeeded = false;
    try {
      final current = await _duringAttempt(
        _snapshot(attempt: attempt),
        attempt,
      );
      _requireModes(current.capabilities, modes);
      if (_issuedConfigGeneration == 0x7fffffffffffffff) {
        throw StateError('Windows configuration generation exhausted');
      }
      final proposal = attempt.proposal = _RuntimeIdentity(
        method == 'start'
            ? '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}'
            : _sessionId,
        ++_issuedConfigGeneration,
        _networkGeneration,
      );
      final connected = Completer<DesktopRuntimeSnapshot>();
      final future = connected.future.timeout(requestTimeout);
      listener = events.listen(
        (event) {
          if (event.method != 'snapshot' ||
              connected.isCompleted ||
              attempt.cancelled != null ||
              !proposal.accepts(event)) {
            return;
          }
          final value = DesktopRuntimeSnapshot.fromMap(
            objectMap(event.payload),
          );
          if (value.phase == DesktopRuntimePhase.failed ||
              value.error != null) {
            connected.completeError(
              DesktopRuntimeException(
                value.error?.code ?? 'runtime_failed',
                value.error?.message ?? 'Windows runtime failed',
              ),
            );
          } else if (value.phase == DesktopRuntimePhase.connected) {
            connected.complete(value);
          }
        },
        onError: (Object error) {
          if (!connected.isCompleted) connected.completeError(error);
        },
      );
      // Observe failure even if RPC fails first, avoiding orphan async errors.
      unawaited(future.then<void>((_) {}, onError: (Object _) {}));
      final data = await _duringAttempt(
        _call(
          method,
          {
            'config': config,
            'modes': wireModes(modes),
            'sessionId': proposal.sessionId,
            'configGeneration': proposal.configGeneration,
            'networkGeneration': proposal.networkGeneration,
          },
          identity: proposal,
          attempt: attempt,
        ),
        attempt,
      );
      final response = _matchingSnapshot(
        data,
        RuntimeEnvelope(
          kind: RuntimeEnvelopeKind.request,
          id: '',
          sessionId: proposal.sessionId,
          configGeneration: proposal.configGeneration,
          networkGeneration: max(proposal.networkGeneration, _networkFloor),
          method: method,
        ),
      );
      _confirm(response);
      if (response.phase == DesktopRuntimePhase.failed ||
          response.error != null) {
        throw DesktopRuntimeException(
          response.error?.code ?? 'runtime_failed',
          response.error?.message ?? 'Windows runtime failed',
        );
      }
      if (response.phase == DesktopRuntimePhase.connected) {
        // Controllers need the verified host state even when it arrives as a
        // response rather than a separate native event.
        _events.add(
          RuntimeEnvelope(
            kind: RuntimeEnvelopeKind.event,
            id: '',
            sessionId: response.sessionId,
            configGeneration: response.configGeneration,
            networkGeneration: response.networkGeneration,
            method: 'snapshot',
            payload: response.toMap(),
          ),
        );
        succeeded = true;
        return response;
      }
      final value = await _duringAttempt(future, attempt);
      succeeded = true;
      return value;
    } finally {
      final proposal = attempt.proposal;
      if (!succeeded && proposal != null) {
        _discardedProposals.add((
          proposal.sessionId,
          proposal.configGeneration,
        ));
      }
      await listener?.cancel();
      if (identical(_activeTransition, attempt)) {
        _activeTransition = null;
        _revision++;
      }
    }
  }

  Future<void> stop({required String reason}) async {
    _revision++;
    final attempt = _activeTransition;
    _activeTransition = null;
    if (attempt != null) {
      final proposal = attempt.proposal;
      if (proposal != null) {
        _discardedProposals.add((
          proposal.sessionId,
          proposal.configGeneration,
        ));
      }
      const error = DesktopRuntimeException(
        'cancelled',
        'Runtime transition cancelled by stop',
      );
      attempt.cancelled = error;
      attempt.cancellation.complete(error);
      for (final pending in _pending.values.toList()) {
        if (identical(pending.attempt, attempt)) {
          _pending.remove(pending.envelope.id);
          if (!pending.completer.isCompleted) {
            pending.completer.completeError(error);
          }
        }
      }
    }
    await call('stop', {'reason': reason});
  }

  Future<T> _duringAttempt<T>(
    Future<T> operation,
    _TransitionAttempt attempt,
  ) => Future.any([
    operation,
    attempt.cancellation.future.then<T>((error) => throw error),
  ]);

  void _fail(String code, String message) {
    if (_terminal != null) return;
    final error = _terminal = DesktopRuntimeException(code, message);
    for (final pending in _pending.values) {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(error);
      }
    }
    _pending.clear();
    _events.addError(error);
    unawaited(_closeTransport());
  }

  Future<void> _closeTransport() {
    // Do not memoize an unopened no-op: the native open may succeed later.
    if (!_transportOpened) return Future<void>.value();
    return _closingTransport ??= () async {
      await _subscription?.cancel();
      try {
        await _transport?.close();
      } on Object {
        // The original terminal failure is authoritative for pending callers.
      }
    }();
  }

  Future<void> close() async {
    _fail('closed', 'Windows runtime client disposed');
    await _closeTransport();
    await _events.close();
  }
}

class _PendingRequest {
  _PendingRequest(this.envelope, this.attempt);
  final RuntimeEnvelope envelope;
  final _TransitionAttempt? attempt;
  final completer = Completer<Map<String, Object?>>();
}

class _RuntimeIdentity {
  const _RuntimeIdentity(
    this.sessionId,
    this.configGeneration,
    this.networkGeneration,
  );
  final String sessionId;
  final int configGeneration;
  final int networkGeneration;
  bool accepts(RuntimeEnvelope envelope) =>
      envelope.sessionId == sessionId &&
      envelope.configGeneration == configGeneration &&
      envelope.networkGeneration >= networkGeneration;
}

class _TransitionAttempt {
  _RuntimeIdentity? proposal;
  DesktopRuntimeException? cancelled;
  final cancellation = Completer<DesktopRuntimeException>();
}
