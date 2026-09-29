// Lista de compras do mês: o PREVISTO (prompt mestre, §9 a §16).

import 'package:sqflite/sqflite.dart';

import '../dados/base_dados.dart';
import '../dados/ids.dart';
import '../dados/modelos.dart';
import '../nucleo/calculos.dart';
import '../nucleo/datas.dart';
import '../nucleo/estados.dart';
import '../nucleo/unidades.dart' as un;
import 'comum.dart';
import 'precos.dart';
import 'produtos.dart' show ordenarCatalogo;

/// Item da lista com os dados do produto e os valores calculados.
class ItemDaLista {
  ItemDaLista(this.item, Produto? produto)
      : nome = produto?.nome ?? 'Produto removido',
        icone = produto?.icone ?? 'generico',
        categoria = produto?.categoria ?? 'outros',
        genero = produto?.genero,
        precoTotalPrevisto = precoTotal(item.quantidadePrevista, item.precoUnitarioPrevisto),
        unidadeBase = un.unidadeBase(item.unidade, item.unidadeTexto),
        precoUnitarioBasePrevisto =
            item.precoUnitarioPrevisto == null ? null : item.precoUnitarioPrevisto! / un.unidade(item.unidade).factor;

  final ItemLista item;
  final String nome;
  final String icone;
  final String categoria;
  final String? genero;
  final int? precoTotalPrevisto;
  final String unidadeBase;
  final double? precoUnitarioBasePrevisto;

  /// Último preço comparável deste produto (só preenchido na tela Comprar).
  RegistoPreco? anterior;

  String get id => item.id;
  String get produtoId => item.produtoId;
  bool get comprado => item.comprado;
}

class ResumoLista {
  const ResumoLista({
    required this.artigos,
    required this.comprados,
    required this.pendentes,
    required this.totalPrevisto,
    required this.semPreco,
    required this.pendentePrevisto,
    required this.pendenteSemPreco,
    required this.estado,
  });

  final int artigos;
  final int comprados;
  final int pendentes;
  final int totalPrevisto;
  final int semPreco;
  final int pendentePrevisto;
  final int pendenteSemPreco;
  final String estado;
}

/// Totais da lista. O total previsto soma todos os artigos com preço;
/// o pendente soma só o que ainda falta comprar, que é o que se compara com o saldo.
ResumoLista resumoLista(Iterable<ItemLista> itens) {
  Iterable<Linha> linhas(Iterable<ItemLista> lista) => lista.map((i) => Linha(i.quantidadePrevista, i.precoUnitarioPrevisto));
  final pendentes = itens.where((i) => !i.comprado).toList();
  final todos = totalPrevisto(linhas(itens));
  final porComprar = totalPrevisto(linhas(pendentes));
  final comprados = itens.length - pendentes.length;
  return ResumoLista(
    artigos: itens.length,
    comprados: comprados,
    pendentes: pendentes.length,
    totalPrevisto: todos.total,
    semPreco: todos.semPreco,
    pendentePrevisto: porComprar.total,
    pendenteSemPreco: porComprar.semPreco,
    estado: estadoDaLista(artigos: itens.length, comprados: comprados),
  );
}

class ListaDoMes {
  const ListaDoMes(this.mes, this.itens, this.resumo);
  final Mes mes;
  final List<ItemDaLista> itens;
  final ResumoLista resumo;
}

Future<Map<String, Produto>> produtosPorId(DatabaseExecutor t) async =>
    {for (final p in (await todasAsLinhas(t, 'produtos')).map(Produto.daLinha)) p.id: p};

Future<List<ItemLista>> itensDoMes(DatabaseExecutor t, String mesId) async {
  final itens = (await linhasOnde(t, 'itens_lista', 'mesId', mesId)).map(ItemLista.daLinha).toList();
  itens.sort((a, b) => a.ordem.compareTo(b.ordem));
  return itens;
}

Future<Mes?> obterMesEm(DatabaseExecutor t, String id) async {
  final linha = await obterLinha(t, 'meses', id);
  return linha == null ? null : Mes.daLinha(linha);
}

Future<ListaDoMes> obterLista(String mesId) => transaccao((t) async {
      final mes = await obterMesEm(t, mesId);
      if (mes == null) throw const ErroKussumba('Este mês não existe.');
      final produtos = await produtosPorId(t);
      final itens = await itensDoMes(t, mesId);
      return ListaDoMes(mes, itens.map((i) => ItemDaLista(i, produtos[i.produtoId])).toList(), resumoLista(itens));
    });

/// Cria o registo de um item de lista. O preço previsto parte do último preço pago, se existir.
Future<ItemLista> novoItemLista(
  DatabaseExecutor t, {
  required String mesId,
  required Produto produto,
  required double quantidade,
  required int ordem,
  bool usarHistorico = true,
  double? precoUnitarioPrevisto,
}) async {
  var preco = precoUnitarioPrevisto;
  if (usarHistorico) {
    preco = estimativaPeloHistorico(await historicoDoProduto(t, produto.id), produto.unidade, produto.unidadeTexto);
  }
  final instante = carimbo();
  return ItemLista(
    id: novoId(),
    mesId: mesId,
    produtoId: produto.id,
    unidade: produto.unidade,
    unidadeTexto: produto.unidadeTexto,
    quantidadePrevista: quantidade,
    precoUnitarioPrevisto: preco,
    ordem: ordem,
    criadoEm: instante,
    actualizadoEm: instante,
  );
}

Future<ItemLista> _itemEditavel(DatabaseExecutor t, String itemId) async {
  final linha = await obterLinha(t, 'itens_lista', itemId);
  if (linha == null) throw const ErroKussumba('Este artigo já não está na lista.');
  final item = ItemLista.daLinha(linha);
  exigirMesAberto(await obterMesEm(t, item.mesId));
  if (item.comprado) throw const ErroKussumba('Este artigo já foi comprado. O que foi previsto fica guardado como estava.');
  return item;
}

int _proximaOrdem(Iterable<ItemLista> itens) => itens.fold(0, (m, i) => i.ordem > m ? i.ordem : m) + 1;

/// Acrescenta um produto à lista do mês. Se já lá estiver, devolve o item existente.
Future<ItemLista> adicionarProduto(String mesId, String produtoId, [num? quantidade]) => transaccao((t) async {
      exigirMesAberto(await obterMesEm(t, mesId));
      final linha = await obterLinha(t, 'produtos', produtoId);
      final produto = linha == null ? null : Produto.daLinha(linha);
      if (produto == null || !produto.activo) throw const ErroKussumba('Este produto não está no catálogo.');
      final itens = await itensDoMes(t, mesId);
      for (final i in itens) {
        if (i.produtoId == produtoId) return i;
      }
      final item = await novoItemLista(t,
          mesId: mesId,
          produto: produto,
          quantidade: validarQuantidade(quantidade ?? produto.quantidadeSugerida),
          ordem: _proximaOrdem(itens));
      await guardarLinha(t, 'itens_lista', item.paraLinha());
      return item;
    });

/// Acrescenta os produtos básicos do catálogo que ainda não estão na lista (§46).
Future<int> adicionarSugeridos(String mesId) => transaccao((t) async {
      exigirMesAberto(await obterMesEm(t, mesId));
      final basicos = ordenarCatalogo((await todasAsLinhas(t, 'produtos')).map(Produto.daLinha))
          .where((p) => p.activo && p.basico);
      final itens = await itensDoMes(t, mesId);
      final naLista = itens.map((i) => i.produtoId).toSet();
      var ordem = _proximaOrdem(itens) - 1;
      var acrescentados = 0;
      for (final produto in basicos) {
        if (naLista.contains(produto.id)) continue;
        ordem += 1;
        final item = await novoItemLista(t, mesId: mesId, produto: produto, quantidade: produto.quantidadeSugerida, ordem: ordem);
        await guardarLinha(t, 'itens_lista', item.paraLinha());
        acrescentados += 1;
      }
      return acrescentados;
    });

/// Muda a quantidade prevista. O preço unitário mantém-se; o total é recalculado.
Future<ItemLista> alterarQuantidade(String itemId, num? quantidade) {
  final qtd = validarQuantidade(quantidade);
  return transaccao((t) async {
    final item = await _itemEditavel(t, itemId);
    item
      ..quantidadePrevista = qtd
      ..actualizadoEm = carimbo();
    await guardarLinha(t, 'itens_lista', item.paraLinha());
    return item;
  });
}

/// Define o preço previsto a partir do total esperado para a quantidade prevista.
/// Com null, o artigo fica sem preço previsto.
Future<ItemLista> definirPrecoPrevisto(String itemId, int? precoTotalPrevisto) {
  final total = precoTotalPrevisto == null ? null : validarKz(precoTotalPrevisto, 'Indica um preço maior do que zero.');
  return transaccao((t) async {
    final item = await _itemEditavel(t, itemId);
    item
      ..precoUnitarioPrevisto = total == null ? null : total / item.quantidadePrevista
      ..actualizadoEm = carimbo();
    await guardarLinha(t, 'itens_lista', item.paraLinha());
    return item;
  });
}

/// Altera quantidade e preço previsto de uma só vez (folha de edição da lista).
Future<ItemLista> actualizarItem(String itemId, {required num? quantidade, required int? precoTotalPrevisto}) {
  final qtd = validarQuantidade(quantidade);
  final total = precoTotalPrevisto == null ? null : validarKz(precoTotalPrevisto, 'Indica um preço maior do que zero.');
  return transaccao((t) async {
    final item = await _itemEditavel(t, itemId);
    item
      ..quantidadePrevista = qtd
      ..precoUnitarioPrevisto = total == null ? null : total / qtd
      ..actualizadoEm = carimbo();
    await guardarLinha(t, 'itens_lista', item.paraLinha());
    return item;
  });
}

Future<void> removerDaLista(String itemId) => transaccao((t) async {
      final item = await _itemEditavel(t, itemId);
      await apagarLinha(t, 'itens_lista', item.id);
    });
