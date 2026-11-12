import 'package:material_ui/material_ui.dart';

const appNavigationBarVisualHeight = 80.0;
const appHeaderBlurHeight = 2.0;
const appHeaderContentGap = 36.0;

double appSystemStatusBarInset(BuildContext context) {
  return MediaQuery.viewPaddingOf(context).top;
}

double appSystemNavigationBarInset(BuildContext context) {
  final viewPadding = MediaQuery.viewPaddingOf(context).bottom;
  final padding = MediaQuery.paddingOf(context).bottom;
  return viewPadding > padding ? viewPadding : padding;
}

double appBottomSafePadding(BuildContext context, double fallback) {
  return appSystemNavigationBarInset(context) + fallback;
}

double appBottomNavigationTotalHeight(BuildContext context) {
  return appNavigationBarVisualHeight + appSystemNavigationBarInset(context);
}

double appHeaderBlurTotalHeight(BuildContext context) {
  return appSystemStatusBarInset(context) +
      kToolbarHeight +
      appHeaderBlurHeight;
}

double progressiveHeaderTopPadding(BuildContext context, double fallback) {
  return fallback;
}

class ProgressiveBlurScaffold extends StatelessWidget {
  const ProgressiveBlurScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaffoldColor = backgroundColor ?? theme.scaffoldBackgroundColor;
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      body: ColoredBox(color: scaffoldColor, child: body),
    );
  }
}

class AppProgressiveHeaderBlur extends StatelessWidget {
  const AppProgressiveHeaderBlur({
    super.key,
    required this.headerHeight,
    required this.child,
    this.sigma = 22,
    this.tintColor = Colors.transparent,
  });

  final double headerHeight;
  final Widget child;
  final double sigma;
  final Color tintColor;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class AppProgressiveEdgeBlur extends StatelessWidget {
  const AppProgressiveEdgeBlur({
    super.key,
    required this.enabled,
    required this.child,
    this.headerHeight = 0,
    this.footerHeight = 0,
    this.sigma = 24,
    this.tintColor = Colors.transparent,
  });

  final bool enabled;
  final Widget child;
  final double headerHeight;
  final double footerHeight;
  final double sigma;
  final Color tintColor;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
