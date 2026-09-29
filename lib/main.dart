// Arranque da KUSSUMBA nativa.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'interface/encaminhador.dart';
import 'interface/tema.dart';
import 'interface/telas/telas.dart';

void main() {
  runApp(const KussumbaApp());
}

class KussumbaApp extends StatelessWidget {
  const KussumbaApp({super.key, this.encaminhador});

  /// Os testes indicam a tela inicial; na aplicação, começa sempre no Mês.
  final Encaminhador? encaminhador;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Fundo claro: ícones escuros na barra de estado.
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: MaterialApp(
        title: 'KUSSUMBA',
        debugShowCheckedModeBanner: false,
        theme: temaKussumba(),
        locale: const Locale('pt', 'PT'),
        supportedLocales: const [Locale('pt', 'PT')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // A letra grande do telefone é respeitada até ao dobro do tamanho normal.
        builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 2, child: child!),
        home: AplicacaoKussumba(telas: telasKussumba, encaminhador: encaminhador),
      ),
    );
  }
}
