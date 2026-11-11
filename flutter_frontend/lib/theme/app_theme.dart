import 'package:flutter/material.dart';

// Paleta "Washi" (escolhida na proposta visual): fundo papel off-white,
// cards brancos e o vermelho só nos destaques — botão principal, item
// ativo, progresso. Lembra a bandeira do Japão (vermelho no branco).
// Antes o app inteiro era um gradiente vermelho forte com texto branco.
class AppColors {
  // base
  static const fundo = Color(0xFFF7F3F1); // papel
  static const superficie = Colors.white; // cards, painéis, campos
  static const linha = Color(0xFFECE4E1); // bordas e divisórias
  static const bordaCampo = Color(0xFFE2D8D5); // borda das caixas de texto

  // texto
  static const texto = Color(0xFF1F1A1A);
  static const textoSuave = Color(0xFF6E6361); // contraste >= 4.5 no fundo
  static const textoFraco = Color(0xFF9A8F8C); // só pra ícones/placeholder

  // vermelho (menos saturado que o #DC2626 de antes)
  static const vermelho = Color(0xFFD1283A);
  static const vermelhoEscuro = Color(0xFFA81E2D); // texto vermelho em fundo claro
  static const vermelhoClaro = Color(0xFFFCE9EB); // fundos de destaque suaves

  // estados
  static const verde = Color(0xFF1F7A45); // acerto
  static const verdeClaro = Color(0xFFE6F4EC);
  static const erro = Color(0xFFB42318); // erro de formulário (com ícone)
  static const amarelo = Color(0xFFD9A400); // XP / nível
  static const laranja = Color(0xFFE8590C); // sequência de dias
}

// Sombra suave usada nos cards de destaque
const sombraSuave = [
  BoxShadow(color: Color(0x141F1A1A), blurRadius: 24, offset: Offset(0, 10)),
];

// Card branco com borda fina — o "container" padrão das telas
BoxDecoration cardDecoration({double raio = 18, Color? cor}) => BoxDecoration(
      color: cor ?? AppColors.superficie,
      borderRadius: BorderRadius.circular(raio),
      border: Border.all(color: AppColors.linha),
    );

ThemeData criarTemaMojiki() {
  final esquema = ColorScheme.fromSeed(
    seedColor: AppColors.vermelho,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.vermelho,
    onPrimary: Colors.white,
    secondary: AppColors.vermelhoEscuro,
    surface: AppColors.superficie,
    onSurface: AppColors.texto,
    error: AppColors.erro,
    outline: AppColors.bordaCampo,
  );

  OutlineInputBorder borda(Color cor, [double largura = 1.5]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cor, width: largura),
      );

  final formaBotao =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  const textoBotao = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: AppColors.fundo,
    textTheme: ThemeData.light().textTheme.apply(
          bodyColor: AppColors.texto,
          displayColor: AppColors.texto,
        ),
    iconTheme: const IconThemeData(color: AppColors.texto),

    // Caixas de texto: 52 px de altura, borda bege, vermelha no foco,
    // vermelho-escuro com erro. O rótulo fica EM CIMA (ver AppCampo).
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.superficie,
      hintStyle: const TextStyle(color: AppColors.textoFraco),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: borda(AppColors.bordaCampo),
      enabledBorder: borda(AppColors.bordaCampo),
      focusedBorder: borda(AppColors.vermelho, 2),
      errorBorder: borda(AppColors.erro),
      focusedErrorBorder: borda(AppColors.erro, 2),
      prefixIconColor: AppColors.textoSuave,
      suffixIconColor: AppColors.textoSuave,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.vermelho,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 52),
        shape: formaBotao,
        textStyle: textoBotao,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.vermelho,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(64, 52),
        shape: formaBotao,
        textStyle: textoBotao,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.texto,
        backgroundColor: AppColors.superficie,
        minimumSize: const Size(64, 52),
        side: const BorderSide(color: AppColors.bordaCampo, width: 1.5),
        shape: formaBotao,
        textStyle: textoBotao,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.vermelhoEscuro,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(
          color: AppColors.texto, fontSize: 20, fontWeight: FontWeight.w700),
      contentTextStyle:
          const TextStyle(color: AppColors.textoSuave, fontSize: 15, height: 1.4),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.superficie,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Color(0xFFD9CFCC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.texto,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),

    // Barra de navegação de baixo (Decks · Estudar · Progresso)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.superficie,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.vermelhoClaro,
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith((estados) => IconThemeData(
            color: estados.contains(WidgetState.selected)
                ? AppColors.vermelho
                : AppColors.textoSuave,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((estados) => TextStyle(
            fontSize: 12,
            fontWeight: estados.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: estados.contains(WidgetState.selected)
                ? AppColors.vermelho
                : AppColors.textoSuave,
          )),
    ),

    listTileTheme: const ListTileThemeData(
      textColor: AppColors.texto,
      iconColor: AppColors.textoSuave,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.vermelho,
      linearTrackColor: AppColors.linha,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.linha, space: 1),
  );
}
