// Testes da cópia de segurança: ida e volta, compatibilidade com a versão web
// e ficheiros adulterados ou danificados.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kussumba/dados/base_dados.dart';
import 'package:kussumba/nucleo/datas.dart';
import 'package:kussumba/servicos/compras.dart' as compras;
import 'package:kussumba/servicos/copia.dart' as copia;
import 'package:kussumba/servicos/lista.dart' as lista;
import 'package:kussumba/servicos/meses.dart' as meses;
import 'package:kussumba/servicos/relatorio.dart' as relatorio;

import 'apoio.dart';

/// Agosto fechado com uma compra; Setembro aberto com lista e uma compra concluída.
Future<(String, String)> cenario() async {
  await baseDeDadosNova();
  relogio(2026, 8, 5);
  final agosto = await meses.configurarInicio(plafond: 240000);
  final arroz = await lista.adicionarProduto(agosto.id, 'cat-arroz', 25);
  final c1 = await compras.iniciarCompra(estabelecimento: 'Grossista <b>Kikolo</b>', data: '2026-08-05');
  await compras.registarArtigo(compraId: c1.id, itemListaId: arroz.id, quantidade: 25, precoReal: 30000);
  await compras.concluirCompra(c1.id);
  relogio(2026, 8, 31);
  await meses.fecharMes(agosto.id);
  relogio(2026, 9, 2);
  final setembro = await meses.criarMes(plafond: 250000, copiarDe: agosto.id);
  final itens = (await lista.obterLista(setembro.id)).itens;
  final c2 = await compras.iniciarCompra(estabelecimento: 'Armazém do Cazenga', data: '2026-09-02');
  await compras.registarArtigo(compraId: c2.id, itemListaId: itens.first.id, quantidade: 25, precoReal: 32000);
  await compras.concluirCompra(c2.id);
  return (agosto.id, setembro.id);
}

Future<Map<String, int>> contagens() => transaccao((t) async => {
      for (final tabela in tabelas) tabela: (await todasAsLinhas(t, tabela)).length,
    });

void main() {
  tearDown(() => definirRelogio(null));

  test('guardar e repor devolve exactamente os mesmos dados e números', () async {
    final (agosto, setembro) = await cenario();
    final antes = await contagens();
    final relatorioAgosto = await relatorio.relatorioMes(agosto);
    final painelSetembro = await relatorio.painelMes(setembro);
    final texto = await copia.exportarCopia();
    final ficheiro = jsonDecode(texto) as Map<String, Object?>;
    expect(ficheiro['formato'], 'kussumba-copia');
    final dados = ficheiro['dados']! as Map<String, Object?>;
    expect((dados['meses']! as List).any((m) => (m as Map).containsKey('resumoFecho')), isFalse);
    expect(((dados['produtos']! as List).first as Map)['activo'], isTrue, reason: 'lógicos como na versão web');

    await baseDeDadosNova();
    await copia.reporCopia(copia.lerCopia(texto));
    expect(await contagens(), antes);
    final reposto = await relatorio.relatorioMes(agosto);
    expect(reposto.congelado, isTrue);
    expect(reposto.sobrou, relatorioAgosto.sobrou);
    expect((await relatorio.painelMes(setembro)).orcamento.saldo, painelSetembro.orcamento.saldo);
  });

  test('aceita uma cópia feita pela versão web', () async {
    final texto = await File('test/ficheiros/copia_da_versao_web.json').readAsString();
    final lida = copia.lerCopia(texto);
    expect(lida.resumo.compras, 1);
    await baseDeDadosNova();
    await copia.reporCopia(lida);
    final mes = await meses.obterMesAberto();
    expect(mes!.plafond, 180000);
    expect((await relatorio.painelMes(mes.id)).orcamento.saldo, 148000);
    final catalogo = await transaccao((t) => t.query('produtos', orderBy: 'ordem', limit: 1));
    expect(catalogo.first['id'], 'cat-arroz', reason: 'o catálogo recupera a ordem original');
  });

  test('repor substitui os dados que já estavam no telefone', () async {
    await cenario();
    final texto = await copia.exportarCopia();
    await baseDeDadosNova();
    relogio(2026, 9, 20);
    final outro = await meses.configurarInicio(plafond: 99000);
    await lista.adicionarProduto(outro.id, 'cat-gas', 1);
    await copia.reporCopia(copia.lerCopia(texto));
    final todos = await meses.listarMeses();
    expect(todos.length, 2);
    expect(todos.firstWhere((m) => m.estado == 'aberto').plafond, 250000);
  });

  test('recusa ficheiros que não são cópias da KUSSUMBA', () {
    void recusa(String texto, String parte) {
      expect(() => copia.lerCopia(texto), throwsA(predicate((e) => e.toString().contains(parte))));
    }

    recusa('isto não é JSON', 'não é uma cópia');
    recusa(jsonEncode({'formato': 'outra-coisa', 'dados': {}}), 'não é uma cópia');
    recusa(jsonEncode({'formato': 'kussumba-copia', 'versaoDados': 99, 'dados': {}}), 'versão mais recente');
    recusa(jsonEncode({'formato': 'kussumba-copia', 'versaoDados': 1, 'dados': {}}), 'danificada');
    recusa('x' * (copia.tamanhoMaximo + 1), 'demasiado grande');
  });

  test('recusa ficheiros adulterados e descarta campos desconhecidos', () async {
    await cenario();
    final original = await copia.exportarCopia();
    String alterar(void Function(Map<String, dynamic> dados) mudanca) {
      final c = jsonDecode(original) as Map<String, dynamic>;
      mudanca(c['dados'] as Map<String, dynamic>);
      return jsonEncode(c);
    }

    void recusa(String texto, String parte) =>
        expect(() => copia.lerCopia(texto), throwsA(predicate((e) => e.toString().contains(parte))));

    recusa(alterar((d) => d['itensCompra'][0]['precoReal'] = '32000'), 'campo precoReal');
    recusa(alterar((d) => d['itensCompra'][0]['precoReal'] = -5), 'campo precoReal');
    recusa(alterar((d) => d['itensCompra'][0]['compraId'] = 'inexistente'), 'não existe');
    recusa(alterar((d) {
      for (final m in d['meses'] as List) {
        m['estado'] = 'aberto';
      }
    }), 'mais do que um mês aberto');
    recusa(alterar((d) => d['produtos'][0]['nome'] = 'x' * 5000), 'campo nome');
    recusa(alterar((d) => d['compras'][0]['data'] = '2026-02-31'), 'campo data');
    recusa(alterar((d) => (d['produtos'] as List).add(Map.of(d['produtos'][0] as Map))), 'repetidos');
    recusa(alterar((d) => d['utilizador'] = []), 'utilizador');

    final comExtra = alterar((d) {
      d['compras'][0]['malicioso'] = '<script>alert(1)</script>';
    });
    final lida = copia.lerCopia(comExtra);
    expect(lida.dados['compras']!.first.containsKey('malicioso'), isFalse);
    expect(lida.dados['compras']!.any((c) => c['estabelecimento'] == 'Grossista <b>Kikolo</b>'), isTrue,
        reason: 'o texto fica como foi escrito; o ecrã mostra-o como texto');
  });
}
