// Utilizador e ciclo de vida dos meses: primeira utilização (§45), plafond,
// fecho do mês (§30) e preparação do mês seguinte (§16, tela Novo mês).

import 'package:sqflite/sqflite.dart';

import '../dados/base_dados.dart';
import '../dados/modelos.dart';
import '../nucleo/calculos.dart';
import '../nucleo/datas.dart';
import 'comum.dart';
import 'lista.dart';
import 'precos.dart';
import 'relatorio.dart';

const String _mensagemPlafond = 'Indica um plafond maior do que zero.';

Mes _novoRegistoMes(int ano, int mes, int plafond, String? listaCopiadaDe, String instante) => Mes(
      id: idMes(ano, mes),
      ano: ano,
      mes: mes,
      plafond: plafond,
      estado: 'aberto',
      listaCopiadaDe: listaCopiadaDe,
      criadoEm: instante,
      actualizadoEm: instante,
    );

Future<List<Mes>> _todosOsMeses(DatabaseExecutor t) async =>
    (await todasAsLinhas(t, 'meses')).map(Mes.daLinha).toList()..sort((a, b) => a.id.compareTo(b.id));

Future<Utilizador?> obterUtilizador() async {
  final linha = await transaccao((t) => obterLinha(t, 'utilizador', 'eu'));
  return linha == null ? null : Utilizador.daLinha(linha);
}

/// Primeira utilização: guarda o utilizador (sem dados pessoais) e cria o mês em curso.
Future<Mes> configurarInicio({required int? plafond}) {
  final valor = validarKz(plafond, _mensagemPlafond);
  final hoje = mesDaData();
  return transaccao((t) async {
    if (await obterLinha(t, 'utilizador', 'eu') != null) {
      throw const ErroKussumba('A KUSSUMBA já está configurada neste telefone.');
    }
    final instante = carimbo();
    await guardarLinha(t, 'utilizador', Utilizador(id: 'eu', moeda: 'AOA', criadoEm: instante, actualizadoEm: instante).paraLinha());
    final registo = _novoRegistoMes(hoje.ano, hoje.mes, valor, null, instante);
    await guardarLinha(t, 'meses', registo.paraLinha());
    return registo;
  });
}

Future<Mes?> obterMesAberto() => transaccao((t) async {
      final abertos = await linhasOnde(t, 'meses', 'estado', 'aberto');
      return abertos.isEmpty ? null : Mes.daLinha(abertos.first);
    });

Future<Mes?> obterMes(String id) => transaccao((t) => obterMesEm(t, id));

/// Mês que o Relatório mostra: o mês aberto ou, entre o fecho e o mês seguinte, o último mês.
Future<Mes?> mesParaRelatorio() => transaccao((t) async {
      final meses = await _todosOsMeses(t);
      for (final m in meses) {
        if (m.estado == 'aberto') return m;
      }
      return meses.isEmpty ? null : meses.last;
    });

Future<List<Mes>> listarMeses() async => (await transaccao(_todosOsMeses)).reversed.toList();

Future<Mes> alterarPlafond(String mesId, int? plafond) {
  final valor = validarKz(plafond, _mensagemPlafond);
  return transaccao((t) async {
    final mes = exigirMesAberto(await obterMesEm(t, mesId));
    mes
      ..plafond = valor
      ..actualizadoEm = carimbo();
    await guardarLinha(t, 'meses', mes.paraLinha());
    return mes;
  });
}

/// Mês que começa depois de fechar o último: o seguinte ao último mês,
/// ou o mês do calendário se entretanto já passaram meses sem uso.
AnoMes proximoMes(AnoMes ultimo, DateTime hoje) {
  final seguinte = mesSeguinte(ultimo);
  final actual = mesDaData(hoje);
  return compararMeses(actual, seguinte) > 0 ? actual : seguinte;
}

/// Fecha o mês (§30): congela o resumo, preserva todo o histórico e não apaga nada.
/// Não fecha com uma compra por concluir.
Future<Mes> fecharMes(String mesId) => transaccao((t) async {
      final mes = exigirMesAberto(await obterMesEm(t, mesId));
      for (final c in (await linhasOnde(t, 'compras', 'mesId', mesId)).map(Compra.daLinha)) {
        if (c.estado == 'em_andamento') {
          throw ErroKussumba(
              'Há uma compra por concluir em ${c.estabelecimento}. Conclui-a ou cancela-a antes de fechar o mês.');
        }
      }
      final resumo = calcularRelatorio(await recolherDadosRelatorio(t, mesId));
      final instante = carimbo();
      mes
        ..estado = 'fechado'
        ..fechadoEm = instante
        ..resumoFecho = resumo.paraJson()
        ..actualizadoEm = instante;
      await guardarLinha(t, 'meses', mes.paraLinha());
      return mes;
    });

/// Preço previsto para um artigo copiado: o último preço pago; sem ele, o previsto do mês anterior.
Future<double?> _precoParaCopia(DatabaseExecutor t, ItemLista item) async =>
    estimativaPeloHistorico(await historicoDoProduto(t, item.produtoId), item.unidade, item.unidadeTexto) ??
    item.precoUnitarioPrevisto;

class ArtigoACopiar {
  const ArtigoACopiar._(this.item, this.nome, this.icone, this.precoUnitarioPrevisto, this.precoTotalPrevisto);

  factory ArtigoACopiar.de(ItemLista item, Produto produto, double? preco) =>
      ArtigoACopiar._(item, produto.nome, produto.icone, preco, precoTotal(item.quantidadePrevista, preco));

  final ItemLista item;
  final String nome;
  final String? icone;
  final double? precoUnitarioPrevisto;
  final int? precoTotalPrevisto;
}

class MesAnteriorResumido {
  const MesAnteriorResumido(this.id, this.nome, this.rotulo, this.plafond, this.sobrou, this.variacaoCabaz);
  final String id;
  final String nome;
  final String rotulo;
  final int plafond;
  final int? sobrou;
  final double? variacaoCabaz;
}

class NovoMesPreparado {
  const NovoMesPreparado({
    this.mesAberto,
    this.ano = 0,
    this.mes = 0,
    this.rotulo = '',
    this.nomeMes = '',
    this.anterior,
    this.plafondSugerido,
    this.itens = const [],
  });

  final Mes? mesAberto;
  final int ano;
  final int mes;
  final String rotulo;
  final String nomeMes;
  final MesAnteriorResumido? anterior;
  final int? plafondSugerido;
  final List<ArtigoACopiar> itens;
}

/// Dados para a tela Novo mês: que mês vem a seguir, como fechou o anterior,
/// sugestão de plafond pelo cabaz e os artigos que podem ser copiados.
Future<NovoMesPreparado> prepararNovoMes() => transaccao((t) async {
      final meses = await _todosOsMeses(t);
      for (final m in meses) {
        if (m.estado == 'aberto') return NovoMesPreparado(mesAberto: m);
      }
      if (meses.isEmpty) throw const ErroKussumba('Ainda não há nenhum mês criado.');
      final ultimo = meses.last;
      final seguinte = proximoMes(AnoMes(ultimo.ano, ultimo.mes), agora());
      final produtos = await produtosPorId(t);
      final itens = <ArtigoACopiar>[];
      for (final item in await itensDoMes(t, ultimo.id)) {
        final produto = produtos[item.produtoId];
        if (produto == null || !produto.activo) continue;
        itens.add(ArtigoACopiar.de(item, produto, await _precoParaCopia(t, item)));
      }
      final resumo = ultimo.resumoFecho == null ? null : Relatorio.deJson(ultimo.resumoFecho!);
      final variacaoCabaz = resumo?.cabaz?.variacao;
      return NovoMesPreparado(
        ano: seguinte.ano,
        mes: seguinte.mes,
        rotulo: rotuloMes(seguinte.ano, seguinte.mes),
        nomeMes: nomeMes(seguinte.mes),
        anterior: MesAnteriorResumido(ultimo.id, nomeMes(ultimo.mes), rotuloMes(ultimo.ano, ultimo.mes), ultimo.plafond,
            resumo?.sobrou, variacaoCabaz),
        plafondSugerido: variacaoCabaz == null ? null : sugestaoPlafond(ultimo.plafond, variacaoCabaz),
        itens: itens,
      );
    });

/// Cria o mês seguinte. Com copiarDe, copia os artigos seleccionados da lista desse mês,
/// com os últimos preços pagos. Os dados do mês anterior ficam intactos.
Future<Mes> criarMes({required int? plafond, String? copiarDe, List<String>? itensSeleccionados}) {
  final valor = validarKz(plafond, _mensagemPlafond);
  return transaccao((t) async {
    final meses = await _todosOsMeses(t);
    if (meses.any((m) => m.estado == 'aberto')) {
      throw const ErroKussumba('Já existe um mês aberto. Fecha-o antes de começar outro.');
    }
    if (meses.isEmpty) throw const ErroKussumba('Ainda não há nenhum mês criado.');
    final ultimo = meses.last;
    final seguinte = proximoMes(AnoMes(ultimo.ano, ultimo.mes), agora());
    final id = idMes(seguinte.ano, seguinte.mes);
    if (meses.any((m) => m.id == id)) throw ErroKussumba('${rotuloMes(seguinte.ano, seguinte.mes)} já existe.');

    // O mês é gravado primeiro: os artigos da lista referem-no.
    final registo = _novoRegistoMes(seguinte.ano, seguinte.mes, valor, null, carimbo());

    String? origem;
    if (copiarDe != null) {
      final fonte = meses.where((m) => m.id == copiarDe).firstOrNull;
      if (fonte == null) throw const ErroKussumba('O mês a copiar não existe.');
      origem = fonte.id;
      registo.listaCopiadaDe = origem;
      await guardarLinha(t, 'meses', registo.paraLinha());
      final seleccao = itensSeleccionados?.toSet();
      var ordem = 0;
      for (final item in await itensDoMes(t, fonte.id)) {
        if (seleccao != null && !seleccao.contains(item.id)) continue;
        final linha = await obterLinha(t, 'produtos', item.produtoId);
        final produto = linha == null ? null : Produto.daLinha(linha);
        if (produto == null || !produto.activo) continue;
        ordem += 1;
        final novo = await novoItemLista(t,
            mesId: id,
            produto: produto,
            quantidade: item.quantidadePrevista,
            ordem: ordem,
            usarHistorico: false,
            precoUnitarioPrevisto: await _precoParaCopia(t, item));
        // Mantém a unidade do artigo copiado, que é a do preço calculado.
        novo
          ..unidade = item.unidade
          ..unidadeTexto = item.unidadeTexto;
        await guardarLinha(t, 'itens_lista', novo.paraLinha());
      }
    } else {
      await guardarLinha(t, 'meses', registo.paraLinha());
    }
    return registo;
  });
}
