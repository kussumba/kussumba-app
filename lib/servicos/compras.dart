// Idas às compras: o REALIZADO (prompt mestre, §18 a §23).
// Só o preço efectivamente pago conta como gasto. O previsto nunca entra no gasto real.

import 'package:sqflite/sqflite.dart';

import '../dados/base_dados.dart';
import '../dados/catalogo_inicial.dart';
import '../dados/ids.dart';
import '../dados/modelos.dart';
import '../nucleo/calculos.dart';
import '../nucleo/datas.dart';
import '../nucleo/unidades.dart';
import 'comum.dart';
import 'lista.dart';
import 'precos.dart';

class ResumoCompra {
  const ResumoCompra({
    required this.artigos,
    required this.previsto,
    required this.realComPrevisao,
    required this.real,
    required this.diferenca,
    required this.semPrevisaoArtigos,
    required this.semPrevisaoTotal,
  });

  final int artigos;
  final int previsto;
  final int realComPrevisao;
  final int real;
  final int? diferenca;
  final int semPrevisaoArtigos;
  final int semPrevisaoTotal;
}

/// Totais de uma compra. A diferença só compara artigos que tinham preço previsto;
/// os artigos sem previsão entram no total real e são mostrados à parte.
ResumoCompra resumoCompra(Iterable<ItemCompra> itens) {
  final comPrevisao = itens.where((i) => i.precoPrevisto != null).toList();
  final semPrevisao = itens.where((i) => i.precoPrevisto == null).toList();
  final previsto = comPrevisao.fold<int>(0, (s, i) => s + i.precoPrevisto!);
  final realComPrevisao = comPrevisao.fold<int>(0, (s, i) => s + i.precoReal);
  return ResumoCompra(
    artigos: itens.length,
    previsto: previsto,
    realComPrevisao: realComPrevisao,
    real: itens.fold<int>(0, (s, i) => s + i.precoReal),
    diferenca: comPrevisao.isEmpty ? null : realComPrevisao - previsto,
    semPrevisaoArtigos: semPrevisao.length,
    semPrevisaoTotal: semPrevisao.fold<int>(0, (s, i) => s + i.precoReal),
  );
}

class ContasArtigo {
  const ContasArtigo(this.previsto, this.diferenca, this.unidadeBase, this.precoUnitarioBase, this.variacao);
  final int? previsto;
  final num? diferenca;
  final String unidadeBase;
  final double? precoUnitarioBase;
  final double? variacao;
}

/// Contas de um artigo durante a compra (§19, §20, §22): previsto para a quantidade comprada,
/// diferença para o preço pago, preço por unidade de base e variação face à última compra.
/// A tela Comprar usa-a enquanto o utilizador escreve; o registo usa as mesmas regras ao gravar.
ContasArtigo simularArtigo({
  required num quantidade,
  required String unidade,
  String? unidadeTexto,
  double? precoUnitarioPrevisto,
  int? precoReal,
  RegistoPreco? anterior,
}) {
  final previsto = precoTotal(quantidade, precoUnitarioPrevisto);
  final pago = precoReal != null && precoReal > 0 ? precoReal : null;
  final porBase = pago == null ? null : precoUnitario(pago, paraBase(quantidade, unidade));
  return ContasArtigo(
    previsto,
    pago == null ? null : diferenca(pago, previsto),
    unidadeBase(unidade, unidadeTexto),
    porBase,
    anterior != null && porBase != null ? variacaoPercentual(porBase, anterior.precoUnitarioBase) : null,
  );
}

Future<RegistoPreco?> _precoAnterior(DatabaseExecutor t, Compra compra, String produtoId, String base) async =>
    ultimoComparavel(await historicoDoProduto(t, produtoId),
        unidadeBase: base, excluirCompraId: compra.id, ateData: compra.data);

Future<Compra> _compraEditavel(DatabaseExecutor t, String compraId) async {
  final linha = await obterLinha(t, 'compras', compraId);
  if (linha == null) throw const ErroKussumba('Esta compra não existe.');
  final compra = Compra.daLinha(linha);
  exigirMesAberto(await obterMesEm(t, compra.mesId));
  if (compra.estado != 'em_andamento') throw const ErroKussumba('Esta compra já foi concluída.');
  return compra;
}

Future<Mes> _mesAberto(DatabaseExecutor t) async {
  final abertos = await linhasOnde(t, 'meses', 'estado', 'aberto');
  if (abertos.isEmpty) throw const ErroKussumba('Não há nenhum mês aberto.');
  return Mes.daLinha(abertos.first);
}

Future<List<Compra>> comprasDoMes(DatabaseExecutor t, String mesId) async =>
    (await linhasOnde(t, 'compras', 'mesId', mesId)).map(Compra.daLinha).toList();

Future<List<ItemCompra>> artigosDoMes(DatabaseExecutor t, String mesId) async =>
    (await linhasOnde(t, 'itens_compra', 'mesId', mesId)).map(ItemCompra.daLinha).toList();

Future<List<ItemCompra>> artigosDaCompra(DatabaseExecutor t, String compraId) async =>
    (await linhasOnde(t, 'itens_compra', 'compraId', compraId)).map(ItemCompra.daLinha).toList();

class IntervaloDatas {
  const IntervaloDatas(this.min, this.max);
  final String min;
  final String max;
}

/// Datas aceites para uma compra do mês aberto (SEC-004): do primeiro dia do mês anterior até hoje.
IntervaloDatas intervaloDataCompra(AnoMes mes, [DateTime? hoje]) {
  final anterior = mesAnterior(mes);
  return IntervaloDatas('${idMes(anterior.ano, anterior.mes)}-01', dataIso(hoje ?? agora()));
}

/// Começa uma ida às compras no mês aberto. Só pode haver uma compra em andamento de cada vez.
Future<Compra> iniciarCompra({required String? estabelecimento, String? data}) {
  final nome = validarTexto(estabelecimento, 'Escreve onde vais fazer as compras.', 60);
  final quando = data ?? dataIso();
  if (!dataValida(quando)) throw const ErroKussumba('Escolhe uma data válida.');
  return transaccao((t) async {
    final mes = await _mesAberto(t);
    final intervalo = intervaloDataCompra(AnoMes(mes.ano, mes.mes));
    if (quando.compareTo(intervalo.min) < 0 || quando.compareTo(intervalo.max) > 0) {
      throw ErroKussumba('A data da compra tem de estar entre ${formatarDataLonga(intervalo.min)} e hoje.');
    }
    final compras = await comprasDoMes(t, mes.id);
    for (final c in compras) {
      if (c.estado == 'em_andamento') throw ErroKussumba('Já tens uma compra em andamento em ${c.estabelecimento}.');
    }
    final instante = carimbo();
    final compra = Compra(
      id: novoId(),
      mesId: mes.id,
      estabelecimento: nome,
      data: quando,
      estado: 'em_andamento',
      criadoEm: instante,
      actualizadoEm: instante,
    );
    await guardarLinha(t, 'compras', compra.paraLinha());
    return compra;
  });
}

/// Compra em andamento do mês aberto, ou null.
Future<Compra?> compraEmAndamento() => transaccao((t) async {
      final abertos = await linhasOnde(t, 'meses', 'estado', 'aberto');
      if (abertos.isEmpty) return null;
      for (final c in await comprasDoMes(t, abertos.first['id']! as String)) {
        if (c.estado == 'em_andamento') return c;
      }
      return null;
    });

/// Artigo registado, com o nome do produto e as contas de preço.
class ArtigoRegistado {
  ArtigoRegistado(this.item, Produto? produto, this.contas, this.anterior)
      : nome = produto?.nome ?? 'Produto removido',
        genero = produto?.genero,
        icone = produto?.icone ?? 'generico';

  final ItemCompra item;
  final String nome;
  final String? genero;
  final String icone;
  final ContasArtigo contas;
  final RegistoPreco? anterior;

  num? get diferenca => item.precoPrevisto == null ? null : item.precoReal - item.precoPrevisto!;
}

class DetalheCompra {
  const DetalheCompra({
    required this.compra,
    required this.mes,
    required this.itens,
    required this.pendentes,
    required this.artigosDaLista,
    required this.resumo,
    required this.gastoMes,
    required this.saldoMes,
  });

  final Compra compra;
  final Mes mes;
  final List<ArtigoRegistado> itens;
  final List<ItemDaLista> pendentes;
  final int artigosDaLista;
  final ResumoCompra resumo;
  final int gastoMes;
  final int saldoMes;
}

/// Tudo o que a tela Comprar precisa: a compra, os artigos já registados (com a comparação
/// de preços), os artigos da lista que faltam, os totais e o saldo do mês.
Future<DetalheCompra> detalheCompra(String compraId) => transaccao((t) async {
      final linha = await obterLinha(t, 'compras', compraId);
      if (linha == null) throw const ErroKussumba('Esta compra não existe.');
      final compra = Compra.daLinha(linha);
      final mes = (await obterMesEm(t, compra.mesId))!;
      final produtos = await produtosPorId(t);
      final doMes = await artigosDoMes(t, compra.mesId);
      final registados = doMes.where((i) => i.compraId == compra.id).toList()
        ..sort((a, b) => (a.registadoEm ?? '').compareTo(b.registadoEm ?? ''));

      final itens = <ArtigoRegistado>[];
      for (final i in registados) {
        final anterior = await _precoAnterior(t, compra, i.produtoId, unidadeBase(i.unidade, i.unidadeTexto));
        final contas = simularArtigo(
          quantidade: i.quantidade,
          unidade: i.unidade,
          unidadeTexto: i.unidadeTexto,
          precoUnitarioPrevisto: i.precoUnitarioPrevisto,
          precoReal: i.precoReal,
          anterior: anterior,
        );
        itens.add(ArtigoRegistado(i, produtos[i.produtoId], contas, anterior));
      }

      final lista = (await itensDoMes(t, compra.mesId)).map((i) => ItemDaLista(i, produtos[i.produtoId])).toList();
      final pendentes = <ItemDaLista>[];
      for (final i in lista.where((item) => !item.comprado)) {
        i.anterior = await _precoAnterior(t, compra, i.produtoId, i.unidadeBase);
        pendentes.add(i);
      }

      final gastoMes = doMes.fold<int>(0, (s, i) => s + i.precoReal);
      return DetalheCompra(
        compra: compra,
        mes: mes,
        itens: itens,
        pendentes: pendentes,
        artigosDaLista: lista.length,
        resumo: resumoCompra(registados),
        gastoMes: gastoMes,
        saldoMes: mes.plafond - gastoMes,
      );
    });

/// Produto escolhido fora da lista durante uma compra, com o último preço comparável.
Future<ItemDaLista> produtoParaCompra(String compraId, String produtoId) => transaccao((t) async {
      final linhaCompra = await obterLinha(t, 'compras', compraId);
      if (linhaCompra == null) throw const ErroKussumba('Esta compra não existe.');
      final compra = Compra.daLinha(linhaCompra);
      final linha = await obterLinha(t, 'produtos', produtoId);
      if (linha == null) throw const ErroKussumba('Este produto não está no catálogo.');
      final produto = Produto.daLinha(linha);
      // Um item "virtual", só para a tela: não é gravado na lista.
      final virtual = ItemDaLista(
        ItemLista(
          id: 'fora-${produto.id}',
          mesId: compra.mesId,
          produtoId: produto.id,
          unidade: produto.unidade,
          unidadeTexto: produto.unidadeTexto,
          quantidadePrevista: produto.quantidadeSugerida,
          ordem: 0,
        ),
        produto,
      );
      virtual.anterior = await _precoAnterior(t, compra, produto.id, virtual.unidadeBase);
      return virtual;
    });

/// Regista o preço efectivamente pago por um artigo (§19, §22).
/// Se o artigo já estava registado nesta compra, actualiza o registo em vez de criar outro.
/// Grava ao mesmo tempo o artigo, o histórico de preços e a marca "comprado" na lista.
Future<ItemCompra> registarArtigo({
  required String compraId,
  String? itemListaId,
  String? produtoId,
  required num? quantidade,
  required int? precoReal,
}) {
  final qtd = validarQuantidade(quantidade);
  final pago = validarKz(precoReal, 'Indica o preço pago, maior do que zero.');
  return transaccao((t) async {
    final compra = await _compraEditavel(t, compraId);

    ItemLista? itemLista;
    var idProduto = produtoId;
    if (itemListaId != null) {
      final linha = await obterLinha(t, 'itens_lista', itemListaId);
      itemLista = linha == null ? null : ItemLista.daLinha(linha);
      if (itemLista == null || itemLista.mesId != compra.mesId) {
        throw const ErroKussumba('Este artigo não está na lista deste mês.');
      }
      if (itemLista.comprado && itemLista.compraId != compra.id) {
        throw const ErroKussumba('Este artigo já foi comprado noutra ida às compras.');
      }
      idProduto = itemLista.produtoId;
    }
    final linhaProduto = idProduto == null ? null : await obterLinha(t, 'produtos', idProduto);
    if (linhaProduto == null) throw const ErroKussumba('Escolhe um produto do catálogo.');
    final produto = Produto.daLinha(linhaProduto);

    final daCompra = await artigosDaCompra(t, compra.id);
    ItemCompra? existente;
    for (final i in daCompra) {
      final mesmo = itemLista != null ? i.itemListaId == itemLista.id : i.itemListaId == null && i.produtoId == produto.id;
      if (mesmo) existente = i;
    }

    final idUnidade = itemLista?.unidade ?? produto.unidade;
    final unidadeTexto = itemLista != null ? itemLista.unidadeTexto : produto.unidadeTexto;
    final precoUnitarioPrevisto = itemLista?.precoUnitarioPrevisto;
    final instante = carimbo();

    final item = ItemCompra(
      id: existente?.id ?? novoId(),
      compraId: compra.id,
      mesId: compra.mesId,
      produtoId: produto.id,
      itemListaId: itemLista?.id,
      quantidadePlaneada: itemLista?.quantidadePrevista,
      quantidade: qtd,
      unidade: idUnidade,
      unidadeTexto: unidadeTexto,
      precoUnitarioPrevisto: precoUnitarioPrevisto,
      // Se a quantidade mudou, o previsto acompanha-a, para a diferença medir o preço e não a quantidade.
      precoPrevisto: precoTotal(qtd, precoUnitarioPrevisto),
      precoReal: pago,
      precoUnitarioReal: precoUnitario(pago, qtd),
      registadoEm: existente?.registadoEm ?? instante,
      actualizadoEm: instante,
    );
    await guardarLinha(t, 'itens_compra', item.paraLinha());
    await guardarLinha(t, 'historico_precos', criarRegistoHistorico(item, compra).paraLinha());

    if (itemLista != null) {
      itemLista
        ..comprado = true
        ..compraId = compra.id
        ..actualizadoEm = instante;
      await guardarLinha(t, 'itens_lista', itemLista.paraLinha());
    }
    compra.actualizadoEm = instante;
    await guardarLinha(t, 'compras', compra.paraLinha());
    return item;
  });
}

Future<void> _desfazerArtigo(DatabaseExecutor t, ItemCompra item) async {
  await apagarLinha(t, 'historico_precos', idHistorico(item.id));
  await apagarLinha(t, 'itens_compra', item.id);
  if (item.itemListaId != null) {
    final linha = await obterLinha(t, 'itens_lista', item.itemListaId!);
    if (linha != null) {
      final itemLista = ItemLista.daLinha(linha);
      if (itemLista.compraId == item.compraId) {
        itemLista
          ..comprado = false
          ..compraId = null
          ..actualizadoEm = carimbo();
        await guardarLinha(t, 'itens_lista', itemLista.paraLinha());
      }
    }
  }
}

/// Retira um artigo registado numa compra em andamento; o artigo volta a ficar por comprar na lista.
Future<void> anularArtigo(String itemCompraId) => transaccao((t) async {
      final linha = await obterLinha(t, 'itens_compra', itemCompraId);
      if (linha == null) throw const ErroKussumba('Este artigo já não está registado.');
      final item = ItemCompra.daLinha(linha);
      await _compraEditavel(t, item.compraId);
      await _desfazerArtigo(t, item);
    });

class CompraConcluida {
  const CompraConcluida(this.compra, this.resumo);
  final Compra compra;
  final ResumoCompra resumo;
}

/// Conclui a compra e guarda os totais (§23).
Future<CompraConcluida> concluirCompra(String compraId) => transaccao((t) async {
      final compra = await _compraEditavel(t, compraId);
      final itens = await artigosDaCompra(t, compra.id);
      if (itens.isEmpty) throw const ErroKussumba('Regista pelo menos um artigo antes de concluir a compra.');
      final resumo = resumoCompra(itens);
      final instante = carimbo();
      compra
        ..estado = 'concluida'
        ..totalPrevisto = resumo.previsto
        ..totalReal = resumo.real
        ..diferenca = resumo.diferenca
        ..artigos = resumo.artigos
        ..concluidaEm = instante
        ..actualizadoEm = instante;
      await guardarLinha(t, 'compras', compra.paraLinha());
      return CompraConcluida(compra, resumo);
    });

/// Cancela uma compra em andamento. Apaga os artigos registados nela; a lista volta ao que estava.
Future<void> cancelarCompra(String compraId) => transaccao((t) async {
      final compra = await _compraEditavel(t, compraId);
      for (final item in await artigosDaCompra(t, compra.id)) {
        await _desfazerArtigo(t, item);
      }
      await apagarLinha(t, 'compras', compra.id);
    });

/// Corrige um erro de digitação num artigo já registado, enquanto o mês estiver aberto.
/// O registo de histórico desse artigo é actualizado e fica marcado como corrigido.
Future<ItemCompra> corrigirArtigo(String itemCompraId, {required num? quantidade, required int? precoReal}) {
  final qtd = validarQuantidade(quantidade);
  final pago = validarKz(precoReal, 'Indica o preço pago, maior do que zero.');
  return transaccao((t) async {
    final linha = await obterLinha(t, 'itens_compra', itemCompraId);
    if (linha == null) throw const ErroKussumba('Este artigo já não está registado.');
    final item = ItemCompra.daLinha(linha);
    final compra = Compra.daLinha((await obterLinha(t, 'compras', item.compraId))!);
    exigirMesAberto(await obterMesEm(t, compra.mesId));
    final instante = carimbo();
    item
      ..quantidade = qtd
      ..precoPrevisto = precoTotal(qtd, item.precoUnitarioPrevisto)
      ..precoReal = pago
      ..precoUnitarioReal = precoUnitario(pago, qtd)
      ..corrigidoEm = instante
      ..actualizadoEm = instante;
    await guardarLinha(t, 'itens_compra', item.paraLinha());
    await guardarLinha(t, 'historico_precos', criarRegistoHistorico(item, compra).paraLinha());
    if (compra.estado == 'concluida') {
      final resumo = resumoCompra(await artigosDaCompra(t, compra.id));
      compra
        ..totalPrevisto = resumo.previsto
        ..totalReal = resumo.real
        ..diferenca = resumo.diferenca
        ..artigos = resumo.artigos;
    }
    compra.actualizadoEm = instante;
    await guardarLinha(t, 'compras', compra.paraLinha());
    return item;
  });
}

class CompraResumida {
  const CompraResumida(this.compra, this.artigos, this.total);
  final Compra compra;
  final int artigos;
  final int total;
}

/// Compras de um mês, das mais recentes para as mais antigas, com o total e o número de artigos.
List<CompraResumida> resumirCompras(Iterable<Compra> compras, Iterable<ItemCompra> itensDoMes) {
  final lista = compras.map((c) {
    final itens = itensDoMes.where((i) => i.compraId == c.id);
    return CompraResumida(c, itens.length, itens.fold<int>(0, (s, i) => s + i.precoReal));
  }).toList();
  lista.sort((a, b) => a.compra.data == b.compra.data
      ? (b.compra.criadoEm ?? '').compareTo(a.compra.criadoEm ?? '')
      : b.compra.data.compareTo(a.compra.data));
  return lista;
}

Future<List<CompraResumida>> listarCompras(String mesId) =>
    transaccao((t) async => resumirCompras(await comprasDoMes(t, mesId), await artigosDoMes(t, mesId)));

/// Estabelecimentos já usados, do mais recente para o mais antigo, sem repetições.
Future<List<String>> estabelecimentosRecentes([int limite = 6]) async {
  final compras = (await transaccao((t) => todasAsLinhas(t, 'compras'))).map(Compra.daLinha).toList()
    ..sort((a, b) => (b.criadoEm ?? '').compareTo(a.criadoEm ?? ''));
  final vistos = <String>{};
  final nomes = <String>[];
  for (final c in compras) {
    if (!vistos.add(normalizarNome(c.estabelecimento))) continue;
    nomes.add(c.estabelecimento);
    if (nomes.length >= limite) break;
  }
  return nomes;
}
