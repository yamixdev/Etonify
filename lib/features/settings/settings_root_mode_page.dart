import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meow_client/features/settings/settings_ui.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/platform/android/root_mode_client.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class SettingsRootModePage extends StatefulWidget {
  const SettingsRootModePage({super.key, this.client});

  final RootModeClient? client;

  @override
  State<SettingsRootModePage> createState() => _SettingsRootModePageState();
}

class _SettingsRootModePageState extends State<SettingsRootModePage>
    with WidgetsBindingObserver {
  late final _client = widget.client ?? RootModeClient();
  RootModeStatus _status = const RootModeStatus.unavailable();
  StreamSubscription<RootModeStatus>? _subscription;
  bool _loading = true;
  bool _pending = false;
  bool _cancelRequested = false;
  bool _appActive = true;
  bool _routeActive = true;
  int _revision = 0;

  bool get _busy => _loading || _pending || _status.busy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeActive = ModalRoute.of(context)?.isCurrent ?? true;
    _syncSubscription();
  }

  void _syncSubscription() {
    if (_appActive && _routeActive) {
      _listen();
    } else {
      unawaited(_subscription?.cancel());
      _subscription = null;
      _revision++;
    }
  }

  void _listen() {
    _subscription ??= _client.events.listen((status) {
      if (!mounted) return;
      _revision++;
      setState(() {
        _status = status;
        _loading = false;
        if (!status.busy) _cancelRequested = false;
      });
    });
  }

  Future<void> _refresh() async {
    final revision = _revision;
    final status = await _client.snapshot();
    if (!mounted || revision != _revision) return;
    setState(() {
      _status = status;
      _loading = false;
      if (!status.busy) _cancelRequested = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncSubscription();
    if (state == AppLifecycleState.resumed) {
      if (_routeActive) unawaited(_refresh());
    }
  }

  Future<void> _run(Future<RootModeStatus> Function() operation) async {
    if (_busy) return;
    setState(() {
      _pending = true;
      _cancelRequested = false;
    });
    final revision = ++_revision;
    final status = await operation();
    if (!mounted) return;
    setState(() {
      if (revision == _revision) _status = status;
      _pending = false;
      _cancelRequested = false;
    });
  }

  Future<void> _cancel() async {
    if (_cancelRequested || !_status.busy) return;
    final revision = _revision;
    setState(() => _cancelRequested = true);
    final status = await _client.cancel();
    if (!mounted || revision != _revision) return;
    setState(() {
      _status = status;
      if (!status.busy || status.reason != null) _cancelRequested = false;
    });
  }

  Future<void> _remove() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    if (mounted && confirmed == true) await _run(_client.remove);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  String _rootLabel(AppLocalizations l) => switch (_status.rootAvailability) {
    RootAvailability.unknown => l.rootModeRootUnknown,
    RootAvailability.noSu => l.rootModeRootUnavailable,
    RootAvailability.granted => l.rootModeRootGranted,
    RootAvailability.denied => l.rootModeRootDenied,
  };

  String _moduleLabel(AppLocalizations l) => switch (_status.moduleState) {
    RootModuleState.notInstalled => l.rootModeNotInstalled,
    RootModuleState.downloading => l.rootModeDownloading,
    RootModuleState.verifying => l.rootModeVerifying,
    RootModuleState.installing => l.rootModeInstalling,
    RootModuleState.ready => l.rootModeReady,
    RootModuleState.incompatible => l.rootModeIncompatible,
    RootModuleState.failed => l.rootModeFailed,
  };

  String _reasonLabel(AppLocalizations l) => switch (_status.reason) {
    'signing_not_configured' ||
    'signing_key_invalid' ||
    'trust_not_configured' ||
    'trust_key_not_configured' ||
    'release_not_configured' => l.rootModeTrustUnavailable,
    'root_denied' || 'authorization_denied' => l.rootModeRootDenied,
    'no_su' || 'root_unavailable' => l.rootModeRootUnavailable,
    'download_failed' || 'network_error' => l.rootModeDownloadFailed,
    'verification_failed' ||
    'signature_invalid' ||
    'binary_hash_mismatch' ||
    'binary_size_mismatch' ||
    'hash_mismatch' => l.rootModeVerificationFailed,
    'cancelled' || 'operation_cancelled' => l.rootModeCancelled,
    'invalid_response' => l.rootModeInvalidResponse,
    'vpn_active' || 'stop_connection_first' => l.rootModeStopFirst,
    'root_dns_unavailable' => l.rootModeDnsUnavailable,
    'root_config_unsupported' => l.rootModeConfigUnsupported,
    _ => l.rootModeOperationFailed,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final granted = _status.rootAvailability == RootAvailability.granted;
    final removable =
        _status.moduleState != RootModuleState.notInstalled &&
        (_status.moduleVersion != null ||
            _status.moduleState == RootModuleState.ready ||
            _status.moduleState == RootModuleState.incompatible);
    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l.rootModeTitle)),
      body: ListView(
        padding: settingsScreenPadding.copyWith(
          bottom: appBottomSafePadding(context, settingsScreenPadding.bottom),
        ),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Chip(
              avatar: const Icon(Icons.science_outlined, size: 18),
              label: Text(l.rootModeExperimental),
            ),
          ),
          const SizedBox(height: 8),
          Text(l.rootModeDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: settingsSectionGap),
          SettingsTileGroup(
            children: [
              ListTile(
                leading: Icon(
                  Icons.admin_panel_settings_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l.rootModeRootStatus),
                subtitle: Text(_loading ? l.rootModeChecking : _rootLabel(l)),
              ),
              ListTile(
                leading: Icon(
                  Icons.extension_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l.rootModeModuleStatus),
                subtitle: Text(
                  _loading
                      ? l.rootModeChecking
                      : [
                          _moduleLabel(l),
                          if (_status.moduleVersion case final version?)
                            l.rootModeVersion(version),
                        ].join('\n'),
                ),
              ),
              if (_status.updateAvailable case final available?
                  when !_loading && !_busy)
                ListTile(
                  key: const ValueKey('root-update-result'),
                  leading: Icon(
                    available
                        ? Icons.system_update_rounded
                        : Icons.check_circle_outline,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    available
                        ? l.rootModeUpdateAvailable(
                            _status.availableModuleVersion!,
                          )
                        : l.rootModeUpToDate,
                  ),
                ),
              SwitchListTile(
                key: const ValueKey('root-enabled'),
                title: Text(l.rootModeUseRoot),
                subtitle: Text(l.rootModeUseRootSummary),
                value: _status.enabled,
                onChanged: !_busy && (_status.canEnable || _status.enabled)
                    ? (value) => _run(() => _client.setEnabled(value))
                    : null,
              ),
            ],
          ),
          if (_status.busy || _pending || _loading) ...[
            const SizedBox(height: settingsSectionGap),
            LinearProgressIndicator(
              key: const ValueKey('root-progress'),
              value: _status.moduleState == RootModuleState.downloading
                  ? _status.progress
                  : null,
              semanticsLabel: _moduleLabel(l),
            ),
          ],
          if (!_loading && _status.reason != null) ...[
            const SizedBox(height: settingsSectionGap),
            Text(
              _reasonLabel(l),
              key: const ValueKey('root-reason'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: settingsSectionGap),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('root-check'),
                onPressed: _busy
                    ? null
                    : () => _run(_client.requestAuthorization),
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(l.rootModeCheckRoot),
              ),
              FilledButton.icon(
                key: const ValueKey('root-install'),
                onPressed: _busy || !granted
                    ? null
                    : () => _run(_client.install),
                icon: const Icon(Icons.download_rounded),
                label: Text(l.rootModeDownload),
              ),
              OutlinedButton.icon(
                key: const ValueKey('root-check-update'),
                onPressed: _busy ? null : () => _run(_client.checkUpdate),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.rootModeCheckUpdate),
              ),
              TextButton.icon(
                key: const ValueKey('root-remove'),
                onPressed: _busy || !granted || !removable ? null : _remove,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(l.rootModeRemove),
              ),
              if (_status.busy)
                TextButton(
                  key: const ValueKey('root-cancel'),
                  onPressed: _cancelRequested ? null : _cancel,
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
            ],
          ),
          const SizedBox(height: settingsSectionGap),
          Text(
            l.rootModeSafety,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
