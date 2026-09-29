// Percurso completo dentro de um telemóvel (Android ou iPhone), com a base de dados verdadeira do aparelho:
// boas-vindas, lista sugerida, preço previsto, ida às compras com o teclado, fecho da compra, Mês e Relatório.
//
// No computador, com um telemóvel ligado ou um emulador aberto:
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/percurso_test.dart
// As capturas de ecrã ficam em build/capturas_dispositivo.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kussumba/dados/base_dados.dart';
import 'package:kussumba/interface/encaminhador.dart';
import 'package:kussumba/main.dart';
import 'package:kussumba/nucleo/datas.dart';
import 'package:path/path.dart' as caminhos;
import 'package:sqflite/sqflite.dart';

/// Espaço inseparável depois de um algarismo, como a interface mostra os valores em Kz.
String ui(String texto) => texto.replaceAllMapped(RegExp(r'(\d) '), (m) => '${m[1]}\u00A0');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var superficieConvertida = false;

  Future<void> captura(WidgetTester tester, String nome) async {
    // No Android, a superfície do Flutter tem de passar a imagem antes da primeira captura.
    if (Platform.isAndroid && !superficieConvertida) {
      await binding.convertFlutterSurfaceToImage();
      superficieConvertida = true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await tester.pump();
    await binding.takeScreenshot(nome);
  }

  /// Espera, em tempo real, que a base de dados responda e o elemento apareça.
  /// Se não aparecer, guarda uma captura do ecrã para se ver o que lá estava.
  Future<void> esperarPor(WidgetTester tester, Finder alvo) async {
    final limite = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(limite)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      if (alvo.evaluate().isNotEmpty) return;
    }
    await captura(tester, 'falha');
    throw TestFailure('Não apareceu no ecrã: $alvo');
  }

  /// Tira os avisos do ecrã, para não taparem o botão seguinte.
  void semAvisos(WidgetTester tester) => tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();

  /// Fecha o teclado do ecrã e espera que ele saia de facto e que a página se ajuste ao espaço livre.
  Future<void> tecladoFechado(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final limite = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(limite)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      if (tester.view.viewInsets.bottom == 0) break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await tester.pump();
  }

  /// Toca como uma pessoa: sem teclado nem avisos à frente, com o elemento já parado no ecrã.
  Future<void> tocar(WidgetTester tester, Finder alvo) async {
    semAvisos(tester);
    await tecladoFechado(tester);
    await tester.ensureVisible(alvo);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.tap(alvo);
    await tester.pump();
  }

  testWidgets('percurso de um mês: do plafond ao relatório', (tester) async {
    // Base de dados própria do teste, apagada no início: nunca toca nos dados de quem usa a aplicação.
    final caminho = caminhos.join(await getDatabasesPath(), 'kussumba-teste.db');
    await fecharBaseDeDados();
    await databaseFactory.deleteDatabase(caminho);
    await usarBaseDeDados(caminho);
    definirRelogio(() => DateTime(2026, 9, 18, 10));

    await tester.pumpWidget(KussumbaApp(encaminhador: Encaminhador()));

    // Boas-vindas: o plafond cria o mês.
    await esperarPor(tester, find.text('Bem-vinda à KUSSUMBA'));
    await captura(tester, '01_boas_vindas');
    await tester.enterText(find.byType(TextField), '250000');
    await tocar(tester, find.text('Continuar'));

    // Primeira lista com os produtos sugeridos.
    await esperarPor(tester, find.text('Queres criar a tua primeira lista?'));
    await tocar(tester, find.text('Começar com produtos sugeridos'));
    await esperarPor(tester, find.text('Lista de Setembro'));

    // Preço previsto do arroz.
    await tocar(tester, find.text('Arroz'));
    await esperarPor(tester, find.text('Preço previsto para esta quantidade'));
    await tester.enterText(find.byType(TextField).last, '32000');
    await tocar(tester, find.text('Guardar'));
    await esperarPor(tester, find.text(ui('32 000 Kz')));
    await captura(tester, '02_lista');

    // Ida às compras: loja, arroz e óleo pelo teclado do preço.
    await tocar(tester, find.text('Comprar').last);
    await esperarPor(tester, find.text('Onde vais comprar?'));
    await tester.enterText(find.byType(TextField), 'Grossista Kikolo');
    await tocar(tester, find.text('Começar a registar'));
    await esperarPor(tester, find.text('Guardar e seguinte'));
    for (final tecla in ['3', '2', '000']) {
      await tocar(tester, find.text(tecla));
    }
    expect(find.text(ui('32 000 Kz')), findsWidgets);
    await captura(tester, '03_comprar');
    await tocar(tester, find.text('Guardar e seguinte'));
    await esperarPor(tester, find.text('1 de 10 artigos registados · faltam 9'));
    for (final tecla in ['9', '5', '0', '0']) {
      await tocar(tester, find.text(tecla).first);
    }
    await tocar(tester, find.text('Guardar e seguinte'));
    await esperarPor(tester, find.text('2 de 10 artigos registados · faltam 8'));

    // Concluir: os artigos que faltam ficam na lista para outra ida.
    await tocar(tester, find.text('Concluir compra'));
    await esperarPor(tester, find.text('Concluir esta compra?'));
    await tocar(tester, find.text('Concluir compra').last);
    await esperarPor(tester, find.text('Compra concluída'));

    // Mês: 250 000 − 32 000 − 9 500 = 208 500 Kz.
    await tocar(tester, find.text('Mês').last);
    await esperarPor(tester, find.text('Sobra disponível'));
    expect(find.text(ui('208 500 Kz')), findsWidgets);
    expect(find.text('Grossista Kikolo'), findsOneWidget);
    await captura(tester, '04_mes');

    // Relatório até hoje.
    await tocar(tester, find.text('Relatório').last);
    await esperarPor(tester, find.text('Relatório até hoje'));
    expect(find.text('Fechar mês e começar Outubro'), findsOneWidget);
    await captura(tester, '05_relatorio');

    // Cópia de segurança: a tela abre; guardar e escolher ficheiros usam janelas do próprio telefone.
    await tocar(tester, find.text('Mês').last);
    await esperarPor(tester, find.text('Cópia de segurança'));
    await tocar(tester, find.text('Cópia de segurança'));
    await esperarPor(tester, find.text('Guardar uma cópia'));
    await captura(tester, '06_copia');

    await fecharBaseDeDados();
    await databaseFactory.deleteDatabase(caminho);
    definirRelogio(null);
  });
}
