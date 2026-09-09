// lib/config/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color bg = Color(0xFF080B14);
  static const Color surface = Color(0xFF0F1320);
  static const Color surface2 = Color(0xFF141929);
  static const Color border = Color(0xFF1E2438);
  static const Color border2 = Color(0xFF252D45);
  static const Color accent = Color(0xFF5B4BFF);
  static const Color accentH = Color(0xFF7265FF);
  static const Color accent2 = Color(0xFF00D4AA);
  static const Color textPrim = Color(0xFFE8EAF6);
  static const Color textSec = Color(0xFFA0A8C8);
  static const Color muted = Color(0xFF5A6285);
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent2,
        surface: surface,
        error: danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textPrim,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: textPrim),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: danger),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrim),
        bodyMedium: TextStyle(color: textSec),
        bodySmall: TextStyle(color: muted),
        headlineLarge: TextStyle(color: textPrim, fontWeight: FontWeight.w900),
        headlineMedium: TextStyle(color: textPrim, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(color: textPrim, fontWeight: FontWeight.w700),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF6F8FF),
      colorScheme: const ColorScheme.light(
        primary: accent,
        secondary: accent2,
        surface: Colors.white,
        error: danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F8FF),
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Color(0xFF111827),
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: Color(0xFF111827)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F3FF),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD5DDEF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD5DDEF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: danger),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF111827)),
        bodyMedium: TextStyle(color: Color(0xFF475569)),
        bodySmall: TextStyle(color: Color(0xFF64748B)),
        headlineLarge:
            TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w900),
        headlineMedium:
            TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w800),
        titleLarge:
            TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700),
      ),
    );
  }
}
