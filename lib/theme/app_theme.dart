import 'package:flutter/material.dart';

class AppTheme {
  // Cores Base - Tema Claro
  static const Color primaryLight = Color(0xFF0061A4);
  static const Color bgLight = Color(0xFFF1F5F9);
  static const Color surfaceLight = Colors.white;

  // Cores Base - Tema Escuro (Tons de Ardósia/Slate Premium)
  static const Color primaryDark = Color(
    0xFF60A5FA,
  ); // Azul mais suave para contraste
  static const Color bgDark = Color(0xFF0F172A); // Fundo muito escuro
  static const Color surfaceDark = Color(
    0xFF1E293B,
  ); // Cartões ligeiramente mais claros

  // Tema Claro de Elite
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryLight,
        brightness: Brightness.light,
        surface: bgLight,
      ),
      scaffoldBackgroundColor: bgLight,
      cardTheme: _cardTheme(surfaceLight, Colors.grey[200]!),
      appBarTheme: _appBarTheme(primaryLight, Colors.white),
      elevatedButtonTheme: _buttonTheme(primaryLight, Colors.white),
      inputDecorationTheme: _inputTheme(Colors.white, Colors.grey[300]!),
      bottomSheetTheme: _bottomSheetTheme(surfaceLight),
      dialogTheme: _dialogTheme(surfaceLight),
      dividerTheme: DividerThemeData(color: Colors.grey[300], thickness: 1),
    );
  }

  // Tema Escuro de Elite
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryDark,
        brightness: Brightness.dark,
        surface: bgDark,
      ),
      scaffoldBackgroundColor: bgDark,
      cardTheme: _cardTheme(surfaceDark, const Color(0xFF334155)),
      appBarTheme: _appBarTheme(
        surfaceDark,
        Colors.white,
      ), // AppBar mescla com a superfície no Dark
      elevatedButtonTheme: _buttonTheme(primaryDark, bgDark),
      inputDecorationTheme: _inputTheme(bgDark, const Color(0xFF334155)),
      bottomSheetTheme: _bottomSheetTheme(surfaceDark),
      dialogTheme: _dialogTheme(surfaceDark),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
      ),
    );
  }

  // --- COMPONENTES REFINADOS ---
  static AppBarTheme _appBarTheme(Color bg, Color fg) => AppBarTheme(
    backgroundColor: bg,
    foregroundColor: fg,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
  );

  static CardThemeData _cardTheme(Color bg, Color borderColor) => CardThemeData(
    color: bg,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: borderColor, width: 1),
    ),
  );

  static ElevatedButtonThemeData _buttonTheme(Color bg, Color fg) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );

  static InputDecorationTheme _inputTheme(Color fill, Color border) =>
      InputDecorationTheme(
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
        contentPadding: const EdgeInsets.all(20),
      );

  static BottomSheetThemeData _bottomSheetTheme(Color bg) =>
      BottomSheetThemeData(
        backgroundColor: bg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      );

  static DialogThemeData _dialogTheme(Color bg) => DialogThemeData(
    backgroundColor: bg,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  );
}
