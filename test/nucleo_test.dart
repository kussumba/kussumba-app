// Testes da camada de cálculos e formatos, com os exemplos do prompt mestre.
// São os mesmos casos da versão web (testes/nucleo.teste.js), para garantir resultados idênticos.

import 'package:flutter_test/flutter_test.dart';
import 'package:kussumba/nucleo/alertas.dart' as a;
import 'package:kussumba/nucleo/calculos.dart' as c;
import 'package:kussumba/nucleo/datas.dart' as d;
import 'package:kussumba/nucleo/formatos.dart' as f;
import 'package:kussumba/nucleo/unidades.dart' as u;

/// Escreve o texto como a interface o mostra: espaço inseparável depois de um algarismo e sinal de menos.
String ui(String texto) => texto
    .replaceAllMapped(RegExp(r'(\d) '), (m) => '${m[1]} ')
    .replaceAllMapped(RegExp(r'(^|[^\w])-(?=\d)'), (m) => '${m[1]}−');

void main() {
  group('formatos (§34)', () {
    test('valores em Kz sem casas decimais', () {
      expect(f.formatarKz(250000), ui('250 000 Kz'));
      expect(f.formatarKz(67600), ui('67 600 Kz'));
      expect(f.formatarKz(1280), ui('1 280 Kz'));
      expect(f.formatarKz(500), ui('500 Kz'));
      expect(f.formatarKz(0), ui('0 Kz'));
      expect(f.formatarKz(1234567), ui('1 234 567 Kz'));
      expect(f.formatarKz(-25200), ui('-25 200 Kz'));
      expect(f.formatarKz(double.nan), '');
      expect(f.formatarKz(null), '');
    });

    test('Kz com sinal', () {
      expect(f.formatarKzComSinal(500), ui('+500 Kz'));
      expect(f.formatarKzComSinal(-500), ui('-500 Kz'));
      expect(f.formatarKzComSinal(8700), ui('+8 700 Kz'));
      expect(f.formatarKzComSinal(0), ui('0 Kz'));
    });

    test('números com vírgula decimal', () {
      expect(f.formatarNumero(2.5, 3), '2,5');
      expect(f.formatarNumero(25, 3), '25');
      expect(f.formatarNumero(0.125, 3), '0,125');
      expect(f.formatarNumero(2266.6667), ui('2 267'));
    });

    test('percentagens', () {
      expect(f.formatarPercentagem(6.6667, sinal: true), '+6,7%');
      expect(f.formatarPercentagem(-8.3333, sinal: true), ui('-8,3%'));
      expect(f.formatarPercentagem(0, sinal: true), '0%');
      expect(f.formatarPercentagem(11.7647), '11,8%');
      expect(f.formatarPercentagem(72.96, casas: 0), '73%');
      expect(f.formatarPercentagem(5, sinal: true), '+5%');
      expect(f.formatarPercentagem(0.04, sinal: true), '0%');
    });

    test('leitura do que o utilizador escreve', () {
      expect(f.lerKz('250 000'), 250000);
      expect(f.lerKz(ui('250 000 Kz')), 250000);
      expect(f.lerKz(''), isNull);
      expect(f.lerKz('abc'), isNull);
      expect(f.lerDecimal('2,5'), 2.5);
      expect(f.lerDecimal('2.5'), 2.5);
      expect(f.lerDecimal('10'), 10);
      expect(f.lerDecimal('2,5,1'), isNull);
      expect(f.lerDecimal(''), isNull);
      expect(f.lerDecimal('-3'), isNull);
      expect(f.formatarDigitacaoKz('0250000'), ui('250 000'));
      expect(f.formatarDigitacaoKz('12a3'), '123');
    });
  });

  group('unidades (§12, §14)', () {
    test('conversão para a base e comparabilidade', () {
      expect(u.paraBase(500, 'g'), 0.5);
      expect(u.paraBase(250, 'ml'), 0.25);
      expect(u.paraBase(25, 'kg'), 25);
      expect(u.unidadeBase('g'), 'kg');
      expect(u.unidadeBase('ml'), 'L');
      expect(u.unidadeBase('pacote'), 'pacote');
      expect(u.saoComparaveis(u.unidadeBase('g'), u.unidadeBase('kg')), isTrue);
      expect(u.saoComparaveis(u.unidadeBase('kg'), u.unidadeBase('pacote')), isFalse);
      expect(u.saoComparaveis(u.unidadeBase('outro', 'molho'), u.unidadeBase('outro', 'kit')), isFalse);
      expect(u.saoComparaveis(u.unidadeBase('outro', 'Molho'), u.unidadeBase('outro', 'molho ')), isTrue);
    });

    test('quantidades e preço por unidade', () {
      expect(u.formatarQuantidade(25, 'kg'), ui('25 kg'));
      expect(u.formatarQuantidade(2.5, 'kg'), ui('2,5 kg'));
      expect(u.formatarQuantidade(1, 'lata'), ui('1 lata'));
      expect(u.formatarQuantidade(3, 'pacote'), ui('3 pacotes'));
      expect(u.formatarQuantidade(2, 'cartao'), ui('2 cartões'));
      expect(u.formatarQuantidade(3, 'outro', 'molhos'), ui('3 molhos'));
      expect(u.formatarPrecoUnitario(1280, 'kg'), ui('1 280 Kz/kg'));
      expect(u.formatarPrecoUnitario(2000, 'L'), ui('2 000 Kz/L'));
      expect(u.formatarPrecoUnitario(150, 'unidade'), ui('150 Kz/un.'));
      expect(u.formatarPrecoUnitario(6800 / 3, 'kg'), ui('2 267 Kz/kg'));
    });

    test('botões − e + nunca levam a quantidade a zero', () {
      expect(u.passoQuantidade(25, 'kg', 1), 26);
      expect(u.passoQuantidade(25, 'kg', -1), 24);
      expect(u.passoQuantidade(1, 'kg', -1), 1);
      expect(u.passoQuantidade(2.5, 'kg', -1), 1.5);
      expect(u.passoQuantidade(0.5, 'kg', -1), 0.5);
      expect(u.passoQuantidade(500, 'g', 1), 600);
      expect(u.passoQuantidade(100, 'g', -1), 100);
    });
  });

  group('cálculos (§43) com os exemplos do documento', () {
    test('saldo e percentagem utilizada (§5)', () {
      expect(c.saldo(250000, 182400), 67600);
      expect(c.percentagemUtilizada(182400, 250000), closeTo(72.96, 1e-9));
      expect(f.formatarPercentagem(c.percentagemUtilizada(182400, 250000), casas: 0), '73%');
      expect(c.saldo(250000, 260000), -10000);
      expect(c.percentagemUtilizada(1000, 0), isNull);
      expect(c.saldo(null, 100), isNull);
    });

    test('previsão das compras restantes (§6)', () {
      expect(c.coberturaDaLista(67600, 92800), -25200);
      expect(c.coberturaDaLista(67600, 50000), 17600);
    });

    test('ritmo de gastos (§7)', () {
      expect(c.mediaDiaria(182400, 18), closeTo(10133.333, 0.001));
      expect(c.previsaoMensal(c.mediaDiaria(182400, 18), 30), 304000);
      expect(c.mediaDiaria(182400, 0), isNull);
      expect(c.previsaoMensal(null, 30), isNull);
    });

    test('preço unitário (§14)', () {
      expect(c.precoUnitario(32000, 25), 1280);
      expect(c.precoUnitario(10000, 5), 2000);
      expect(c.precoUnitario(18000, 2.5), 7200);
      expect(c.precoUnitario(100, 0), isNull);
      expect(c.precoUnitario(null, 5), isNull);
    });

    test('total previsto da lista de Setembro (§9)', () {
      final lista = [
        const c.Linha(25, 1280),
        const c.Linha(5, 1900),
        const c.Linha(10, 1100),
        const c.Linha(5, 1500),
        const c.Linha(10, 800),
        c.Linha(3, 6800 / 3),
        const c.Linha(2.5, 7200),
      ];
      final t = c.totalPrevisto(lista);
      expect([t.total, t.semPreco], [92800, 0]);
      final comSemPreco = c.totalPrevisto([...lista, const c.Linha(1, null)]);
      expect([comSemPreco.total, comSemPreco.semPreco], [92800, 1]);
      final vazia = c.totalPrevisto([]);
      expect([vazia.total, vazia.semPreco], [0, 0]);
    });

    test('preço pago e diferença (§19, §21)', () {
      expect(c.diferenca(10000, 9500), 500);
      expect(c.diferenca(93300, 92800), 500);
      expect(c.diferenca(238700, 230000), 8700);
      expect(c.diferenca(100, null), isNull);
      expect(c.totalReal([32000, 10000, null]), 42000);
    });

    test('variação de preço (§15, §20, §26)', () {
      expect(c.variacaoPercentual(1280, 1200), closeTo(6.6667, 0.0001));
      expect(f.formatarPercentagem(c.variacaoPercentual(1280, 1200), sinal: true), '+6,7%');
      expect(f.formatarPercentagem(c.variacaoPercentual(2000, 1900), sinal: true), '+5,3%');
      expect(f.formatarPercentagem(c.variacaoPercentual(1900, 1700), sinal: true), '+11,8%');
      expect(f.formatarPercentagem(c.variacaoPercentual(1500, 1500), sinal: true), '0%');
      expect(f.formatarPercentagem(c.variacaoPercentual(1100, 1200), sinal: true), ui('-8,3%'));
      expect(c.variacaoPercentual(1280, null), isNull);
      expect(c.variacaoPercentual(1280, 0), isNull);
    });

    test('redução de quantidade durante a compra (§22)', () {
      final previstoAjustado = c.precoTotal(3, 1900);
      expect(previstoAjustado, 5700);
      expect(c.precoUnitario(6000, 3), 2000);
      expect(c.diferenca(6000, previstoAjustado), 300);
    });

    test('preço médio ponderado', () {
      expect(c.precoMedioPonderado(const [c.Registo(32000, 25), c.Registo(6000, 5)]), closeTo(38000 / 30, 1e-9));
      expect(c.precoMedioPonderado(const []), isNull);
      expect(c.precoMedioPonderado(const [c.Registo(100, 0)]), isNull);
    });

    test('cabaz habitual e sugestão de plafond (§29, tela Novo mês)', () {
      final r = c.cabaz(const [c.ParCabaz(25, 1280, 1200), c.ParCabaz(5, 1900, 1700), c.ParCabaz(10, 1100, 1200)])!;
      expect(r.actual, 32000 + 9500 + 11000);
      expect(r.anterior, 30000 + 8500 + 12000);
      expect(r.variacao, closeTo((52500 - 50500) / 50500 * 100, 1e-9));
      expect(c.cabaz(const []), isNull);
      expect(f.formatarPercentagem(c.variacaoPercentual(198400, 187600), sinal: true), '+5,8%');
      expect(c.sugestaoPlafond(250000, 3.4), 258500);
      expect(c.sugestaoPlafond(250000, null), isNull);
    });

    test('fecho do mês (§24)', () {
      expect(c.saldo(250000, 238700), 11300);
    });
  });

  group('datas', () {
    test('meses, dias decorridos e restantes', () {
      final hoje = DateTime(2026, 9, 18, 10);
      expect(d.rotuloMes(2026, 9), 'Setembro 2026');
      expect(d.diasNoMes(2026, 9), 30);
      expect(d.diasNoMes(2028, 2), 29);
      expect(d.diasDecorridos(2026, 9, hoje), 18);
      expect(d.diasRestantes(2026, 9, hoje), 12);
      expect(d.diasDecorridos(2026, 10, hoje), 0);
      expect(d.diasDecorridos(2026, 8, hoje), 31);
      expect(d.mesSeguinte(const d.AnoMes(2026, 12)), const d.AnoMes(2027, 1));
      expect(d.mesAnterior(const d.AnoMes(2027, 1)), const d.AnoMes(2026, 12));
      expect(d.idMes(2026, 9), '2026-09');
      expect(d.formatarDataCurta('2026-09-02'), '02 Set');
      expect(d.formatarDataLonga('2026-09-02'), '2 de Setembro de 2026');
      expect(d.dataIso(DateTime(2026, 9, 2, 23, 30)), '2026-09-02');
      expect(d.dataValida('2026-02-30'), isFalse);
      expect(d.dataValida('2026-09-02'), isTrue);
    });
  });

  group('alertas (§37)', () {
    test('orçamento perto do limite, como na tela de referência', () {
      final r = a.alertasOrcamento(plafond: 250000, gasto: 182400, percentagem: 72.96, diasRestantes: 12,
          previsaoMensal: 304000, diasDecorridos: 18, mesTerminado: false, nomeDoMes: 'Setembro');
      expect(r[0].tipo, 'proximo_limite');
      expect(r[0].texto, 'Já usaste 73% do plafond e faltam 12 dias para o fim do mês.');
      expect(r[1].tipo, 'previsao_acima');
      expect(r[1].texto, ui('Ao ritmo actual, o mês pode fechar 54 000 Kz acima do plafond.'));
    });

    test('orçamento ultrapassado', () {
      final r = a.alertasOrcamento(plafond: 250000, gasto: 262000, percentagem: 104.8, diasRestantes: 3,
          previsaoMensal: 280000, diasDecorridos: 27, mesTerminado: false, nomeDoMes: 'Setembro');
      expect(r.length, 1);
      expect(r[0].texto, ui('Orçamento ultrapassado em 12 000 Kz.'));
    });

    test('sem avisos quando está tudo dentro do orçamento', () {
      expect(a.alertasOrcamento(plafond: 250000, gasto: 50000, percentagem: 20, diasRestantes: 20,
          previsaoMensal: 150000, diasDecorridos: 10, mesTerminado: false, nomeDoMes: 'Setembro'), isEmpty);
    });

    test('previsão pelo ritmo só depois de alguns dias', () {
      expect(a.alertasOrcamento(plafond: 250000, gasto: 128900, percentagem: 51.56, diasRestantes: 28,
          previsaoMensal: 1933500, diasDecorridos: 2, mesTerminado: false, nomeDoMes: 'Setembro'), isEmpty);
    });

    test('lista acima do saldo', () {
      expect(a.alertaLista(pendente: 92800, saldo: 67600, artigosPendentes: 7)!.texto,
          'Ei, comadre! A tua lista está acima do saldo disponível.');
      expect(a.alertaLista(pendente: 50000, saldo: 67600, artigosPendentes: 3), isNull);
      expect(a.alertaLista(pendente: 0, saldo: 67600, artigosPendentes: 0), isNull);
    });

    test('valores que parecem engano de digitação (auditoria SEC-007)', () {
      expect(a.pareceEngano(1280, 1200), isFalse);
      expect(a.pareceEngano(12800000, 1280), isTrue);
      expect(a.pareceEngano(128, 1280), isTrue);
      expect(a.pareceEngano(300, 1280), isFalse);
      expect(a.pareceEngano(100, null), isFalse);
      expect(a.motivoPrecoEstranho(precoReal: 300000, plafond: 250000), 'é maior do que o plafond do mês inteiro');
      expect(a.motivoPrecoEstranho(precoReal: 320000, plafond: 500000, precoUnitarioBase: 12800, anteriorUnitarioBase: 1200),
          'está muito longe do preço da última compra');
      expect(a.motivoPrecoEstranho(precoReal: 95000, plafond: 500000, previsto: 9500), 'está muito longe do previsto');
      expect(a.motivoPrecoEstranho(precoReal: 10000, plafond: 250000, precoUnitarioBase: 2000, anteriorUnitarioBase: 1900, previsto: 9500),
          isNull);
    });

    test('preços e fim de compra', () {
      expect(a.alertaPreco(nomeProduto: 'Óleo alimentar', genero: 'o', variacao: 11.76)!.texto,
          'Atenção, comadre: o preço do óleo alimentar subiu 11,8% desde a última compra.');
      expect(a.alertaPreco(nomeProduto: 'Fuba de milho', genero: 'a', variacao: 5), isNull);
      expect(a.alertaPreco(nomeProduto: 'Açúcar', genero: 'o', variacao: -8.33)!.nivel, 'positivo');
      expect(a.alertaPreco(nomeProduto: 'Coca-Cola', variacao: 12)!.texto.contains('de Coca-Cola'), isTrue);
      expect(a.alertaPreco(nomeProduto: 'Arroz', variacao: null), isNull);
      expect(a.alertaFimCompra(-1200)!.texto, 'Boa, comadre! Gastaste menos do que o previsto nesta compra.');
      expect(a.alertaFimCompra(null), isNull);
    });
  });
}
