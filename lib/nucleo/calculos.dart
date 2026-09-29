// Regras de cálculo da KUSSUMBA (prompt mestre, §43).
// Todas as telas usam estas funções. Nenhuma tela faz contas por conta própria.
// Quando falta um dado ou haveria divisão por zero, as funções devolvem null em vez de inventar um valor.

import 'formatos.dart';

bool _numero(num? v) => v != null && v.isFinite;

/// Saldo = plafond − gasto real.
num? saldo(num? plafond, num? gastoReal) {
  if (!_numero(plafond) || !_numero(gastoReal)) return null;
  return plafond! - gastoReal!;
}

/// Percentagem utilizada = gasto real / plafond × 100.
double? percentagemUtilizada(num? gastoReal, num? plafond) {
  if (!_numero(gastoReal) || !_numero(plafond) || plafond! <= 0) return null;
  return gastoReal! / plafond * 100;
}

/// Preço total de uma linha = quantidade × preço unitário, arredondado ao Kz.
int? precoTotal(num? quantidade, num? precoUnitario) {
  if (!_numero(quantidade) || !_numero(precoUnitario) || quantidade! <= 0) return null;
  return arredondar(quantidade * precoUnitario!);
}

/// Preço unitário = preço total / quantidade.
double? precoUnitario(num? total, num? quantidade) {
  if (!_numero(total) || !_numero(quantidade) || quantidade! <= 0) return null;
  return total! / quantidade;
}

class Linha {
  const Linha(this.quantidade, this.precoUnitario);
  final num? quantidade;
  final num? precoUnitario;
}

class TotalPrevisto {
  const TotalPrevisto(this.total, this.semPreco);
  final int total;
  final int semPreco;
}

/// Total previsto = Σ quantidade × preço unitário previsto.
/// As linhas sem preço previsto não entram na soma e são contadas à parte.
TotalPrevisto totalPrevisto(Iterable<Linha> linhas) {
  var total = 0;
  var semPreco = 0;
  for (final l in linhas) {
    final t = precoTotal(l.quantidade, l.precoUnitario);
    if (t == null) {
      semPreco += 1;
    } else {
      total += t;
    }
  }
  return TotalPrevisto(total, semPreco);
}

/// Total real = Σ preço efectivamente pago em cada linha.
int totalReal(Iterable<int?> precosReais) =>
    precosReais.fold(0, (soma, p) => soma + (p ?? 0));

/// Diferença = total real − total previsto. Positiva quando se pagou mais do que o previsto.
num? diferenca(num? real, num? previsto) {
  if (!_numero(real) || !_numero(previsto)) return null;
  return real! - previsto!;
}

/// Variação de preço = (actual − anterior) / anterior × 100. Sem preço anterior, não há variação.
double? variacaoPercentual(num? actual, num? anterior) {
  if (!_numero(actual) || !_numero(anterior) || anterior! <= 0) return null;
  return (actual! - anterior) / anterior * 100;
}

/// Média diária = total gasto / dias decorridos.
double? mediaDiaria(num? gastoReal, num? diasDecorridos) {
  if (!_numero(gastoReal) || !_numero(diasDecorridos) || diasDecorridos! <= 0) return null;
  return gastoReal! / diasDecorridos;
}

/// Previsão mensal = média diária × dias do mês.
int? previsaoMensal(num? media, num? diasDoMes) {
  if (!_numero(media) || !_numero(diasDoMes) || diasDoMes! <= 0) return null;
  return arredondar(media! * diasDoMes);
}

/// Previsão das compras restantes = saldo actual − total previsto do que falta comprar.
num? coberturaDaLista(num? saldoActual, num? pendentePrevisto) {
  if (!_numero(saldoActual) || !_numero(pendentePrevisto)) return null;
  return saldoActual! - pendentePrevisto!;
}

class Registo {
  const Registo(this.precoTotal, this.quantidadeBase);
  final num? precoTotal;
  final num? quantidadeBase;
}

/// Preço médio ponderado por unidade de base: Σ preço pago / Σ quantidade.
double? precoMedioPonderado(Iterable<Registo> registos) {
  num pago = 0;
  num quantidade = 0;
  for (final r in registos) {
    if (!_numero(r.precoTotal) || !_numero(r.quantidadeBase) || r.quantidadeBase! <= 0) continue;
    pago += r.precoTotal!;
    quantidade += r.quantidadeBase!;
  }
  return quantidade > 0 ? pago / quantidade : null;
}

class ParCabaz {
  const ParCabaz(this.quantidade, this.precoActual, this.precoAnterior);
  final num? quantidade;
  final num? precoActual;
  final num? precoAnterior;
}

class Cabaz {
  const Cabaz(this.actual, this.anterior, this.variacao);
  final int actual;
  final int anterior;
  final double? variacao;
}

/// Cabaz habitual: quanto custa o mesmo conjunto de produtos, nas mesmas quantidades,
/// aos preços de cada mês.
Cabaz? cabaz(Iterable<ParCabaz> pares) {
  num actual = 0;
  num anterior = 0;
  for (final p in pares) {
    if (!_numero(p.quantidade) || !_numero(p.precoActual) || !_numero(p.precoAnterior)) continue;
    actual += p.quantidade! * p.precoActual!;
    anterior += p.quantidade! * p.precoAnterior!;
  }
  if (anterior <= 0) return null;
  return Cabaz(arredondar(actual), arredondar(anterior), variacaoPercentual(actual, anterior));
}

/// Plafond ajustado à variação do cabaz, arredondado a múltiplos de 500 Kz.
int? sugestaoPlafond(num? plafond, num? variacao, [int multiplo = 500]) {
  if (!_numero(plafond) || !_numero(variacao) || plafond! <= 0) return null;
  return arredondar(plafond * (1 + variacao! / 100) / multiplo) * multiplo;
}

/// Percentagem limitada entre 0 e 100, para larguras de barras.
double limitarPercentagem(num? valor) {
  if (!_numero(valor)) return 0;
  return valor!.clamp(0, 100).toDouble();
}
