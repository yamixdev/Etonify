import 'dart:async';
import 'package:flutter/material.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/platform/android/root_mode_client.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

/// Temporary migration screen: no root permission request until confirmation.
class SettingsRootModePage extends StatefulWidget {
  const SettingsRootModePage({super.key, this.client});
  final RootModeClient? client;
  @override
  State<SettingsRootModePage> createState() => _SettingsRootModePageState();
}

class _SettingsRootModePageState extends State<SettingsRootModePage> {
  late final _client = widget.client ?? RootModeClient();
  RootModeStatus _status = const RootModeStatus();
  bool _loading = true;
  bool _pending = false;
  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final status = await _client.snapshot();
    if (mounted) {
      setState(() {
        _status = status;
        _loading = false;
      });
    }
  }

  Future<void> _remove() async {
    if (_loading || _pending || _status.busy) return;
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(l.rootModeRemoveTitle),
        content: Text(l.rootModeRemoveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('root-remove-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.rootModeRemove),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _pending = true);
    final status = await _client.remove();
    if (mounted) {
      setState(() {
        _status = status;
        _pending = false;
      });
    }
  }

  String _reason(AppLocalizations l) => switch (_status.reason) {
    'module_metadata_missing' => l.rootModeMetadataMissing,
    'root_denied' => l.rootModeRootDenied,
    'su_not_found' => l.rootModeRootUnavailable,
    'root_command_timeout' => l.rootModePermissionTimeout,
    'runtime_busy' => l.rootModeStopFirst,
    'signature_invalid' ||
    'module_integrity_failed' ||
    'manifest_invalid' ||
    'signing_not_configured' ||
    'signing_key_invalid' => l.rootModeVerificationFailed,
    'module_cleanup_work_dir_denied' => l.rootModeWorkDirDenied,
    'module_cleanup_lock_denied' => l.rootModeLockDenied,
    'module_cleanup_journal_denied' => l.rootModeJournalDenied,
    'module_cleanup_root_required' => l.rootModeRootDenied,
    'module_cleanup_failed' ||
    'module_cleanup_cleanup_failed' => l.rootModeCleanupFailed,
    _ => l.rootModeOperationFailed,
  };
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l.rootModeTitle)),
      body: ListView(
        padding: settingsScreenPadding.copyWith(
          bottom: appBottomSafePadding(context, settingsScreenPadding.bottom),
        ),
        children: [
          Text(l.rootModeDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: settingsSectionGap),
          ListTile(
            leading: const Icon(Icons.extension_off_outlined),
            title: Text(l.rootModeModuleStatus),
            subtitle: Text(
              _loading
                  ? l.rootModeChecking
                  : _status.moduleState == RootModuleState.notInstalled
                  ? l.rootModeNotInstalled
                  : _status.moduleVersion != null
                  ? l.rootModeVersion(_status.moduleVersion!)
                  : l.rootModeFailed,
            ),
          ),
          if (_loading || _pending || _status.busy)
            const LinearProgressIndicator(key: ValueKey('root-progress')),
          if (!_loading && _status.reason != null) ...[
            const SizedBox(height: settingsSectionGap),
            Text(
              _reason(l),
              key: const ValueKey('root-reason'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            SelectableText(
              _status.reason!,
              key: const ValueKey('root-reason-code'),
            ),
          ],
          const SizedBox(height: settingsSectionGap),
          FilledButton.icon(
            key: const ValueKey('root-remove'),
            onPressed: _loading || _pending || _status.busy ? null : _remove,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(l.rootModeRemove),
          ),
        ],
      ),
    );
  }
}
