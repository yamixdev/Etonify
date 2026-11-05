import 'package:flutter/material.dart';
import 'package:meow_client/platform/android/legacy_module_cleanup_client.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

class LegacyModuleCleanupNotice extends StatefulWidget {
  const LegacyModuleCleanupNotice({
    super.key,
    required this.child,
    this.enabled = true,
    this.client,
  });
  final Widget child;
  final bool enabled;
  final LegacyModuleCleanupClient? client;
  @override
  State<LegacyModuleCleanupNotice> createState() =>
      _LegacyModuleCleanupNoticeState();
}

class _LegacyModuleCleanupNoticeState extends State<LegacyModuleCleanupNotice> {
  late final _client = widget.client ?? LegacyModuleCleanupClient();
  bool _attempted = false;
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(LegacyModuleCleanupNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    if (!widget.enabled || _attempted) return;
    _attempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final status = await _client.snapshot();
      if (!mounted) return;
      if (!widget.enabled) {
        _attempted = false;
        return;
      }
      if (!status.promptPending) return;
      final l = AppLocalizations.of(context);
      if (status.moduleState != LegacyModuleState.ready) {
        await _client.acknowledgePrompt();
        if (!mounted || !widget.enabled) return;
        await _result(l.legacyCleanupFailed);
        return;
      }
      final accept = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(l.legacyCleanupTitle),
          content: Text(l.legacyCleanupMessage),
          actions: [
            TextButton(
              key: const ValueKey('legacy-cleanup-later'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.legacyCleanupLater),
            ),
            FilledButton(
              key: const ValueKey('legacy-cleanup-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.legacyCleanupRemove),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (accept == true && !widget.enabled) {
        _attempted = false;
        return;
      }
      // Store an actual answer before requesting root, never consume a
      // prompt merely because an asynchronous snapshot finished in background.
      final acknowledged = await _client.acknowledgePrompt();
      if (accept != true || !mounted || !widget.enabled) return;
      if (acknowledged.promptPending || acknowledged.reason != null) {
        await _result(l.legacyCleanupFailed);
        return;
      }
      final result = await _client.remove();
      if (mounted) {
        await _result(
          result.moduleState == LegacyModuleState.notInstalled &&
                  result.reason == null
              ? l.legacyCleanupSuccess
              : l.legacyCleanupFailed,
        );
      }
    });
  }

  Future<void> _result(String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(AppLocalizations.of(context).legacyCleanupTitle),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => widget.child;
}
