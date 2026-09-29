// Painel da tela Mês (§5 a §8, §38) e relatório de fecho (§24 a §29).

import 'package:sqflite/sqflite.dart';

import '../dados/base_dados.dart';
import '../dados/catalogo_inicial.dart';
import '../dados/modelos.dart';
import '../nucleo/alertas.dart';
import '../nucleo/calculos.dart' as calc;
import '../nucleo/datas.dart';
import '../nucleo/estados.dart';
import '../nucleo/unidades.dart';
import 'comum.dart';
import 'compras.dart';
import 'lista.dart';

/// O cabaz habitual só se mostra quando há pelo menos este número de produtos comprados nos dois meses.
const int minProdutosCabaz = 3;

// ---------- Painel do mês ----------

class Orcamento {
  const Orcamento(this.plafond, this.gasto, this.saldo, this.percentagem, this.larguraBarra);
  final int plafond;
  final int gasto;
  final int saldo;
  final double? percentagem;
  final double larguraBarra;
  bool get ultrapassado => saldo < 0;
}

class Ritmo {
  const Ritmo({
    required this.diasDecorridos,
    required this.diasRestantes,
    required this.diasNoMes,
    required this.mediaDiaria,
    required this.previsaoMensal,
    required this.disponivel,
    required this.faceAoPlafond,
  });

  final int diasDecorridos;
  final int diasRestantes;
  final int diasNoMes;
  final double? mediaDiaria;
  final int? previsaoMensal;
  final bool disponivel;

  /// Diferença entre a previsão e o plafond: positiva quando a previsão passa o plafond.
  final num? faceAoPlafond;
  int get diasMinimos => diasMinimosRitmo;
}

class Painel {
  const Painel({
    required this.mes,
    required this.rotulo,
    required this.estado,
    required this.orcamento,
    required this.lista,
    required this.cobertura,
    required this.ritmo,
    required this.compras,
    required this.compraEmAndamento,
    required this.mesTerminado,
    required this.alertas,
    required this.alertaLista,
  });

  final Mes mes;
  final String rotulo;
  final String estado;
  final Orcamento orcamento;
  final ResumoLista lista;

  /// Saldo actual menos o previsto do que falta comprar. Negativo: faltam Kz para cumprir a lista.
  final num? cobertura;
  final Ritmo ritmo;
  final List<CompraResumida> compras;
  final CompraResumida? compraEmAndamento;
  final bool mesTerminado;
  final List<Alerta> alertas;
  final Alerta? alertaLista;
}

Painel calcularPainel({
  required Mes mes,
  required List<ItemLista> itensLista,
  required List<Compra> compras,
  required List<ItemCompra> itensCompra,
  required DateTime hoje,
}) {
  final gasto = calc.totalReal(itensCompra.map((i) => i.precoReal));
  final saldoActual = mes.plafond - gasto;
  final percentagem = calc.percentagemUtilizada(gasto, mes.plafond);
  final lista = resumoLista(itensLista);
  final decorridos = diasDecorridos(mes.ano, mes.mes, hoje);
  final restantes = diasRestantes(mes.ano, mes.mes, hoje);
  final totalDias = diasNoMes(mes.ano, mes.mes);
  final media = calc.mediaDiaria(gasto, decorridos);
  final previsao = calc.previsaoMensal(media, totalDias);
  final mesTerminado = mes.estado != 'fechado' && compararMeses(mesDaData(hoje), AnoMes(mes.ano, mes.mes)) > 0;
  final resumidas = resumirCompras(compras, itensCompra);
  CompraResumida? emAndamento;
  for (final c in resumidas) {
    if (c.compra.estado == 'em_andamento') emAndamento = c;
  }

  return Painel(
    mes: mes,
    rotulo: rotuloMes(mes.ano, mes.mes),
    estado: estadoDoMes(mes.estado, compras.length),
    orcamento: Orcamento(mes.plafond, gasto, saldoActual, percentagem, calc.limitarPercentagem(percentagem)),
    lista: lista,
    cobertura: calc.coberturaDaLista(saldoActual, lista.pendentePrevisto),
    ritmo: Ritmo(
      diasDecorridos: decorridos,
      diasRestantes: restantes,
      diasNoMes: totalDias,
      mediaDiaria: media,
      previsaoMensal: previsao,
      disponivel: decorridos >= diasMinimosRitmo && gasto > 0,
      faceAoPlafond: previsao == null ? null : calc.diferenca(previsao, mes.plafond),
    ),
    compras: resumidas,
    compraEmAndamento: emAndamento,
    mesTerminado: mesTerminado,
    alertas: alertasOrcamento(
      plafond: mes.plafond,
      gasto: gasto,
      percentagem: percentagem,
      diasRestantes: restantes,
      previsaoMensal: previsao,
      diasDecorridos: decorridos,
      mesTerminado: mesTerminado,
      nomeDoMes: nomeMes(mes.mes),
    ),
    alertaLista: alertaLista(pendente: lista.pendentePrevisto, saldo: saldoActual, artigosPendentes: lista.pendentes),
  );
}

Future<Painel> painelMes(String mesId) => transaccao((t) async {
      final mes = await obterMesEm(t, mesId);
      if (mes == null) throw const ErroKussumba('Este mês não existe.');
      return calcularPainel(
        mes: mes,
        itensLista: await itensDoMes(t, mesId),
        compras: await comprasDoMes(t, mesId),
        itensCompra: await artigosDoMes(t, mesId),
        hoje: agora(),
      );
    });

// ---------- Relatório do mês ----------

class PrecoComparado {
  const PrecoComparado(this.produtoId, this.nome, this.unidadeBase, this.anterior, this.actual, this.variacao, this.quantidadeBase);

  factory PrecoComparado.deJson(Map<String, Object?> j) => PrecoComparado(
        j['produtoId']! as String,
        j['nome']! as String,
        j['unidadeBase']! as String,
        (j['anterior']! as num).toDouble(),
        (j['actual']! as num).toDouble(),
        (j['variacao'] as num?)?.toDouble(),
        (j['quantidadeBase']! as num).toDouble(),
      );

  final String produtoId;
  final String nome;
  final String unidadeBase;
  final double anterior;
  final double actual;
  final double? variacao;
  final double quantidadeBase;

  Map<String, Object?> paraJson() => {
        'produtoId': produtoId, 'nome': nome, 'unidadeBase': unidadeBase, 'anterior': anterior,
        'actual': actual, 'variacao': variacao, 'quantidadeBase': quantidadeBase,
      };
}

class Loja {
  const Loja(this.estabelecimento, this.total, this.idas, this.proporcao);

  factory Loja.deJson(Map<String, Object?> j) => Loja(
      j['estabelecimento']! as String, (j['total']! as num).toInt(), (j['idas']! as num).toInt(), (j['proporcao']! as num).toDouble());

  final String estabelecimento;
  final int total;
  final int idas;
  final double proporcao;

  Map<String, Object?> paraJson() => {'estabelecimento': estabelecimento, 'total': total, 'idas': idas, 'proporcao': proporcao};
}

class Relatorio {
  const Relatorio({
    required this.mesId,
    required this.rotulo,
    required this.nomeMes,
    required this.plafond,
    required this.gasto,
    required this.sobrou,
    required this.previsto,
    required this.previstoSemPreco,
    required this.artigosNaLista,
    required this.diferencaPrevisto,
    required this.mesAnteriorNome,
    required this.precos,
    required this.maiorAumento,
    required this.maiorReducao,
    required this.maiorDespesaNome,
    required this.maiorDespesaTotal,
    required this.ondeGastou,
    required this.cabaz,
    required this.compras,
    required this.artigosComprados,
    this.congelado = false,
  });

  factory Relatorio.deJson(Map<String, Object?> j, {bool congelado = true}) {
    List<Map<String, Object?>> lista(Object? v) => (v as List? ?? []).cast<Map<String, Object?>>();
    final c = j['cabaz'] as Map<String, Object?>?;
    return Relatorio(
      mesId: j['mesId']! as String,
      rotulo: j['rotulo']! as String,
      nomeMes: j['nomeMes']! as String,
      plafond: (j['plafond']! as num).toInt(),
      gasto: (j['gasto']! as num).toInt(),
      sobrou: (j['sobrou']! as num).toInt(),
      previsto: (j['previsto']! as num).toInt(),
      previstoSemPreco: (j['previstoSemPreco']! as num).toInt(),
      artigosNaLista: (j['artigosNaLista']! as num).toInt(),
      diferencaPrevisto: (j['diferencaPrevisto'] as num?)?.toInt(),
      mesAnteriorNome: j['mesAnteriorNome'] as String?,
      precos: lista(j['precos']).map(PrecoComparado.deJson).toList(),
      maiorAumento: j['maiorAumento'] == null ? null : PrecoComparado.deJson(j['maiorAumento']! as Map<String, Object?>),
      maiorReducao: j['maiorReducao'] == null ? null : PrecoComparado.deJson(j['maiorReducao']! as Map<String, Object?>),
      maiorDespesaNome: j['maiorDespesaNome'] as String?,
      maiorDespesaTotal: (j['maiorDespesaTotal'] as num?)?.toInt(),
      ondeGastou: lista(j['ondeGastou']).map(Loja.deJson).toList(),
      cabaz: c == null
          ? null
          : calc.Cabaz((c['actual']! as num).toInt(), (c['anterior']! as num).toInt(), (c['variacao'] as num?)?.toDouble()),
      compras: (j['compras']! as num).toInt(),
      artigosComprados: (j['artigosComprados']! as num).toInt(),
      congelado: congelado,
    );
  }

  final String mesId;
  final String rotulo;
  final String nomeMes;
  final int plafond;
  final int gasto;
  final int sobrou;
  final int previsto;
  final int previstoSemPreco;
  final int artigosNaLista;
  final int? diferencaPrevisto;
  final String? mesAnteriorNome;
  final List<PrecoComparado> precos;
  final PrecoComparado? maiorAumento;
  final PrecoComparado? maiorReducao;
  final String? maiorDespesaNome;
  final int? maiorDespesaTotal;
  final List<Loja> ondeGastou;
  final calc.Cabaz? cabaz;
  final int compras;
  final int artigosComprados;
  final bool congelado;

  bool get ultrapassado => sobrou < 0;

  Map<String, Object?> paraJson() => {
        'mesId': mesId, 'rotulo': rotulo, 'nomeMes': nomeMes, 'plafond': plafond, 'gasto': gasto, 'sobrou': sobrou,
        'previsto': previsto, 'previstoSemPreco': previstoSemPreco, 'artigosNaLista': artigosNaLista,
        'diferencaPrevisto': diferencaPrevisto, 'mesAnteriorNome': mesAnteriorNome,
        'precos': precos.map((p) => p.paraJson()).toList(),
        'maiorAumento': maiorAumento?.paraJson(), 'maiorReducao': maiorReducao?.paraJson(),
        'maiorDespesaNome': maiorDespesaNome, 'maiorDespesaTotal': maiorDespesaTotal,
        'ondeGastou': ondeGastou.map((l) => l.paraJson()).toList(),
        'cabaz': cabaz == null ? null : {'actual': cabaz!.actual, 'anterior': cabaz!.anterior, 'variacao': cabaz!.variacao},
        'compras': compras, 'artigosComprados': artigosComprados,
      };
}

class _GrupoPreco {
  _GrupoPreco(this.produtoId, this.unidadeBase);
  final String produtoId;
  final String unidadeBase;
  final List<calc.Registo> registos = [];
  double quantidadeBase = 0;
  double? get precoMedio => calc.precoMedioPonderado(registos);
}

/// Agrupa os artigos comprados por produto e unidade de base, com o preço médio ponderado.
Map<String, _GrupoPreco> _precosPorProduto(Iterable<ItemCompra> itens) {
  final grupos = <String, _GrupoPreco>{};
  for (final i in itens) {
    final base = unidadeBase(i.unidade, i.unidadeTexto);
    final grupo = grupos.putIfAbsent('${i.produtoId}|$base', () => _GrupoPreco(i.produtoId, base));
    final quantidadeBase = paraBase(i.quantidade, i.unidade);
    grupo.registos.add(calc.Registo(i.precoReal, quantidadeBase));
    grupo.quantidadeBase += quantidadeBase;
  }
  return grupos;
}

// Uma variação que arredonda a 0,0% não conta como aumento nem como redução.
double _arredondada(double v) => double.parse(v.toStringAsFixed(1));

class DadosRelatorio {
  const DadosRelatorio(this.mes, this.itensLista, this.compras, this.itensCompra, this.produtos, this.mesAnterior, this.itensAnteriores);
  final Mes mes;
  final List<ItemLista> itensLista;
  final List<Compra> compras;
  final List<ItemCompra> itensCompra;
  final Map<String, Produto> produtos;
  final Mes? mesAnterior;
  final List<ItemCompra> itensAnteriores;
}

Relatorio calcularRelatorio(DadosRelatorio d) {
  String nome(String id) => d.produtos[id]?.nome ?? 'Produto removido';
  final gasto = calc.totalReal(d.itensCompra.map((i) => i.precoReal));
  final sobrou = d.mes.plafond - gasto;
  final previsto = calc.totalPrevisto(d.itensLista.map((i) => calc.Linha(i.quantidadePrevista, i.precoUnitarioPrevisto)));

  // Preços face ao mês anterior (§26): só produtos comprados nos dois meses, na mesma unidade de base.
  final actuais = _precosPorProduto(d.itensCompra);
  final anteriores = _precosPorProduto(d.itensAnteriores);
  final precos = <PrecoComparado>[];
  actuais.forEach((chave, g) {
    final a = anteriores[chave];
    final mediaActual = g.precoMedio;
    final mediaAnterior = a?.precoMedio;
    if (a == null || mediaActual == null || mediaAnterior == null) return;
    precos.add(PrecoComparado(g.produtoId, nome(g.produtoId), g.unidadeBase, mediaAnterior, mediaActual,
        calc.variacaoPercentual(mediaActual, mediaAnterior), g.quantidadeBase));
  });
  precos.sort((x, y) {
    final porVariacao = (y.variacao ?? 0).compareTo(x.variacao ?? 0);
    return porVariacao != 0 ? porVariacao : x.nome.compareTo(y.nome);
  });

  // Maiores alterações (§27).
  final aumentos = precos.where((p) => _arredondada(p.variacao ?? 0) > 0).toList();
  final reducoes = precos.where((p) => _arredondada(p.variacao ?? 0) < 0).toList();
  final gastoPorProduto = <String, int>{};
  for (final i in d.itensCompra) {
    gastoPorProduto[i.produtoId] = (gastoPorProduto[i.produtoId] ?? 0) + i.precoReal;
  }
  MapEntry<String, int>? maiorDespesa;
  for (final e in gastoPorProduto.entries) {
    if (maiorDespesa == null || e.value > maiorDespesa.value) maiorDespesa = e;
  }

  // Onde gastou (§28): barras proporcionais à parte de cada estabelecimento no gasto total.
  final porLoja = <String, List<Object>>{};
  for (final c in d.compras) {
    final total = d.itensCompra.where((i) => i.compraId == c.id).fold<int>(0, (s, i) => s + i.precoReal);
    if (total == 0) continue;
    final chave = normalizarNome(c.estabelecimento);
    final actual = porLoja[chave];
    porLoja[chave] = actual == null
        ? [c.estabelecimento, total, 1]
        : [actual[0], (actual[1] as int) + total, (actual[2] as int) + 1];
  }
  final ondeGastou = porLoja.values
      .map((l) => Loja(l[0] as String, l[1] as int, l[2] as int, gasto > 0 ? (l[1] as int) / gasto * 100 : 0))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  // Cabaz habitual (§29): os mesmos produtos, nas quantidades deste mês, aos preços de cada mês.
  final cabazHabitual = precos.length >= minProdutosCabaz
      ? calc.cabaz(precos.map((p) => calc.ParCabaz(p.quantidadeBase, p.actual, p.anterior)))
      : null;

  return Relatorio(
    mesId: d.mes.id,
    rotulo: rotuloMes(d.mes.ano, d.mes.mes),
    nomeMes: nomeMes(d.mes.mes),
    plafond: d.mes.plafond,
    gasto: gasto,
    sobrou: sobrou,
    previsto: previsto.total,
    previstoSemPreco: previsto.semPreco,
    artigosNaLista: d.itensLista.length,
    diferencaPrevisto: d.itensLista.isNotEmpty && previsto.total > 0 ? gasto - previsto.total : null,
    mesAnteriorNome: d.mesAnterior == null ? null : nomeMes(d.mesAnterior!.mes),
    precos: precos,
    maiorAumento: aumentos.isEmpty ? null : aumentos.first,
    maiorReducao: reducoes.isEmpty ? null : reducoes.last,
    maiorDespesaNome: maiorDespesa == null ? null : nome(maiorDespesa.key),
    maiorDespesaTotal: maiorDespesa?.value,
    ondeGastou: ondeGastou,
    cabaz: cabazHabitual,
    compras: d.compras.length,
    artigosComprados: d.itensCompra.length,
  );
}

/// Reúne, dentro de uma transacção, os dados do mês e do último mês anterior com compras.
Future<DadosRelatorio> recolherDadosRelatorio(DatabaseExecutor t, String mesId) async {
  final mes = await obterMesEm(t, mesId);
  if (mes == null) throw const ErroKussumba('Este mês não existe.');
  final mesesAntes = (await todasAsLinhas(t, 'meses')).map(Mes.daLinha).where((m) => m.id.compareTo(mesId) < 0).toList()
    ..sort((a, b) => b.id.compareTo(a.id));
  Mes? anterior;
  var itensAnteriores = <ItemCompra>[];
  for (final m in mesesAntes) {
    final itens = await artigosDoMes(t, m.id);
    if (itens.isNotEmpty) {
      anterior = m;
      itensAnteriores = itens;
      break;
    }
  }
  return DadosRelatorio(mes, await itensDoMes(t, mesId), await comprasDoMes(t, mesId), await artigosDoMes(t, mesId),
      await produtosPorId(t), anterior, itensAnteriores);
}

/// Relatório de um mês. Num mês fechado, devolve o resumo congelado no fecho.
Future<Relatorio> relatorioMes(String mesId) => transaccao((t) async {
      final mes = await obterMesEm(t, mesId);
      if (mes != null && mes.estado == 'fechado' && mes.resumoFecho != null) {
        return Relatorio.deJson(mes.resumoFecho!);
      }
      final r = calcularRelatorio(await recolherDadosRelatorio(t, mesId));
      return Relatorio.deJson(r.paraJson(), congelado: false);
    });
