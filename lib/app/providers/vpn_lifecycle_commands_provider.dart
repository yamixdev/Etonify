import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef VpnToggleCommand = Future<void> Function(String source);
typedef VpnStopCommand =
    Future<bool> Function(String reason, bool allowQueuedRestart);

/// UI-facing command port for the VPN lifecycle.
///
/// The port deliberately delegates to the existing runtime coordinators. It
/// does not introduce a second queue or attempt to cancel native work, so
/// start/stop ordering remains owned by RuntimeSessionCoordinator.
class VpnLifecycleCommands {
  VpnToggleCommand? _toggle;
  VpnStopCommand? _stop;

  bool get bound => _toggle != null && _stop != null;

  void bind({required VpnToggleCommand toggle, required VpnStopCommand stop}) {
    _toggle = toggle;
    _stop = stop;
  }

  void unbind() {
    _toggle = null;
    _stop = null;
  }

  Future<bool> toggle({required String source}) async {
    final command = _toggle;
    if (command == null) {
      return false;
    }
    await command(source.trim().isEmpty ? 'unknown' : source.trim());
    return true;
  }

  Future<bool> stop({
    required String reason,
    bool allowQueuedRestart = true,
  }) async {
    final command = _stop;
    if (command == null) {
      return false;
    }
    return command(
      reason.trim().isEmpty ? 'unknown' : reason.trim(),
      allowQueuedRestart,
    );
  }
}

final vpnLifecycleCommandsProvider = Provider<VpnLifecycleCommands>((ref) {
  final commands = VpnLifecycleCommands();
  ref.onDispose(commands.unbind);
  return commands;
}, name: 'vpnLifecycleCommandsProvider');
