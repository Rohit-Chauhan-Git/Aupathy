import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/app_settings.dart';
import '../../theme/app_theme.dart';

class ReaderPalette {
  const ReaderPalette({
    required this.background,
    required this.surface,
    required this.text,
    required this.secondaryText,
    required this.border,
    required this.accent,
    required this.link,
    required this.isDark,
  });

  final Color background;
  final Color surface;
  final Color text;
  final Color secondaryText;
  final Color border;
  final Color accent;
  final Color link;
  final bool isDark;

  static const Map<String, ReaderPalette> _palettes = <String, ReaderPalette>{
    'dark': ReaderPalette(
      background: Color(0xFF090E17),
      surface: Color(0xFF111A2A),
      text: Color(0xFFE9E6DE),
      secondaryText: Color(0xFFA7B1C2),
      border: Color(0xFF26344B),
      accent: AppColors.indigoBright,
      link: Color(0xFF93C5FD),
      isDark: true,
    ),
    'light': ReaderPalette(
      background: Color(0xFFFAF8F3),
      surface: Color(0xFFFFFFFF),
      text: Color(0xFF1D2733),
      secondaryText: Color(0xFF64748B),
      border: Color(0xFFD8DEE7),
      accent: AppColors.indigoDeep,
      link: Color(0xFF1D4ED8),
      isDark: false,
    ),
    'sepia': ReaderPalette(
      background: Color(0xFFF1E6D2),
      surface: Color(0xFFF8F0E2),
      text: Color(0xFF433525),
      secondaryText: Color(0xFF7A6650),
      border: Color(0xFFD9C6AA),
      accent: Color(0xFF9A5B2E),
      link: Color(0xFF8A451A),
      isDark: false,
    ),
  };

  static ReaderPalette resolve(String theme) {
    return _palettes[theme] ?? _palettes['dark']!;
  }

  SystemUiOverlayStyle get overlayStyle {
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: background,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );
  }
}

abstract final class ReaderFonts {
  static const String lora = 'lora';
  static const String nunito = 'nunito';
  static const String system = 'system';

  static String resolveFamily(String value) {
    return switch (value) {
      nunito => AppFonts.body,
      system => '',
      _ => AppFonts.display,
    };
  }

  static List<String>? fallbackFor(String value) {
    return switch (value) {
      nunito => AppFonts.bodyFallback,
      system => null,
      _ => AppFonts.displayFallback,
    };
  }

  static String label(String value) {
    return switch (value) {
      nunito => 'Nunito',
      system => 'System',
      _ => 'Lora',
    };
  }
}

abstract final class ReaderThemeValues {
  static const String dark = 'dark';
  static const String light = 'light';
  static const String sepia = 'sepia';

  static const List<String> all = <String>[dark, light, sepia];

  static String label(String value) {
    return switch (value) {
      light => 'Light',
      sepia => 'Sepia',
      _ => 'Dark',
    };
  }
}

TextStyle readerTextStyle(AppSettings settings, ReaderPalette palette) {
  final family = ReaderFonts.resolveFamily(settings.fontFamily);
  return TextStyle(
    fontFamily: family.isEmpty ? null : family,
    fontFamilyFallback: ReaderFonts.fallbackFor(settings.fontFamily),
    fontSize: settings.fontSize,
    height: settings.lineHeight,
    color: palette.text,
    letterSpacing: 0.05,
  );
}

TextAlign readerTextAlign(AppSettings settings) {
  return settings.readerTextAlign == 'justify'
      ? TextAlign.justify
      : TextAlign.left;
}
