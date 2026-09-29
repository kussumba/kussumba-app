// Testes das telas: cada tela abre com os dados das telas de referência, sem erros de desenho,
// com a letra normal e com a letra grande (o dobro), num ecrã de 390 × 844 e num ecrã estreito.
//
// Para guardar uma imagem de cada tela em build/capturas:
//   flutter test test/interface_test.dart --dart-define=CAPTURAS=true

import 'dart:io';
import 'dart:ui' as pintura;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kussumba/dados/base_dados.dart';
import 'package:kussumba/interface/encaminhador.dart';
import 'package:kussumba/main.dart';
import 'package:kussumba/nucleo/datas.dart';
import 'package:kussumba/servicos/compras.dart' as compras;
import 'package:kussumba/servicos/lista.dart' as lista;
import 'package:kussumba/servicos/meses.dart' as meses;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'apoio.dart';

const bool _capturar = bool.fromEnvironment('CAPTURAS');
final _moldura = GlobalKey();

// ---------- Dados das telas de referência ----------

Future<void> _baseNova() async {
  sqfliteFfiInit();
  await usarBaseDeDados(inMemoryDatabasePath, fabrica: databaseFactoryFfiNoIsolate);
}

/// Preço total de cada artigo da lista de Setembro (tela 3).
const _listaSetembro = {
  'cat-arroz': 32000,
  'cat-oleo': 9500,
  'cat-acucar': 11000,
  'cat-feijao': 7500,
  'cat-fuba': 8000,
  'cat-sabao-po': 6800,
  'cat-leite-po': 18000,
};

/// Agosto com uma compra no Grossista Kikolo, já fechado.
Future<String> _agostoFechado() async {
  relogio(2026, 8, 5);
  final agosto = await meses.configurarInicio(plafond: 240000);
  const precos = {
    'cat-arroz': 30000, 'cat-oleo': 8500, 'cat-acucar': 12000, 'cat-feijao': 7500,
    'cat-fuba': 7500, 'cat-sabao-po': 6300, 'cat-leite-po': 17000,
  };
  for (final id in precos.keys) {
    await lista.adicionarProduto(agosto.id, id);
  }
  final compra = await compras.iniciarCompra(estabelecimento: 'Grossista Kikolo', data: '2026-08-05');
  for (final item in (await lista.obterLista(agosto.id)).itens) {
    await compras.registarArtigo(
        compraId: compra.id, itemListaId: item.id, quantidade: item.item.quantidadePrevista, precoReal: precos[item.produtoId]);
  }
  await compras.concluirCompra(compra.id);
  relogio(2026, 8, 31);
  await meses.fecharMes(agosto.id);
  return agosto.id;
}

/// Setembro com a lista copiada de Agosto e os preços previstos da tela 3.
Future<String> _setembroComLista() async {
  await _agostoFechado();
  relogio(2026, 9, 1);
  final setembro = await meses.criarMes(plafond: 250000, copiarDe: '2026-08');
  for (final item in (await lista.obterLista(setembro.id)).itens) {
    await lista.definirPrecoPrevisto(item.id, _listaSetembro[item.produtoId]);
  }
  return setembro.id;
}

Future<void> _compra(String loja, String data, List<(String, num, int)> artigos, {Map<String, String> daLista = const {}}) async {
  final compra = await compras.iniciarCompra(estabelecimento: loja, data: data);
  for (final (produto, quantidade, preco) in artigos) {
    await compras.registarArtigo(
      compraId: compra.id,
      itemListaId: daLista[produto],
      produtoId: daLista.containsKey(produto) ? null : produto,
      quantidade: quantidade,
      precoReal: preco,
    );
  }
  await compras.concluirCompra(compra.id);
}

/// As três idas de Setembro da tela 1: 128 900 + 21 300 + 32 200 = 182 400 Kz.
Future<String> _setembroComCompras({bool comprasDaLista = true}) async {
  final setembro = await _setembroComLista();
  final itens = {for (final i in (await lista.obterLista(setembro)).itens) i.produtoId: i.id};
  relogio(2026, 9, 2);
  await _compra(
    'Grossista Kikolo',
    '2026-09-02',
    comprasDaLista
        ? [('cat-arroz', 25, 32000), ('cat-acucar', 10, 11000), ('cat-feijao', 5, 7500), ('cat-oleo', 5, 9500),
            ('cat-frango', 5, 30000), ('cat-carne', 2, 24000), ('cat-gas', 1, 14900)]
        : [('cat-frango', 5, 30000), ('cat-carne', 2, 24000), ('cat-gas', 1, 14900), ('cat-sal', 1, 500),
            ('cat-farinha-trigo', 2, 3000), ('cat-massa', 4, 6000), ('cat-refrigerante', 6, 50500)],
    daLista: comprasDaLista ? itens : const {},
  );
  relogio(2026, 9, 9);
  await _compra('Cantina do bairro', '2026-09-09', [
    ('cat-sal', 1, 500), ('cat-tomate', 2, 3000), ('cat-cebola', 2, 2400), ('cat-batata', 3, 4500), ('cat-sabonete', 4, 10900),
  ]);
  relogio(2026, 9, 16);
  await _compra('Mercado do 30', '2026-09-16', [
    ('cat-ovos', 1, 4500), ('cat-peixe', 3, 9000), ('cat-agua', 6, 1800), ('cat-sumo', 2, 1600), ('cat-refrigerante', 6, 3000),
    ('cat-detergente', 1, 1500), ('cat-lixivia', 1, 800), ('cat-papel-higienico', 1, 2500), ('cat-pasta-dentes', 2, 7500),
  ]);
  relogio(2026, 9, 18);
  return setembro;
}

// ---------- Desenho ----------

Future<void> _carregarLetra() async {
  final letra = FontLoader('DM Sans');
  for (final peso in [400, 500, 600, 700, 800]) {
    letra.addFont(Future.value(ByteData.sublistView(File('fontes/DMSans-$peso.ttf').readAsBytesSync())));
  }
  await letra.load();
}

/// Espera que a base de dados responda e que as animações terminem.
Future<void> _assentar(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _abrir(WidgetTester tester, String caminho, {double largura = 390, double altura = 844, double letra = 1}) async {
  tester.view.physicalSize = Size(largura, altura);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = letra;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(RepaintBoundary(key: _moldura, child: KussumbaApp(encaminhador: Encaminhador(caminho))));
  await _assentar(tester);
}

Future<void> _captura(WidgetTester tester, String nome) async {
  expect(tester.takeException(), isNull);
  if (!_capturar) return;
  final moldura = tester.renderObject<RenderRepaintBoundary>(find.byKey(_moldura));
  await tester.runAsync(() async {
    final imagem = await moldura.toImage();
    final png = await imagem.toByteData(format: pintura.ImageByteFormat.png);
    final ficheiro = File('build/capturas/$nome.png')..createSync(recursive: true);
    ficheiro.writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pump();
  await tester.tap(alvo);
  await _assentar(tester);
}

void main() {
  setUpAll(_carregarLetra);
  setUp(_baseNova);
  tearDown(() => definirRelogio(null));

  testWidgets('boas-vindas: o plafond cria o mês e leva à primeira lista', (tester) async {
    relogio(2026, 9, 1);
    await _abrir(tester, 'mes');
    expect(find.text('Bem-vinda à KUSSUMBA'), findsOneWidget);
    await _captura(tester, '00_boas_vindas');

    await tester.enterText(find.byType(TextField), '250000');
    await tester.pump();
    expect(find.text(ui('250 000')), findsOneWidget);
    await _tocar(tester, find.text('Continuar'));
    expect(find.text('Queres criar a tua primeira lista?'), findsOneWidget);
    await _captura(tester, '00_primeira_lista');

    await _tocar(tester, find.text('Começar com produtos sugeridos'));
    expect(find.text('Lista de Setembro'), findsOneWidget);
    expect(find.text('Arroz'), findsOneWidget);
  });

  testWidgets('tela 1, Mês: saldo, alerta e idas deste mês', (tester) async {
    await tester.runAsync(_setembroComCompras);
    await _abrir(tester, 'mes');
    expect(find.text('Setembro 2026'), findsOneWidget);
    expect(find.text(ui('67 600 Kz')), findsWidgets);
    expect(find.text('Já usaste 73% do plafond e faltam 12 dias para o fim do mês.'), findsOneWidget);
    expect(find.text('Grossista Kikolo'), findsOneWidget);
    expect(find.text(ui('128 900 Kz')), findsOneWidget);
    expect(find.text('02 Set · 7 artigos'), findsOneWidget);
    await _captura(tester, '01_mes');
  });

  testWidgets('tela 3, Lista do mês: copiada de Agosto, total previsto e preço por unidade', (tester) async {
    await tester.runAsync(_setembroComLista);
    await _abrir(tester, 'lista');
    expect(find.text('Lista de Setembro'), findsOneWidget);
    expect(find.text('Copiada de Agosto'), findsOneWidget);
    expect(find.text(ui('92 800 Kz')), findsOneWidget);
    expect(find.text(ui('1 280 Kz/kg')), findsOneWidget);
    await _captura(tester, '03_lista');

    await _tocar(tester, find.text('Arroz'));
    expect(find.text('Preço previsto para esta quantidade'), findsOneWidget);
    expect(find.text('Retirar da lista'), findsOneWidget);
    await _captura(tester, '03_lista_editar');
  });

  testWidgets('tela 2, Catálogo: produtos da lista marcados, com quantidade', (tester) async {
    await tester.runAsync(_setembroComLista);
    await _abrir(tester, 'catalogo');
    expect(find.text('O que vais comprar?'), findsOneWidget);
    expect(find.text('Na lista'), findsWidgets);
    expect(find.text(ui('Sugestão: 4 pacotes')), findsOneWidget);
    expect(find.text('7 artigos'), findsOneWidget);
    await _captura(tester, '02_catalogo');

    await _tocar(tester, find.text('Massa'));
    expect(find.text('8 artigos'), findsOneWidget);
    await _tocar(tester, find.text('Novo produto'));
    expect(find.text('Criar e pôr na lista'), findsOneWidget);
    await _captura(tester, '02_catalogo_novo_produto');
  });

  testWidgets('tela 4, Ida às compras: dois registados e o teclado do preço', (tester) async {
    await tester.runAsync(() async {
      final setembro = await _setembroComCompras(comprasDaLista: false);
      final itens = {for (final i in (await lista.obterLista(setembro)).itens) i.produtoId: i.id};
      final compra = await compras.iniciarCompra(estabelecimento: 'Armazém do Cazenga', data: '2026-09-18');
      await compras.registarArtigo(compraId: compra.id, itemListaId: itens['cat-arroz'], quantidade: 25, precoReal: 32000);
      await compras.registarArtigo(compraId: compra.id, itemListaId: itens['cat-acucar'], quantidade: 10, precoReal: 11000);
    });
    await _abrir(tester, 'comprar');
    expect(find.text('Armazém do Cazenga'), findsOneWidget);
    expect(find.text('2 de 7 artigos registados · faltam 5'), findsOneWidget);
    expect(find.text(ui('24 600 Kz')), findsWidgets);
    expect(find.text('Óleo alimentar'), findsOneWidget);

    await tester.tap(find.text('1'));
    await tester.tap(find.text('0').first);
    await tester.tap(find.text('000'));
    await tester.pump();
    expect(find.text(ui('10 000 Kz')), findsOneWidget);
    expect(find.text(ui('+500 Kz')), findsOneWidget);
    await _captura(tester, '04_comprar');

    await _tocar(tester, find.text('Guardar e seguinte'));
    expect(find.text('3 de 7 artigos registados · faltam 4'), findsOneWidget);
  });

  testWidgets('comprar: começar uma ida às compras', (tester) async {
    await tester.runAsync(_setembroComLista);
    await _abrir(tester, 'comprar');
    expect(find.text('Nova ida às compras'), findsOneWidget);
    expect(find.text('Grossista Kikolo'), findsOneWidget);
    await _captura(tester, '04_comprar_inicio');

    await _tocar(tester, find.text('Grossista Kikolo'));
    await _tocar(tester, find.text('Começar a registar'));
    expect(find.text('0 de 7 artigos registados · faltam 7'), findsOneWidget);
    expect(find.text('Guardar e seguinte'), findsOneWidget);
  });

  testWidgets('detalhe de uma compra concluída', (tester) async {
    late String id;
    await tester.runAsync(() async {
      await _setembroComCompras();
      id = (await compras.listarCompras('2026-09')).last.compra.id;
    });
    await _abrir(tester, 'compra/$id/concluida');
    expect(find.text('Compra concluída'), findsOneWidget);
    expect(find.text('Grossista Kikolo'), findsOneWidget);
    await _captura(tester, '04_compra_detalhe');
  });

  testWidgets('tela 5, Fecho do mês: preços face a Agosto e onde gastou', (tester) async {
    await tester.runAsync(() async {
      await _setembroComCompras();
      relogio(2026, 10, 1);
    });
    await _abrir(tester, 'relatorio');
    expect(find.text('Fecho do mês'), findsOneWidget);
    expect(find.text('Preços face a Agosto (por unidade)'), findsOneWidget);
    expect(find.text(ui('1 700 Kz/L → 1 900 Kz/L')), findsOneWidget);
    expect(find.text('Fechar mês e começar Outubro'), findsOneWidget);
    await _captura(tester, '05_relatorio');

    await _tocar(tester, find.text('Fechar mês e começar Outubro'));
    expect(find.text('Fechar Setembro?'), findsOneWidget);
    await _captura(tester, '05_relatorio_confirmar');
    await _tocar(tester, find.text('Fechar mês'));
    expect(find.text('Outubro 2026'), findsOneWidget);
  });

  testWidgets('tela 6, Novo mês: nota do fecho, plafond sugerido e cópia da lista', (tester) async {
    await tester.runAsync(() async {
      final setembro = await _setembroComCompras();
      relogio(2026, 10, 1);
      await meses.fecharMes(setembro);
    });
    await _abrir(tester, 'mes');
    expect(find.text('Outubro 2026'), findsOneWidget);
    expect(find.text('Copiar lista de Setembro'), findsOneWidget);
    expect(find.textContaining('Setembro fechou com'), findsOneWidget);
    await _captura(tester, '06_novo_mes');

    await _tocar(tester, find.text('Criar mês'));
    expect(find.text('Lista de Outubro'), findsOneWidget);
    expect(find.text('Copiada de Setembro'), findsOneWidget);
  });

  testWidgets('cópia de segurança', (tester) async {
    await tester.runAsync(_setembroComLista);
    await _abrir(tester, 'dados');
    expect(find.text('Guardar uma cópia'), findsOneWidget);
    expect(find.text('Ainda não guardaste nenhuma cópia.'), findsOneWidget);
    await _captura(tester, '07_copia');
  });

  testWidgets('a barra inferior leva às quatro telas principais', (tester) async {
    await tester.runAsync(_setembroComCompras);
    await _abrir(tester, 'mes');
    await _tocar(tester, find.text('Lista').last);
    expect(find.text('Lista de Setembro'), findsOneWidget);
    await _tocar(tester, find.text('Comprar').last);
    expect(find.text('Nova ida às compras'), findsOneWidget);
    await _tocar(tester, find.text('Relatório').last);
    expect(find.text('Relatório até hoje'), findsOneWidget);
    await _tocar(tester, find.text('Mês').last);
    expect(find.text('Mês em curso'), findsOneWidget);
  });

  group('letra grande (o dobro) e ecrã estreito: nada fica cortado', () {
    for (final (caminho, preparar) in [
      ('mes', _setembroComCompras),
      ('lista', _setembroComLista),
      ('catalogo', _setembroComLista),
      ('comprar', _setembroComLista),
      ('relatorio', _setembroComCompras),
      ('dados', _setembroComLista),
    ]) {
      testWidgets(caminho, (tester) async {
        await tester.runAsync(preparar);
        await _abrir(tester, caminho, letra: 2);
        await _captura(tester, '08_letra_grande_$caminho');
        await _abrir(tester, caminho, largura: 320, altura: 640);
        await _captura(tester, '09_estreito_$caminho');
      });
    }

    testWidgets('boas-vindas', (tester) async {
      relogio(2026, 9, 1);
      await _abrir(tester, 'mes', letra: 2);
      await _captura(tester, '08_letra_grande_boas_vindas');
    });

    testWidgets('novo mês', (tester) async {
      await tester.runAsync(() async {
        final setembro = await _setembroComCompras();
        relogio(2026, 10, 1);
        await meses.fecharMes(setembro);
      });
      await _abrir(tester, 'novo-mes', letra: 2);
      await _captura(tester, '08_letra_grande_novo_mes');
    });
  });
}
