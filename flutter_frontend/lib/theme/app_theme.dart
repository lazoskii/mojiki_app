import 'package:flutter/material.dart';

// Cores e tema do Mojiki num lugar só. Antes cada tela repetia o gradiente
// e os diálogos usavam o tema padrão (branco), destoando do resto do app.
class AppColors {
  static const vermelho = Color(0xFFDC2626);
  static const vermelhoEscuro = Color(0xFF991B1B);
  static const verde = Color(0xFF16A34A);
  static const amarelo = Color(0xFFFACC15);

  // fundo dos diálogos/bottom sheets: quase preto puxado pro vermelho
  static const superficie = Color(0xFF1F1414);

  // gradiente de fundo de todas as telas
  static const fundo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [vermelho, vermelhoEscuro, Colors.black],
  );
}

ThemeData criarTemaMojiki() {
  final esquema = ColorScheme.fromSeed(
    seedColor: AppColors.vermelho,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.vermelho,
    onPrimary: Colors.white,
    surface: AppColors.superficie,
    onSurface: Colors.white,
  );

  final borda = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
  );

  return ThemeData(
    colorScheme: esquema,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.black,
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      titleTextStyle: const TextStyle(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
      contentTextStyle: const TextStyle(color: Colors.white70, fontSize: 14),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.superficie,
      showDragHandle: true,
      dragHandleColor: Colors.white24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF2A1A1A),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.vermelho,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Colors.white70),
    ),
    // campos dos diálogos (editar card, renomear deck, feedback)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      labelStyle: const TextStyle(color: Colors.white60),
      hintStyle: const TextStyle(color: Colors.white38),
      border: borda,
      enabledBorder: borda,
      focusedBorder: borda.copyWith(
          borderSide: const BorderSide(color: AppColors.vermelho, width: 1.5)),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: Colors.white,
      iconColor: Colors.white70,
    ),
  );
}
