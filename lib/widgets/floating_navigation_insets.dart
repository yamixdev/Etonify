import 'package:flutter/widgets.dart';

class FloatingNavigationInsets extends InheritedWidget {
  const FloatingNavigationInsets({
    super.key,
    required this.bottom,
    required super.child,
  });

  final double bottom;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<FloatingNavigationInsets>()
          ?.bottom ??
      0;

  @override
  bool updateShouldNotify(FloatingNavigationInsets oldWidget) =>
      bottom != oldWidget.bottom;
}
