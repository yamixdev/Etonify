import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:meow_client/app/app.dart';
import 'package:meow_client/logging/app_log_store.dart';

void _recordFatalError(String source, Object error, StackTrace stackTrace) {
  final message = '$error\n$stackTrace';
  AppLogStore.error('fatal/$source', message);
}

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
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
      runApp(const ProviderScope(child: MeowClient()));
    },
    (error, stackTrace) {
      _recordFatalError('zone', error, stackTrace);
    },
  );
}
