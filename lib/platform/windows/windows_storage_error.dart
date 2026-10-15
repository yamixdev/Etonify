import 'package:flutter/material.dart';
import 'package:meow_client/core/platform/app_data_paths.dart';

/// A recoverable error surface, never a substitute database or ready home.
class WindowsStorageErrorScreen extends StatefulWidget {
  const WindowsStorageErrorScreen({
    super.key,
    required this.onRetry,
    this.legacyDataFound = false,
  });
  final Future<void> Function() onRetry;
  final bool legacyDataFound;
  @override
  State<WindowsStorageErrorScreen> createState() =>
      _WindowsStorageErrorScreenState();
}

class _WindowsStorageErrorScreenState extends State<WindowsStorageErrorScreen> {
  bool _retrying = false;
  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: AlertDialog(
        title: const Text('Unable to open user data'),
        content: Text(
          widget.legacyDataFound
              ? LegacyWindowsStorageException.message
              : 'Storage may be unavailable, read-only, or its encryption key may be '
                    'missing or corrupt. Restore the complete data folder and retry. '
                    'Your existing files were kept.',
        ),
        actions: [
          FilledButton(
            onPressed: _retrying ? null : _retry,
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
