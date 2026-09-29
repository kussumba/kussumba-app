// Histórico de preços (prompt mestre, §15 e §44).
// Cada artigo comprado gera um registo. Os preços são guardados por unidade de base
// (kg, L, unidade, pacote...) para as comparações nunca misturarem unidades.

import 'package:sqflite/sqflite.dart';

import '../dados/base_dados.dart';
import '../dados/modelos.dart';
import '../nucleo/calculos.dart';
import '../nucleo/unidades.dart';

/// Identificador do registo de histórico de um artigo comprado: um registo por artigo, nunca dois.
String idHistorico(String itemCompraId) => 'h-$itemCompraId';

RegistoPreco criarRegistoHistorico(ItemCompra item, Compra compra) {
  final quantidadeBase = paraBase(item.quantidade, item.unidade);
  return RegistoPreco(
    id: idHistorico(item.id),
    produtoId: item.produtoId,
    itemCompraId: item.id,
    compraId: compra.id,
    mesId: compra.mesId,
    data: compra.data,
    estabelecimento: compra.estabelecimento,
    precoTotal: item.precoReal,
    quantidade: item.quantidade,
    unidade: item.unidade,
    unidadeTexto: item.unidadeTexto,
    quantidadeBase: quantidadeBase,
    unidadeBase: unidadeBase(item.unidade, item.unidadeTexto),
    precoUnitarioBase: item.precoReal / quantidadeBase,
    registadoEm: item.registadoEm,
    corrigidoEm: item.corrigidoEm,
  );
}

/// Ordem cronológica: primeiro pela data da compra, depois pela hora do registo.
List<RegistoPreco> ordenarCronologicamente(Iterable<RegistoPreco> registos) {
  final lista = [...registos];
  lista.sort((a, b) =>
      a.data == b.data ? (a.registadoEm ?? '').compareTo(b.registadoEm ?? '') : a.data.compareTo(b.data));
  return lista;
}

/// Último preço comparável antes de uma compra: mesma unidade de base, data igual ou anterior,
/// e nunca a própria compra que está a ser registada.
RegistoPreco? ultimoComparavel(Iterable<RegistoPreco> registos,
    {required String unidadeBase, String? excluirCompraId, String? ateData}) {
  final candidatos = registos.where((r) =>
      r.unidadeBase == unidadeBase &&
      r.compraId != excluirCompraId &&
      (ateData == null || r.data.compareTo(ateData) <= 0));
  final ordenados = ordenarCronologicamente(candidatos);
  return ordenados.isEmpty ? null : ordenados.last;
}

class ResumoPreco {
  const ResumoPreco(this.ultimo, this.anterior, this.unidadeBase, this.medio, this.variacao, this.registos);
  final RegistoPreco ultimo;
  final RegistoPreco? anterior;
  final String unidadeBase;
  final double? medio;
  final double? variacao;
  final int registos;
}

/// Resumo do preço de um produto para o cartão de produto (§11):
/// último preço, preço anterior, preço médio e variação entre os dois últimos.
ResumoPreco? resumoPreco(Iterable<RegistoPreco> registos) {
  final ordenados = ordenarCronologicamente(registos);
  if (ordenados.isEmpty) return null;
  final ultimo = ordenados.last;
  final comparaveis = ordenados.where((r) => r.unidadeBase == ultimo.unidadeBase).toList();
  final anterior = comparaveis.length >= 2 ? comparaveis[comparaveis.length - 2] : null;
  return ResumoPreco(
    ultimo,
    anterior,
    ultimo.unidadeBase,
    precoMedioPonderado(comparaveis.map((r) => Registo(r.precoTotal, r.quantidadeBase))),
    anterior == null ? null : variacaoPercentual(ultimo.precoUnitarioBase, anterior.precoUnitarioBase),
    comparaveis.length,
  );
}

/// Converte um preço por unidade de base para a unidade do artigo: 1 280 Kz/kg → 1,28 Kz/g.
double precoNaUnidade(double precoUnitarioBase, String idUnidade) => precoUnitarioBase * unidade(idUnidade).factor;

/// Preço unitário estimado a partir do último preço pago, ou null se não houver preço comparável.
double? estimativaPeloHistorico(Iterable<RegistoPreco> registos, String idUnidade, [String? unidadeTexto]) {
  final ultimo = ultimoComparavel(registos, unidadeBase: unidadeBase(idUnidade, unidadeTexto));
  return ultimo == null ? null : precoNaUnidade(ultimo.precoUnitarioBase, idUnidade);
}

/// Leitura dentro de uma transacção: todos os registos de um produto.
Future<List<RegistoPreco>> historicoDoProduto(DatabaseExecutor t, String produtoId) async =>
    (await linhasOnde(t, 'historico_precos', 'produtoId', produtoId)).map(RegistoPreco.daLinha).toList();
