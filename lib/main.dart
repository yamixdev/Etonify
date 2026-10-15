import 'dart:async';
import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:meow_client/app/app.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/core/platform/app_data_paths.dart';
import 'package:meow_client/platform/windows/desktop_contract.dart';
import 'package:meow_client/platform/windows/windows_storage_key.dart';
import 'package:meow_client/platform/windows/windows_storage_bootstrap.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/platform/windows/windows_storage_error.dart';

void _recordFatalError(String source, Object error, StackTrace stackTrace) {
  final message = '$error\n$stackTrace';
  AppLogStore.error('fatal/$source', message);
}

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      File? portableAcknowledgement;
      if (Platform.isWindows) {
        try {
          final launch = await WindowsStorageBootstrap.prepare();
          final paths = AppDataPaths.current;
          final portable = launch.distribution == DesktopDistribution.portable;
          // Open before rendering the application so key/decryption failures
          // cannot silently become an empty database or a blank startup frame.
          final store = await HiveAppSettingsStore.open();
          await store.close();
          if (portable) {
            AppLogStore.info(
              'portable storage',
              WindowsStorageKey.portabilityWarning,
            );
            final acknowledgement = File(
              '${paths.userRoot}/portable-warning-acknowledged',
            );
            if (!await acknowledgement.exists()) {
              portableAcknowledgement = acknowledgement;
            }
          }
        } catch (error) {
          runApp(
            MaterialApp(
              home: WindowsStorageErrorScreen(
                onRetry: main,
                legacyDataFound: error is LegacyWindowsStorageException,
              ),
            ),
          );
          return;
        }
      }
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _recordFatalError(
          'flutter',
          details.exception,
          details.stack ?? StackTrace.current,
        );
      };
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        _recordFatalError('platform', error, stackTrace);
        return true;
      };
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
      );
      // AndroidFilesDir initializes lazily at its call sites. Neither that
      // platform round-trip nor the system UI RPC should delay runApp and the
      // first visible Flutter frame.
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge).catchError(
          (Object error, StackTrace stackTrace) {
            _recordFatalError('system_ui', error, stackTrace);
          },
        ),
      );
      const app = ProviderScope(child: MeowClient());
      final acknowledgement = portableAcknowledgement;
      runApp(
        acknowledgement == null
            ? app
            : WindowsStorageStartup(
                onAcknowledged: () =>
                    acknowledgement.writeAsString('1', flush: true),
                child: app,
              ),
      );
    },
    (error, stackTrace) {
      _recordFatalError('zone', error, stackTrace);
    },
  );
}

/// A one-time disclosure, removed entirely after acknowledgement. Subsequent
/// launches render the normal app directly, including its ordinary startup.
class WindowsStorageStartup extends StatefulWidget {
  const WindowsStorageStartup({
    super.key,
    required this.child,
    required this.onAcknowledged,
  });
  final Widget child;
  final Future<void> Function() onAcknowledged;
  @override
  State<WindowsStorageStartup> createState() => _WindowsStorageStartupState();
}

class _WindowsStorageStartupState extends State<WindowsStorageStartup> {
  bool _acknowledged = false;
  bool _saving = false;
  bool _failed = false;
  Future<void> _continue() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.onAcknowledged();
      if (mounted) setState(() => _acknowledged = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_acknowledged) return widget.child;
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: AlertDialog(
            title: const Text('Portable data privacy'),
            content: Text(
              _failed
                  ? 'Unable to save your choice. Check that the portable data folder is writable and try again.'
                  : WindowsStorageKey.portabilityWarning,
            ),
            actions: [
              FilledButton(
                onPressed: _saving ? null : _continue,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
