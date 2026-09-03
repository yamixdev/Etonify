import 'package:flutter/material.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/etonify_logo_badge.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({
    super.key,
    required this.onContinue,
    required this.brandName,
    required this.versionLabel,
  });

  final VoidCallback onContinue;
  final String brandName;
  final String versionLabel;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _scale = Tween<double>(begin: .98, end: 1).animate(curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _continue,
      child: Scaffold(
        body: ColoredBox(
          color: isDark ? const Color(0xFF101113) : cs.surface,
          child: SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _opacity,
                child: ScaleTransition(
                  scale: _scale,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const EtonifyLogoBadge(size: 124, logoSize: 48),
                        const SizedBox(height: 28),
                        Text(
                          widget.brandName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            height: 1,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.welcomeSubtitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          l10n.welcomeTapHint,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'v${widget.versionLabel}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: .72),
                          ),
                        ),
                      ],
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
