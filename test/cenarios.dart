// Dados das telas de referência (Agosto fechado, Setembro de 2026 com plafond de 250 000 Kz e três idas
// às compras), usados pelos testes das telas e pelas capturas para as lojas.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kussumba/dados/base_dados.dart';
import 'package:kussumba/servicos/compras.dart' as compras;
import 'package:kussumba/servicos/lista.dart' as lista;
import 'package:kussumba/servicos/meses.dart' as meses;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'apoio.dart';

/// Base de dados nova, em memória, sem processo à parte (as telas lêem-na dentro do relógio dos testes).
Future<void> baseNova() async {
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
Future<String> agostoFechado() async {
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
Future<String> setembroComLista() async {
  await agostoFechado();
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
Future<String> setembroComCompras({bool comprasDaLista = true}) async {
  final setembro = await setembroComLista();
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

/// A ida ao Armazém do Cazenga da tela 4: arroz e açúcar já registados; sobra 24 600 Kz no mês.
Future<void> compraNoCazenga() async {
  final setembro = await setembroComCompras(comprasDaLista: false);
  final itens = {for (final i in (await lista.obterLista(setembro)).itens) i.produtoId: i.id};
  final compra = await compras.iniciarCompra(estabelecimento: 'Armazém do Cazenga', data: '2026-09-18');
  await compras.registarArtigo(compraId: compra.id, itemListaId: itens['cat-arroz'], quantidade: 25, precoReal: 32000);
  await compras.registarArtigo(compraId: compra.id, itemListaId: itens['cat-acucar'], quantidade: 10, precoReal: 11000);
}

/// Setembro com as compras, visto a 1 de Outubro, ainda por fechar: a tela Fecho do mês (tela 5).
Future<void> setembroTerminado() async {
  await setembroComCompras();
  relogio(2026, 10, 1);
}

/// Setembro fechado a 1 de Outubro: a tela Novo mês (tela 6).
Future<void> setembroFechado() async {
  final setembro = await setembroComCompras();
  relogio(2026, 10, 1);
  await meses.fecharMes(setembro);
}

// ---------- Desenho ----------

/// Carrega a letra DM Sans no motor de desenho dos testes (sem ela, o texto sai em quadrados).
Future<void> carregarLetra() async {
  final letra = FontLoader('DM Sans');
  for (final peso in [400, 500, 600, 700, 800]) {
    letra.addFont(Future.value(ByteData.sublistView(File('fontes/DMSans-$peso.ttf').readAsBytesSync())));
  }
  await letra.load();
}

/// Espera que a base de dados responda e que as animações terminem.
Future<void> assentar(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}
