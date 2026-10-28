import 'package:flutter/material.dart';

/// Central color palette for the dark slate/blue reading experience.
abstract final class AppColors {
  static const Color deepNavy = Color(0xFF070B14);
  static const Color navy = Color(0xFF0B1220);
  static const Color navyElevated = Color(0xFF0E1728);
  static const Color card = Color(0xFF121C30);
  static const Color cardElevated = Color(0xFF18243C);
  static const Color border = Color(0xFF22304D);

  static const Color indigo = Color(0xFF6366F1);
  static const Color indigoBright = Color(0xFF818CF8);
  static const Color indigoDeep = Color(0xFF4F46E5);
  static const Color blue = Color(0xFF3B82F6);
  static const Color blueBright = Color(0xFF60A5FA);
  static const Color violet = Color(0xFF8B5CF6);

  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);

  static const Color error = Color(0xFFF87171);
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
}

/// Font families used across the app. Reading surfaces favor Lora, UI copy
/// uses Nunito, and metadata/code surfaces use Mono.
abstract final class AppFonts {
  static const String display = 'Lora';
  static const String body = 'Nunito';
  static const String mono = 'Mono';

  static const List<String> displayFallback = <String>['Georgia', 'serif'];
  static const List<String> bodyFallback = <String>[
    'Roboto',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];
  static const List<String> monoFallback = <String>[
    'JetBrains Mono',
    'Roboto Mono',
    'Courier New',
    'monospace',
  ];
}

/// Reusable gradients for hero cards, primary actions, and accent surfaces.
abstract final class AppGradients {
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.indigo, AppColors.blue],
  );

  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.violet, AppColors.indigo, AppColors.blueBright],
  );

  static const LinearGradient card = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.cardElevated, AppColors.card],
  );

  static const LinearGradient cardHighlight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF1E2B47), AppColors.card],
  );
}

/// Theme extension exposing gradients and typography that [ThemeData] cannot
/// represent directly.
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.primaryGradient,
    required this.accentGradient,
    required this.cardGradient,
    required this.monoStyle,
  });

  final LinearGradient primaryGradient;
  final LinearGradient accentGradient;
  final LinearGradient cardGradient;
  final TextStyle monoStyle;

  @override
  AppThemeExtension copyWith({
    LinearGradient? primaryGradient,
    LinearGradient? accentGradient,
    LinearGradient? cardGradient,
    TextStyle? monoStyle,
  }) {
    return AppThemeExtension(
      primaryGradient: primaryGradient ?? this.primaryGradient,
      accentGradient: accentGradient ?? this.accentGradient,
      cardGradient: cardGradient ?? this.cardGradient,
      monoStyle: monoStyle ?? this.monoStyle,
    );
  }

  @override
  AppThemeExtension lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      primaryGradient: LinearGradient.lerp(
        primaryGradient,
        other.primaryGradient,
        t,
      )!,
      accentGradient: LinearGradient.lerp(
        accentGradient,
        other.accentGradient,
        t,
      )!,
      cardGradient: LinearGradient.lerp(cardGradient, other.cardGradient, t)!,
      monoStyle: TextStyle.lerp(monoStyle, other.monoStyle, t)!,
    );
  }
}

abstract final class AppTheme {
  static const double minTextScale = 0.85;
  static const double maxTextScale = 2.0;

  static const ColorScheme darkColorScheme = ColorScheme.dark(
    primary: AppColors.indigo,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF312E81),
    onPrimaryContainer: Color(0xFFE0E7FF),
    secondary: AppColors.blue,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFF1E3A8A),
    onSecondaryContainer: Color(0xFFDBEAFE),
    tertiary: AppColors.violet,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFF4C1D95),
    onTertiaryContainer: Color(0xFFEDE9FE),
    error: AppColors.error,
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFEE2E2),
    surface: AppColors.navy,
    onSurface: AppColors.slate100,
    surfaceDim: AppColors.deepNavy,
    surfaceBright: Color(0xFF1B2942),
    surfaceContainerLowest: AppColors.deepNavy,
    surfaceContainerLow: AppColors.navyElevated,
    surfaceContainer: AppColors.card,
    surfaceContainerHigh: AppColors.cardElevated,
    surfaceContainerHighest: Color(0xFF1E2B47),
    onSurfaceVariant: AppColors.slate400,
    outline: AppColors.slate600,
    outlineVariant: AppColors.border,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColors.slate200,
    onInverseSurface: AppColors.deepNavy,
    inversePrimary: AppColors.indigoDeep,
    surfaceTint: AppColors.indigo,
  );

  static const ColorScheme highContrastColorScheme = ColorScheme.dark(
    primary: Color(0xFFA5B4FC),
    onPrimary: Color(0xFF050914),
    primaryContainer: Color(0xFF4338CA),
    onPrimaryContainer: Colors.white,
    secondary: Color(0xFF93C5FD),
    onSecondary: Color(0xFF050914),
    secondaryContainer: Color(0xFF1D4ED8),
    onSecondaryContainer: Colors.white,
    tertiary: Color(0xFFC4B5FD),
    onTertiary: Color(0xFF050914),
    tertiaryContainer: Color(0xFF6D28D9),
    onTertiaryContainer: Colors.white,
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Colors.white,
    surface: Color(0xFF05080F),
    onSurface: Colors.white,
    surfaceDim: Color(0xFF03060C),
    surfaceBright: Color(0xFF26344D),
    surfaceContainerLowest: Color(0xFF03060C),
    surfaceContainerLow: Color(0xFF0A111D),
    surfaceContainer: Color(0xFF101A2B),
    surfaceContainerHigh: Color(0xFF172238),
    surfaceContainerHighest: Color(0xFF1F2D47),
    onSurfaceVariant: Color(0xFFD6DEEB),
    outline: Color(0xFF93A4C2),
    outlineVariant: Color(0xFF64748B),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Colors.white,
    onInverseSurface: Color(0xFF05080F),
    inversePrimary: Color(0xFF4338CA),
    surfaceTint: Color(0xFFA5B4FC),
  );

  static ThemeData get darkTheme => build();

  static ThemeData get highContrastDarkTheme => build(highContrast: true);

  /// Wraps the app in a text scaler that respects accessibility settings while
  /// avoiding layouts that become unusable at extreme scale factors.
  static Widget textScaleBuilder(BuildContext context, Widget? child) {
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: minTextScale,
      maxScaleFactor: maxTextScale,
      child: child ?? const SizedBox.shrink(),
    );
  }

  static ThemeData build({bool highContrast = false}) {
    final scheme = highContrast ? highContrastColorScheme : darkColorScheme;
    final textTheme = _textTheme(scheme);
    const radius = BorderRadius.all(Radius.circular(16));

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceDim,
      canvasColor: scheme.surface,
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.bodyFallback,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceDim,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
        actionsIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 24,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: highContrast ? 0.6 : 0.35),
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      primaryIconTheme: IconThemeData(color: scheme.onPrimary, size: 22),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHigh,
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: textTheme.labelLarge,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primary.withValues(alpha: 0.2),
        disabledColor: scheme.surfaceContainer,
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
        ),
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primary.withValues(
          alpha: highContrast ? 0.3 : 0.18,
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        selectedLabelStyle: textTheme.labelMedium,
        unselectedLabelStyle: textTheme.labelMedium,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        modalBackgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: 0.6),
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
        actionTextColor: scheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: scheme.onSurface,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppThemeExtension(
          primaryGradient: AppGradients.primary,
          accentGradient: AppGradients.accent,
          cardGradient: AppGradients.card,
          monoStyle:
              textTheme.labelSmall ??
              const TextStyle(fontFamily: AppFonts.mono),
        ),
      ],
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;

    TextStyle display(double size, FontWeight weight, double height) {
      return TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.displayFallback,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: -0.4,
        color: onSurface,
      );
    }

    TextStyle sans(double size, FontWeight weight, double height) {
      return TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: onSurface,
      );
    }

    return TextTheme(
      displayLarge: display(57, FontWeight.w600, 1.1),
      displayMedium: display(45, FontWeight.w600, 1.15),
      displaySmall: display(36, FontWeight.w600, 1.2),
      headlineLarge: display(32, FontWeight.w600, 1.25),
      headlineMedium: display(28, FontWeight.w600, 1.3),
      headlineSmall: display(24, FontWeight.w600, 1.3),
      titleLarge: display(22, FontWeight.w600, 1.3),
      titleMedium: display(18, FontWeight.w600, 1.35),
      titleSmall: sans(16, FontWeight.w700, 1.35),
      bodyLarge: sans(17, FontWeight.w400, 1.6),
      bodyMedium: sans(15, FontWeight.w400, 1.55),
      bodySmall: sans(
        13,
        FontWeight.w400,
        1.5,
      ).copyWith(color: onSurfaceVariant),
      labelLarge: sans(15, FontWeight.w700, 1.2),
      labelMedium: sans(
        13,
        FontWeight.w600,
        1.2,
      ).copyWith(color: onSurfaceVariant),
      labelSmall: TextStyle(
        fontFamily: AppFonts.mono,
        fontFamilyFallback: AppFonts.monoFallback,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.5,
        color: onSurfaceVariant,
      ),
    );
  }
}
