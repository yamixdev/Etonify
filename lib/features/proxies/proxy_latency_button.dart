import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

/// A separate gesture target: scrolling cancels the tap recognizer, and taps
/// never fall through to the surrounding server-selection row.
class ProxyLatencyButton extends StatelessWidget {
  const ProxyLatencyButton({
    super.key,
    required this.label,
    required this.child,
    this.onPressed,
  });
  final String label;
  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => GestureDetector(
    excludeFromSemantics: true,
    onTap: () {},
    child: Tooltip(
      message: label,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(72, 48),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          backgroundColor: Colors.transparent,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Semantics(label: label, child: child),
      ),
    ),
  );
}

@Preview(name: 'Latency action', size: Size(160, 80))
Widget proxyLatencyButtonPreview() => MaterialApp(
  home: Scaffold(
    body: Center(
      child: ProxyLatencyButton(
        label: 'Test latency',
        onPressed: () {},
        child: const Text('145 ms'),
      ),
    ),
  ),
);
