/// Launch-local interlock; durable pending state is owned by the settings store.
class SplitRoutingResetSession {
  SplitRoutingResetSession({required this.pending})
    : suppressAutoConnect = pending;
  bool pending;
  final bool suppressAutoConnect;
  bool _handling = false;
  Future<bool?> handle({
    required Future<bool> Function() stop,
    required Future<bool?> Function() showNotice,
    required Future<void> Function() acknowledge,
  }) async {
    if (!pending || _handling) return null;
    _handling = true;
    try {
      if (!await stop()) throw StateError('VPN stop was not confirmed');
      final openSettings = await showNotice();
      if (openSettings == null) return null;
      await acknowledge();
      pending = false;
      return openSettings;
    } finally {
      _handling = false;
    }
  }
}
