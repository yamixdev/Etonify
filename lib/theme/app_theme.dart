import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:meow_client/theme/predictive_back_page_transitions.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Theme extensions
// ---------------------------------------------------------------------------

class ConnectionButtonTheme extends ThemeExtension<ConnectionButtonTheme> {
  const ConnectionButtonTheme({this.idleColor, this.connectedColor});

  final Color? idleColor;
  final Color? connectedColor;

  static const light = ConnectionButtonTheme(
    idleColor: Color(0xFF2D5BFF),
    connectedColor: Color(0xFF0F9D58),
  );

  static const dark = ConnectionButtonTheme(
    idleColor: Color(0xFF6B8AFF),
    connectedColor: Color(0xFF34D399),
  );

  @override
  ThemeExtension<ConnectionButtonTheme> copyWith({
    Color? idleColor,
    Color? connectedColor,
  }) {
    return ConnectionButtonTheme(
      idleColor: idleColor ?? this.idleColor,
      connectedColor: connectedColor ?? this.connectedColor,
    );
  }

  @override
  ThemeExtension<ConnectionButtonTheme> lerp(
    covariant ThemeExtension<ConnectionButtonTheme>? other,
    double t,
  ) {
    if (other is! ConnectionButtonTheme) return this;
    return ConnectionButtonTheme(
      idleColor: Color.lerp(idleColor, other.idleColor, t),
      connectedColor: Color.lerp(connectedColor, other.connectedColor, t),
    );
  }
}

class AppSurfaceTheme extends ThemeExtension<AppSurfaceTheme> {
  const AppSurfaceTheme({
    required this.smallRadius,
    required this.mediumRadius,
    required this.largeRadius,
    required this.tilePadding,
    required this.sectionPadding,
  });

  final double smallRadius;
  final double mediumRadius;
  final double largeRadius;
  final EdgeInsets tilePadding;
  final EdgeInsets sectionPadding;

  static const standard = AppSurfaceTheme(
    smallRadius: 16,
    mediumRadius: 22,
    largeRadius: 28,
    tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    sectionPadding: EdgeInsets.fromLTRB(14, 8, 14, 20),
  );

  BorderRadius get small => BorderRadius.circular(smallRadius);

  @override
  ThemeExtension<AppSurfaceTheme> copyWith({
    double? smallRadius,
    double? mediumRadius,
    double? largeRadius,
    EdgeInsets? tilePadding,
    EdgeInsets? sectionPadding,
  }) {
    return AppSurfaceTheme(
      smallRadius: smallRadius ?? this.smallRadius,
      mediumRadius: mediumRadius ?? this.mediumRadius,
      largeRadius: largeRadius ?? this.largeRadius,
      tilePadding: tilePadding ?? this.tilePadding,
      sectionPadding: sectionPadding ?? this.sectionPadding,
    );
  }

  @override
  ThemeExtension<AppSurfaceTheme> lerp(
    covariant ThemeExtension<AppSurfaceTheme>? other,
    double t,
  ) {
    if (other is! AppSurfaceTheme) return this;
    return AppSurfaceTheme(
      smallRadius: lerpDouble(smallRadius, other.smallRadius, t) ?? smallRadius,
      mediumRadius:
          lerpDouble(mediumRadius, other.mediumRadius, t) ?? mediumRadius,
      largeRadius: lerpDouble(largeRadius, other.largeRadius, t) ?? largeRadius,
      tilePadding:
          EdgeInsets.lerp(tilePadding, other.tilePadding, t) ?? tilePadding,
      sectionPadding:
          EdgeInsets.lerp(sectionPadding, other.sectionPadding, t) ??
          sectionPadding,
    );
  }
}

// ---------------------------------------------------------------------------
// Theme builder
// ---------------------------------------------------------------------------

ThemeData buildAppTheme(
  Brightness brightness, {
  Color? seedColor,
  ColorScheme? dynamicLightScheme,
  ColorScheme? dynamicDarkScheme,
}) {
  final isDark = brightness == Brightness.dark;
  final effectiveSeed = seedColor ?? const Color(0xFF6750A4);
  final dynamicScheme = isDark ? dynamicDarkScheme : dynamicLightScheme;
  final generatedScheme = ColorScheme.fromSeed(
    seedColor: effectiveSeed,
    brightness: brightness,
  );
  final baseScheme = dynamicScheme ?? generatedScheme;

  final scheme = isDark
      ? baseScheme.copyWith(
          surface: const Color(0xFF1A1C1E),
          surfaceContainerLow: const Color(0xFF1E2022),
          surfaceContainer: const Color(0xFF232528),
          surfaceContainerHigh: const Color(0xFF2C2E31),
          surfaceContainerHighest: const Color(0xFF363839),
          secondaryContainer: dynamicScheme == null
              ? const Color(0xFF2E3548)
              : baseScheme.secondaryContainer,
          onSecondaryContainer: dynamicScheme == null
              ? Colors.white
              : baseScheme.onSecondaryContainer,
          outlineVariant: const Color(0xFF464849),
        )
      : baseScheme.copyWith(
          secondaryContainer: dynamicScheme == null
              ? const Color(0xFFDEE3F0)
              : baseScheme.secondaryContainer,
          onSecondaryContainer: dynamicScheme == null
              ? const Color(0xFF1A2744)
              : baseScheme.onSecondaryContainer,
        );

  const surfaces = AppSurfaceTheme.standard;

  final baseTextTheme = isDark
      ? Typography.material2021().white
      : Typography.material2021().black;

  final textTheme = baseTextTheme.copyWith(
    titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: baseTextTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    titleSmall: baseTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    bodyMedium: baseTextTheme.bodyMedium?.copyWith(height: 1.3),
    bodySmall: baseTextTheme.bodySmall?.copyWith(height: 1.35),
    labelLarge: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  );

  final outlineColor = scheme.outlineVariant.withValues(alpha: 0.42);
  final filledColor = scheme.surfaceContainerHighest.withValues(alpha: 0.55);

  final pressedOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.pressed)) {
      return scheme.primary.withValues(alpha: 0.18);
    }
    if (states.contains(WidgetState.hovered)) {
      return scheme.primary.withValues(alpha: 0.10);
    }
    if (states.contains(WidgetState.focused)) {
      return scheme.primary.withValues(alpha: 0.14);
    }
    return null;
  });

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    textTheme: textTheme,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: EtonifyPredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: _EtonifySlidePageTransitionsBuilder(),
        TargetPlatform.macOS: _EtonifySlidePageTransitionsBuilder(),
        TargetPlatform.linux: _EtonifySlidePageTransitionsBuilder(),
        TargetPlatform.windows: _EtonifySlidePageTransitionsBuilder(),
      },
    ),
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(surfaces.mediumRadius),
        side: BorderSide(color: outlineColor),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: surfaces.tilePadding,
      iconColor: scheme.onSurfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(surfaces.mediumRadius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: filledColor,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(surfaces.smallRadius),
        borderSide: BorderSide(color: outlineColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(surfaces.smallRadius),
        borderSide: BorderSide(color: outlineColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(surfaces.smallRadius),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(surfaces.smallRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: textTheme.labelLarge,
      ).copyWith(overlayColor: pressedOverlay),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(surfaces.smallRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: BorderSide(color: outlineColor),
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(surfaces.smallRadius),
        ),
      ).copyWith(overlayColor: pressedOverlay),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        visualDensity: VisualDensity.comfortable,
        side: WidgetStatePropertyAll(BorderSide(color: outlineColor)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
          size: 24,
        );
      }),
    ),
    extensions: [
      isDark ? ConnectionButtonTheme.dark : ConnectionButtonTheme.light,
      AppSurfaceTheme.standard,
    ],
  );
}

// ---------------------------------------------------------------------------
// AMOLED theme — pure-black surface variant of the dark theme
// ---------------------------------------------------------------------------

ThemeData buildAmoledTheme({
  Color? seedColor,
  ColorScheme? dynamicLightScheme,
  ColorScheme? dynamicDarkScheme,
}) {
  final base = buildAppTheme(
    Brightness.dark,
    seedColor: seedColor,
    dynamicLightScheme: dynamicLightScheme,
    dynamicDarkScheme: dynamicDarkScheme,
  );
  final amoledScheme = base.colorScheme.copyWith(
    surface: Colors.black,
    surfaceContainerLow: const Color(0xFF080808),
    surfaceContainer: const Color(0xFF0D0D0D),
    surfaceContainerHigh: const Color(0xFF111111),
    surfaceContainerHighest: const Color(0xFF161616),
    secondaryContainer: const Color(0xFF0F0F1E),
    outlineVariant: const Color(0xFF252525),
  );
  return base.copyWith(
    colorScheme: amoledScheme,
    scaffoldBackgroundColor: Colors.black,
    canvasColor: Colors.black,
    appBarTheme: base.appBarTheme.copyWith(
      systemOverlayStyle: base.appBarTheme.systemOverlayStyle?.copyWith(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: Colors.black,
    ),
    cardTheme: base.cardTheme.copyWith(color: const Color(0xFF0D0D0D)),
  );
}

class _EtonifySlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _EtonifySlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final primary = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final secondary = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(primary),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.028, 0),
          end: Offset.zero,
        ).animate(primary),
        child: AnimatedBuilder(
          animation: secondary,
          child: child,
          builder: (context, child) {
            return Transform.scale(
              scale: 1 - (secondary.value * 0.012),
              child: child,
            );
          },
        ),
      ),
    );
  }
}
