import 'dart:async';

import 'package:material_ui/material_ui.dart';

enum AppNoticeTone { info, success, warning, error }

class AppNotice {
  AppNotice._();

  static OverlayEntry? _entry;
  static GlobalKey<_AppNoticeOverlayState>? _noticeKey;

  static void show(
    BuildContext context,
    String message, {
    AppNoticeTone tone = AppNoticeTone.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final normalized = message.trim();
    if (normalized.isEmpty) return;
    final overlay =
        Navigator.maybeOf(context, rootNavigator: true)?.overlay ??
        Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _removeImmediately();
    final key = GlobalKey<_AppNoticeOverlayState>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _AppNoticeOverlay(
        key: key,
        message: normalized,
        tone: tone,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        onRemoved: () {
          if (identical(_entry, entry)) {
            _removeImmediately();
          }
        },
      ),
    );
    _noticeKey = key;
    _entry = entry;
    overlay.insert(entry);
  }

  static void dismiss() {
    final state = _noticeKey?.currentState;
    if (state == null) {
      _removeImmediately();
      return;
    }
    unawaited(state.dismiss());
  }

  static void _removeImmediately() {
    _entry?.remove();
    _entry = null;
    _noticeKey = null;
  }
}

class _AppNoticeOverlay extends StatefulWidget {
  const _AppNoticeOverlay({
    super.key,
    required this.message,
    required this.tone,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
    required this.onRemoved,
  });

  final String message;
  final AppNoticeTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onRemoved;

  @override
  State<_AppNoticeOverlay> createState() => _AppNoticeOverlayState();
}

class _AppNoticeOverlayState extends State<_AppNoticeOverlay>
    with SingleTickerProviderStateMixin {
  final Key _dismissibleKey = UniqueKey();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 140),
  );
  Timer? _dismissTimer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _dismissTimer = Timer(widget.duration, dismiss);
  }

  Future<void> dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    await _controller.reverse();
    widget.onRemoved();
  }

  void _dismissFromSwipe(DismissDirection _) {
    if (_dismissing) return;
    _dismissing = true;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    widget.onRemoved();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final bottom = mediaQuery.viewInsets.bottom > 0
        ? mediaQuery.viewInsets.bottom + 18
        : mediaQuery.padding.bottom + 18;
    final icon = switch (widget.tone) {
      AppNoticeTone.info => Icons.info_outline_rounded,
      AppNoticeTone.success => Icons.check_circle_outline_rounded,
      AppNoticeTone.warning => Icons.warning_amber_rounded,
      AppNoticeTone.error => Icons.error_outline_rounded,
    };

    return Positioned(
      left: 18,
      right: 18,
      bottom: bottom,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, .3),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: Dismissible(
              key: _dismissibleKey,
              direction: DismissDirection.horizontal,
              dismissThresholds: const {
                DismissDirection.startToEnd: .28,
                DismissDirection.endToStart: .28,
              },
              movementDuration: const Duration(milliseconds: 170),
              resizeDuration: null,
              onDismissed: _dismissFromSwipe,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Material(
                  color: cs.inverseSurface,
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                      child: Row(
                        children: [
                          Icon(icon, color: cs.onInverseSurface, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.message,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onInverseSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (widget.actionLabel != null &&
                              widget.onAction != null) ...[
                            const SizedBox(width: 6),
                            TextButton(
                              onPressed: () {
                                final action = widget.onAction!;
                                AppNotice.dismiss();
                                action();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: cs.inversePrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(widget.actionLabel!),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
