// Identidade visual da KUSSUMBA: as mesmas cores, medidas e letra da versão web
// (css/tokens.css), retiradas das telas de referência do projecto.

import 'package:flutter/material.dart';

abstract final class Cores {
  // Superfícies
  static const fundo = Color(0xFFF6F3EE);
  static const superficie = Color(0xFFFFFFFF);
  static const superficie2 = Color(0xFFF6F3EE);
  static const borda = Color(0xFFE7E3DC);
  static const bordaForte = Color(0xFFD9D3C8);
  static const tracejado = Color(0xFF9DB5A9);
  static const marcador = Color(0xFF858B85); // texto de exemplo em campos vazios: 3:1 no mínimo
  static const trilho = Color(0xFFECE7DE);

  // Texto
  static const tinta = Color(0xFF1F2421);
  static const tinta2 = Color(0xFF5E6660);

  // Marca
  static const verde = Color(0xFF1E6B52);
  static const verdePremido = Color(0xFF185A45);
  static const verdeSuave = Color(0xFFE1EFE8);
  static const verdeTinta = Color(0xFF154D3B);

  // Estados
  static const alertaFundo = Color(0xFFFDF0E1);
  static const alertaBorda = Color(0xFFF2D8B9);
  static const alertaTinta = Color(0xFF7A3E06);
  static const subida = Color(0xFF8A3B12);
  static const descida = Color(0xFF1D4E89);

  // Ícones de produto
  static const iconeFundo = Color(0xFFF3E7D3);
  static const iconeTraco = Color(0xFF7A4A12);

  static const veu = Color(0x731F2421); // fundo escurecido atrás dos diálogos
}

abstract final class Medidas {
  static const raio = 16.0;
  static const raioPequeno = 12.0;
  static const margem = 20.0;
  static const toque = 48.0;
  static const alturaNav = 72.0;
  static const larguraMaxima = 480.0;
}

const String fonte = 'DM Sans';

abstract final class Letra {
  static const meta = 14.0;
  static const corpo = 16.0;
  static const destaque = 17.0;
  static const titulo = 30.0;
  static const valor = 42.0;
}

abstract final class Estilos {
  static const corpo = TextStyle(fontFamily: fonte, fontSize: Letra.corpo, height: 1.45, color: Cores.tinta);
  static const nota = TextStyle(fontFamily: fonte, fontSize: Letra.meta, height: 1.45, color: Cores.tinta2);
  static const titulo = TextStyle(
      fontFamily: fonte, fontSize: Letra.titulo, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: Cores.tinta);
  static const subtitulo =
      TextStyle(fontFamily: fonte, fontSize: Letra.destaque, height: 1.3, fontWeight: FontWeight.w600, color: Cores.tinta);
  static const forte = TextStyle(fontFamily: fonte, fontSize: Letra.corpo, height: 1.45, fontWeight: FontWeight.w600, color: Cores.tinta);
}

ThemeData temaKussumba() {
  final esquema = ColorScheme.fromSeed(
    seedColor: Cores.verde,
    primary: Cores.verde,
    onPrimary: Colors.white,
    surface: Cores.superficie,
    onSurface: Cores.tinta,
    error: Cores.subida,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    fontFamily: fonte,
    scaffoldBackgroundColor: Cores.fundo,
    canvasColor: Cores.fundo,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: const TextTheme(
      bodyMedium: Estilos.corpo,
      bodyLarge: Estilos.corpo,
      titleMedium: Estilos.subtitulo,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Cores.verde,
      selectionColor: Cores.verdeSuave,
      selectionHandleColor: Cores.verde,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((estados) => estados.contains(WidgetState.selected) ? Cores.verde : null),
      side: const BorderSide(color: Cores.tinta2, width: 1.5),
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: Cores.superficie,
      headerBackgroundColor: Cores.verde,
      headerForegroundColor: Colors.white,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Cores.superficie, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Cores.superficie,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Cores.veu,
    ),
  );
}
