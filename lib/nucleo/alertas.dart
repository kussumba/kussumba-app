// Regras de alertas (prompt mestre, §37). Funções puras: recebem números e devolvem mensagens.
// Níveis: "perigo" (ultrapassagem), "aviso" (atenção), "positivo" (poupança) e "info".

import 'formatos.dart';

class Alerta {
  const Alerta(this.tipo, this.nivel, this.texto);
  final String tipo;
  final String nivel;
  final String texto;
}

/// A partir desta percentagem do plafond, a KUSSUMBA avisa que o orçamento está perto do limite.
const int limiarProximoLimite = 70;

/// Subida de preço, face à compra anterior, a partir da qual a KUSSUMBA chama a atenção.
const int limiarSubidaSignificativa = 10;

/// A média diária só serve para prever o mês depois de alguns dias.
const int diasMinimosRitmo = 7;

/// Um valor mais de 5 vezes acima ou abaixo da referência parece engano de digitação.
const int factorEstranho = 5;

String _plural(int n, String singular, String plural) => n == 1 ? singular : plural;

/// Alertas do orçamento do mês, por ordem de prioridade. A tela Mês mostra só o primeiro.
List<Alerta> alertasOrcamento({
  required num plafond,
  required num gasto,
  required double? percentagem,
  required int diasRestantes,
  required int? previsaoMensal,
  required int diasDecorridos,
  required bool mesTerminado,
  required String nomeDoMes,
}) {
  final alertas = <Alerta>[];
  if (mesTerminado) {
    alertas.add(Alerta('mes_terminado', 'info', '$nomeDoMes já terminou. Quando quiseres, fecha o mês no Relatório.'));
  }
  if (gasto > plafond) {
    alertas.add(Alerta('orcamento_ultrapassado', 'perigo', 'Orçamento ultrapassado em ${formatarKz(gasto - plafond)}.'));
  } else if (percentagem != null && percentagem >= limiarProximoLimite && !mesTerminado) {
    final dias = diasRestantes > 0
        ? ' e ${_plural(diasRestantes, 'falta', 'faltam')} $diasRestantes ${_plural(diasRestantes, 'dia', 'dias')} para o fim do mês'
        : '';
    alertas.add(Alerta('proximo_limite', 'aviso',
        'Já usaste ${formatarPercentagem(percentagem, casas: 0)} do plafond$dias.'));
  }
  if (!mesTerminado &&
      gasto <= plafond &&
      previsaoMensal != null &&
      diasDecorridos >= diasMinimosRitmo &&
      previsaoMensal > plafond) {
    alertas.add(Alerta('previsao_acima', 'aviso',
        'Ao ritmo actual, o mês pode fechar ${formatarKz(previsaoMensal - plafond)} acima do plafond.'));
  }
  return alertas;
}

/// Lista por comprar comparada com o saldo. Devolve null quando não há nada a dizer.
Alerta? alertaLista({required num pendente, required num saldo, required int artigosPendentes}) {
  if (artigosPendentes == 0 || pendente <= 0) return null;
  if (pendente > saldo) {
    return const Alerta('lista_acima_saldo', 'aviso', 'Ei, comadre! A tua lista está acima do saldo disponível.');
  }
  return null;
}

const Map<String, String> _contraccoes = {'o': 'do', 'a': 'da', 'os': 'dos', 'as': 'das'};

// Produtos do catálogo têm género: "do óleo alimentar", "da fuba de milho", "dos ovos".
// Produtos criados pelo utilizador ficam como foram escritos: "de Coca-Cola".
String _artigoDe(String? nome, String? genero) {
  final n = (nome ?? '').trim();
  if (n.isEmpty) return 'deste produto';
  final contraccao = _contraccoes[genero];
  return contraccao != null ? '$contraccao ${n.toLowerCase()}' : 'de $n';
}

/// Variação do preço face à última compra do mesmo produto.
Alerta? alertaPreco({required String nomeProduto, String? genero, required double? variacao}) {
  if (variacao == null) return null;
  if (variacao >= limiarSubidaSignificativa) {
    return Alerta('preco_subiu', 'aviso',
        'Atenção, comadre: o preço ${_artigoDe(nomeProduto, genero)} subiu ${formatarPercentagem(variacao)} desde a última compra.');
  }
  if (variacao < 0) {
    return Alerta('preco_desceu', 'positivo',
        'O preço ${_artigoDe(nomeProduto, genero)} está ${formatarPercentagem(variacao.abs())} mais baixo do que na última compra.');
  }
  return null;
}

/// Mensagem no fim de uma compra, só quando há comparação possível com o previsto.
Alerta? alertaFimCompra(num? diferenca) {
  if (diferenca == null) return null;
  if (diferenca < 0) {
    return const Alerta('compra_abaixo', 'positivo', 'Boa, comadre! Gastaste menos do que o previsto nesta compra.');
  }
  if (diferenca > 0) {
    return Alerta('compra_acima', 'aviso', 'Esta compra ficou ${formatarKz(diferenca)} acima do previsto.');
  }
  return const Alerta('compra_igual', 'info', 'Esta compra ficou exactamente no previsto.');
}

/// Um valor mais de 5 vezes acima ou abaixo da referência parece engano de digitação.
bool pareceEngano(num? valor, num? referencia, [int factor = factorEstranho]) {
  bool valido(num? n) => n != null && n.isFinite && n > 0;
  if (!valido(valor) || !valido(referencia)) return false;
  return valor! > referencia! * factor || valor < referencia / factor;
}

/// Motivo para confirmar um preço pago antes de o gravar, ou null se parecer normal.
String? motivoPrecoEstranho({
  required int? precoReal,
  num? plafond,
  num? precoUnitarioBase,
  num? anteriorUnitarioBase,
  num? previsto,
}) {
  if (precoReal == null || precoReal == 0) return null;
  if (plafond != null && plafond > 0 && precoReal > plafond) return 'é maior do que o plafond do mês inteiro';
  if (pareceEngano(precoUnitarioBase, anteriorUnitarioBase)) return 'está muito longe do preço da última compra';
  if (pareceEngano(precoReal, previsto)) return 'está muito longe do previsto';
  return null;
}
