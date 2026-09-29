// Testes dos serviços de negócio com a base de dados real (SQLite em memória).
// Mesmos cenários da versão web (testes/servicos.teste.js).

import 'package:flutter_test/flutter_test.dart';
import 'package:kussumba/dados/base_dados.dart';
import 'package:kussumba/dados/catalogo_inicial.dart';
import 'package:kussumba/dados/modelos.dart';
import 'package:kussumba/nucleo/datas.dart';
import 'package:kussumba/nucleo/formatos.dart';
import 'package:kussumba/servicos/compras.dart' as compras;
import 'package:kussumba/servicos/lista.dart' as lista;
import 'package:kussumba/servicos/meses.dart' as meses;
import 'package:kussumba/servicos/produtos.dart' as produtos;
import 'package:kussumba/servicos/relatorio.dart' as relatorio;

import 'apoio.dart';

Future<Mes> comecar(int ano, int mes, int dia, [int plafond = 250000]) async {
  await baseDeDadosNova();
  relogio(ano, mes, dia);
  return meses.configurarInicio(plafond: plafond);
}

Future<lista.ItemDaLista> itemDe(String mesId, String produtoId) async =>
    (await lista.obterLista(mesId)).itens.firstWhere((i) => i.produtoId == produtoId);

Future<int> contarHistorico() async => (await transaccao((t) => todasAsLinhas(t, 'historico_precos'))).length;

/// Agosto com uma compra; fecha Agosto e cria Setembro copiando a lista.
Future<(Mes, Mes)> cenarioAgostoSetembro() async {
  final agosto = await comecar(2026, 8, 5, 240000);
  for (final (id, qtd) in [('cat-arroz', 25), ('cat-oleo', 5), ('cat-feijao', 5), ('cat-acucar', 10)]) {
    await lista.adicionarProduto(agosto.id, id, qtd);
  }
  final compra = await compras.iniciarCompra(estabelecimento: 'Grossista Kikolo', data: '2026-08-05');
  for (final (produtoId, preco) in [('cat-arroz', 30000), ('cat-oleo', 8500), ('cat-feijao', 7500), ('cat-acucar', 12000)]) {
    final item = await itemDe(agosto.id, produtoId);
    await compras.registarArtigo(
        compraId: compra.id, itemListaId: item.id, quantidade: item.item.quantidadePrevista, precoReal: preco);
  }
  await compras.concluirCompra(compra.id);
  relogio(2026, 8, 31);
  await meses.fecharMes(agosto.id);
  relogio(2026, 9, 1);
  final setembro = await meses.criarMes(plafond: 250000, copiarDe: agosto.id);
  return (agosto, setembro);
}

/// Setembro: compra no Armazém do Cazenga com os preços das telas de referência.
Future<Compra> compraSetembro(Mes setembro) async {
  relogio(2026, 9, 2);
  final compra = await compras.iniciarCompra(estabelecimento: 'Armazém do Cazenga', data: '2026-09-02');
  for (final (produtoId, preco) in [('cat-arroz', 32000), ('cat-oleo', 9500), ('cat-feijao', 7500), ('cat-acucar', 11000)]) {
    final item = await itemDe(setembro.id, produtoId);
    await compras.registarArtigo(
        compraId: compra.id, itemListaId: item.id, quantidade: item.item.quantidadePrevista, precoReal: preco);
  }
  return compra;
}

void main() {
  tearDown(() => definirRelogio(null));

  group('dados', () {
    test('a base de dados abre com o catálogo inicial, sem preços', () async {
      await baseDeDadosNova();
      final todos = await produtos.listarProdutos();
      expect(todos.length, produtosIniciais.length);
      expect(todos.first.id, 'cat-arroz');
      expect(todos.first.quantidadeSugerida, 25);
    });

    test('uma operação que falha a meio não deixa nada gravado', () async {
      await baseDeDadosNova();
      await deveFalhar(
          () => transaccao((t) async {
                await guardarLinha(t, 'meses', {'id': '2026-09', 'ano': 2026, 'mes': 9, 'plafond': 1, 'estado': 'aberto'});
                throw StateError('falha simulada');
              }),
          'falha simulada');
      expect(await transaccao((t) => obterLinha(t, 'meses', '2026-09')), isNull);
    });

    test('pesquisa sem acentos', () {
      expect(normalizarNome('  Açúcar  '), 'acucar');
      expect(normalizarNome('Papel   Higiénico'), 'papel higienico');
    });
  });

  group('primeira utilização e meses', () {
    test('cria o utilizador e o mês em curso', () async {
      final mes = await comecar(2026, 9, 18);
      expect(mes.id, '2026-09');
      expect(mes.plafond, 250000);
      final u = await meses.obterUtilizador();
      expect(u!.moeda, 'AOA');
      expect(u.nome, isNull, reason: 'não recolhe dados pessoais');
      await deveFalhar(() => meses.configurarInicio(plafond: 100000), 'já está configurada');
    });

    test('plafond tem de ser maior do que zero', () async {
      await baseDeDadosNova();
      await deveFalhar(() => meses.configurarInicio(plafond: 0), 'plafond');
      await deveFalhar(() => meses.configurarInicio(plafond: null), 'plafond');
    });

    test('mês seguinte ao fecho, saltando meses sem uso', () {
      expect(meses.proximoMes(const AnoMes(2026, 9), DateTime(2026, 9, 28)), const AnoMes(2026, 10));
      expect(meses.proximoMes(const AnoMes(2026, 9), DateTime(2026, 12, 5)), const AnoMes(2026, 12));
      expect(meses.proximoMes(const AnoMes(2026, 12), DateTime(2026, 12, 31)), const AnoMes(2027, 1));
    });
  });

  group('lista', () {
    test('sem repetidos, com quantidade sugerida e sem preço inventado', () async {
      final mes = await comecar(2026, 9, 1);
      final a = await lista.adicionarProduto(mes.id, 'cat-arroz');
      final b = await lista.adicionarProduto(mes.id, 'cat-arroz');
      expect(a.id, b.id);
      expect(a.quantidadePrevista, 25);
      expect(a.precoUnitarioPrevisto, isNull);
      final l = await lista.obterLista(mes.id);
      expect(l.resumo.artigos, 1);
      expect(l.resumo.semPreco, 1);
      expect(l.resumo.estado, 'criada');
    });

    test('começar com produtos sugeridos (§46)', () async {
      final mes = await comecar(2026, 9, 1);
      await lista.adicionarProduto(mes.id, 'cat-arroz');
      expect(await lista.adicionarSugeridos(mes.id), 9);
      expect((await lista.obterLista(mes.id)).resumo.artigos, 10);
    });

    test('preço previsto e quantidade (§13, §14)', () async {
      final mes = await comecar(2026, 9, 1);
      final item = await lista.adicionarProduto(mes.id, 'cat-sabao-po', 3);
      await lista.definirPrecoPrevisto(item.id, 6800);
      var actual = await itemDe(mes.id, 'cat-sabao-po');
      expect(actual.precoTotalPrevisto, 6800);
      expect(formatarKz(actual.precoUnitarioBasePrevisto), ui('2 267 Kz'));
      await lista.alterarQuantidade(item.id, 4);
      actual = await itemDe(mes.id, 'cat-sabao-po');
      expect(actual.precoTotalPrevisto, 9067);
      await lista.actualizarItem(item.id, quantidade: 5, precoTotalPrevisto: null);
      expect((await itemDe(mes.id, 'cat-sabao-po')).precoTotalPrevisto, isNull);
      await deveFalhar(() => lista.alterarQuantidade(item.id, 0), 'quantidade');
      await lista.removerDaLista(item.id);
      expect((await lista.obterLista(mes.id)).itens, isEmpty);
    });

    test('produtos personalizados (§10)', () async {
      await comecar(2026, 9, 1);
      final p = await produtos.criarProduto(nome: '  Coca-Cola  ', categoria: 'bebidas', unidade: 'lata', quantidadeSugerida: 12);
      expect(p.nome, 'Coca-Cola');
      await deveFalhar(() => produtos.criarProduto(nome: 'coca-cola', categoria: 'bebidas', unidade: 'lata'), 'Já existe');
      await deveFalhar(() => produtos.criarProduto(nome: 'acucar', categoria: 'mercearia', unidade: 'kg'), 'Já existe');
      await deveFalhar(() => produtos.criarProduto(nome: 'Kitaba', categoria: 'bebidas', unidade: 'outro'), 'unidade');
      final catalogo = await produtos.listarProdutos();
      expect(catalogo.first.id, 'cat-arroz');
      expect(catalogo.last.nome, 'Coca-Cola');
    });
  });

  group('compras', () {
    test('registo actualiza saldo, lista e histórico (§18 a §21)', () async {
      final mes = await comecar(2026, 9, 2);
      final oleo = await lista.adicionarProduto(mes.id, 'cat-oleo', 5);
      await lista.definirPrecoPrevisto(oleo.id, 9500);
      final compra = await compras.iniciarCompra(estabelecimento: 'Armazém do Cazenga', data: '2026-09-02');
      await deveFalhar(() => compras.iniciarCompra(estabelecimento: 'Outro sítio'), 'Já tens uma compra');
      await compras.registarArtigo(compraId: compra.id, itemListaId: oleo.id, quantidade: 5, precoReal: 10000);
      final d = await compras.detalheCompra(compra.id);
      expect(d.itens.length, 1);
      expect(d.itens.first.diferenca, 500);
      expect(d.itens.first.contas.precoUnitarioBase, 2000);
      expect(d.itens.first.contas.variacao, isNull);
      expect(d.resumo.previsto, 9500);
      expect(d.resumo.real, 10000);
      expect(d.resumo.diferenca, 500);
      expect(d.saldoMes, 240000);
      expect(d.pendentes, isEmpty);
      expect((await lista.obterLista(mes.id)).resumo.estado, 'comprada');
      expect(await contarHistorico(), 1);
      await compras.registarArtigo(compraId: compra.id, itemListaId: oleo.id, quantidade: 5, precoReal: 9800);
      expect((await compras.detalheCompra(compra.id)).resumo.real, 9800);
      expect(await contarHistorico(), 1, reason: 'registar outra vez corrige o registo, não cria outro');
    });

    test('alteração de quantidade durante a compra (§22)', () async {
      final mes = await comecar(2026, 9, 2);
      final oleo = await lista.adicionarProduto(mes.id, 'cat-oleo', 5);
      await lista.definirPrecoPrevisto(oleo.id, 9500);
      final compra = await compras.iniciarCompra(estabelecimento: 'Mercado do 30');
      final item = await compras.registarArtigo(compraId: compra.id, itemListaId: oleo.id, quantidade: 3, precoReal: 6000);
      expect(item.quantidadePlaneada, 5);
      expect(item.precoPrevisto, 5700);
      expect(item.precoUnitarioReal, 2000);
      final d = await compras.detalheCompra(compra.id);
      expect(d.resumo.diferenca, 300);
      expect(d.saldoMes, 244000);
    });

    test('artigo fora da lista e artigo sem preço previsto', () async {
      final mes = await comecar(2026, 9, 2);
      final arroz = await lista.adicionarProduto(mes.id, 'cat-arroz', 25);
      await lista.definirPrecoPrevisto(arroz.id, 30000);
      final feijao = await lista.adicionarProduto(mes.id, 'cat-feijao', 5);
      final compra = await compras.iniciarCompra(estabelecimento: 'Cantina do bairro');
      await compras.registarArtigo(compraId: compra.id, itemListaId: arroz.id, quantidade: 25, precoReal: 31000);
      await compras.registarArtigo(compraId: compra.id, itemListaId: feijao.id, quantidade: 5, precoReal: 7500);
      await compras.registarArtigo(compraId: compra.id, produtoId: 'cat-sal', quantidade: 1, precoReal: 400);
      final r = (await compras.detalheCompra(compra.id)).resumo;
      expect(r.real, 38900);
      expect(r.previsto, 30000);
      expect(r.diferenca, 1000);
      expect(r.semPrevisaoArtigos, 2);
      expect(r.semPrevisaoTotal, 7900);
    });

    test('anular artigo e cancelar compra devolvem tudo ao estado anterior', () async {
      final mes = await comecar(2026, 9, 2);
      final arroz = await lista.adicionarProduto(mes.id, 'cat-arroz', 25);
      final acucar = await lista.adicionarProduto(mes.id, 'cat-acucar', 10);
      final compra = await compras.iniciarCompra(estabelecimento: 'Grossista Kikolo');
      final r1 = await compras.registarArtigo(compraId: compra.id, itemListaId: arroz.id, quantidade: 25, precoReal: 32000);
      await compras.registarArtigo(compraId: compra.id, itemListaId: acucar.id, quantidade: 10, precoReal: 11000);
      await compras.anularArtigo(r1.id);
      expect((await itemDe(mes.id, 'cat-arroz')).comprado, isFalse);
      expect((await compras.detalheCompra(compra.id)).gastoMes, 11000);
      await compras.cancelarCompra(compra.id);
      final painel = await relatorio.painelMes(mes.id);
      expect(painel.orcamento.gasto, 0);
      expect(painel.compras, isEmpty);
      expect(await contarHistorico(), 0);
    });

    test('concluir compra guarda os totais (§23)', () async {
      final mes = await comecar(2026, 9, 2);
      final compra = await compras.iniciarCompra(estabelecimento: 'Grossista Kikolo');
      await deveFalhar(() => compras.concluirCompra(compra.id), 'pelo menos um artigo');
      final arroz = await lista.adicionarProduto(mes.id, 'cat-arroz', 25);
      await lista.definirPrecoPrevisto(arroz.id, 32000);
      await compras.registarArtigo(compraId: compra.id, itemListaId: arroz.id, quantidade: 25, precoReal: 31000);
      final r = await compras.concluirCompra(compra.id);
      expect(r.compra.estado, 'concluida');
      expect(r.compra.totalPrevisto, 32000);
      expect(r.compra.totalReal, 31000);
      expect(r.compra.diferenca, -1000);
      await deveFalhar(
          () => compras.registarArtigo(compraId: compra.id, produtoId: 'cat-sal', quantidade: 1, precoReal: 400), 'concluída');
      expect(await compras.compraEmAndamento(), isNull);
    });

    test('um artigo comprado não pode ser comprado outra vez noutra ida', () async {
      final mes = await comecar(2026, 9, 2);
      final arroz = await lista.adicionarProduto(mes.id, 'cat-arroz', 25);
      final c1 = await compras.iniciarCompra(estabelecimento: 'Grossista Kikolo');
      await compras.registarArtigo(compraId: c1.id, itemListaId: arroz.id, quantidade: 25, precoReal: 32000);
      await compras.concluirCompra(c1.id);
      final c2 = await compras.iniciarCompra(estabelecimento: 'Mercado do 30');
      await deveFalhar(
          () => compras.registarArtigo(compraId: c2.id, itemListaId: arroz.id, quantidade: 25, precoReal: 30000), 'já foi comprado');
      await deveFalhar(() => lista.alterarQuantidade(arroz.id, 30), 'já foi comprado');
    });

    test('a data da compra fica entre o mês anterior e hoje (auditoria SEC-004)', () async {
      final mes = await comecar(2026, 9, 18);
      final intervalo = compras.intervaloDataCompra(AnoMes(mes.ano, mes.mes), DateTime(2026, 9, 18));
      expect(intervalo.min, '2026-08-01');
      expect(intervalo.max, '2026-09-18');
      await deveFalhar(() => compras.iniciarCompra(estabelecimento: 'Erro', data: '2062-09-02'), 'data da compra');
      await deveFalhar(() => compras.iniciarCompra(estabelecimento: 'Erro', data: '2026-07-31'), 'data da compra');
      final c = await compras.iniciarCompra(estabelecimento: 'Mês anterior', data: '2026-08-01');
      expect(c.data, '2026-08-01');
    });

    test('o previsto nunca conta como gasto real (§44)', () async {
      final mes = await comecar(2026, 9, 18);
      final arroz = await lista.adicionarProduto(mes.id, 'cat-arroz', 25);
      await lista.definirPrecoPrevisto(arroz.id, 92800);
      final p = await relatorio.painelMes(mes.id);
      expect(p.orcamento.gasto, 0);
      expect(p.orcamento.saldo, 250000);
      expect(p.lista.pendentePrevisto, 92800);
    });

    test('contas do artigo enquanto se escreve o preço', () {
      final r = compras.simularArtigo(quantidade: 5, unidade: 'L', precoUnitarioPrevisto: 1900, precoReal: 10000);
      expect(r.previsto, 9500);
      expect(r.diferenca, 500);
      expect(r.precoUnitarioBase, 2000);
      final gramas = compras.simularArtigo(quantidade: 500, unidade: 'g', precoReal: 650);
      expect(gramas.unidadeBase, 'kg');
      expect(gramas.precoUnitarioBase, 1300);
      final vazio = compras.simularArtigo(quantidade: 5, unidade: 'L');
      expect(vazio.previsto, isNull);
      expect(vazio.precoUnitarioBase, isNull);
    });
  });

  group('painel, fecho, relatório e novo mês', () {
    test('painel do mês com os números da tela de referência', () {
      final mes = Mes(id: '2026-09', ano: 2026, mes: 9, plafond: 250000, estado: 'aberto');
      final lojas = [
        Compra(id: 'c1', mesId: mes.id, estabelecimento: 'Grossista Kikolo', data: '2026-09-02', estado: 'concluida', criadoEm: '1'),
        Compra(id: 'c2', mesId: mes.id, estabelecimento: 'Cantina do bairro', data: '2026-09-09', estado: 'concluida', criadoEm: '2'),
        Compra(id: 'c3', mesId: mes.id, estabelecimento: 'Mercado do 30', data: '2026-09-16', estado: 'concluida', criadoEm: '3'),
      ];
      ItemCompra pago(String compraId, int valor) => ItemCompra(
          id: compraId, compraId: compraId, mesId: mes.id, produtoId: 'p', quantidade: 1, unidade: 'unidade', precoReal: valor);
      ItemLista previsto(double qtd, double preco) =>
          ItemLista(id: '$qtd$preco', mesId: mes.id, produtoId: 'p', unidade: 'kg', quantidadePrevista: qtd, precoUnitarioPrevisto: preco, ordem: 0);
      final p = relatorio.calcularPainel(
        mes: mes,
        itensLista: [previsto(25, 1280), previsto(5, 1900), previsto(10, 1100), previsto(5, 1500), previsto(10, 800),
          previsto(3, 6800 / 3), previsto(2.5, 7200)],
        compras: lojas,
        itensCompra: [pago('c1', 128900), pago('c2', 21300), pago('c3', 32200)],
        hoje: DateTime(2026, 9, 18, 10),
      );
      expect(p.rotulo, 'Setembro 2026');
      expect(p.estado, 'em_andamento');
      expect(p.orcamento.gasto, 182400);
      expect(p.orcamento.saldo, 67600);
      expect(formatarPercentagem(p.orcamento.percentagem, casas: 0), '73%');
      expect(p.lista.pendentePrevisto, 92800);
      expect(p.cobertura, -25200);
      expect(p.alertas.first.texto, 'Já usaste 73% do plafond e faltam 12 dias para o fim do mês.');
      expect(p.alertaLista!.tipo, 'lista_acima_saldo');
      expect(p.ritmo.previsaoMensal, 304000);
      expect(p.ritmo.faceAoPlafond, 54000);
      expect(p.compras.map((c) => c.compra.estabelecimento).join(','), 'Mercado do 30,Cantina do bairro,Grossista Kikolo');
    });

    test('Setembro copia a lista de Agosto com os últimos preços pagos (§16)', () async {
      final (agosto, setembro) = await cenarioAgostoSetembro();
      expect(setembro.id, '2026-09');
      expect(setembro.listaCopiadaDe, agosto.id);
      final l = await lista.obterLista(setembro.id);
      expect(l.itens.length, 4);
      expect(l.itens.firstWhere((i) => i.produtoId == 'cat-arroz').precoTotalPrevisto, 30000);
      expect(l.resumo.totalPrevisto, 58000);
      expect((await meses.obterMes(agosto.id))!.estado, 'fechado');
      expect((await lista.obterLista(agosto.id)).itens.length, 4, reason: 'a lista de Agosto fica intacta');
    });

    test('comparação com a última compra durante a compra (§20)', () async {
      final (_, setembro) = await cenarioAgostoSetembro();
      final compra = await compraSetembro(setembro);
      final d = await compras.detalheCompra(compra.id);
      final oleo = d.itens.firstWhere((i) => i.item.produtoId == 'cat-oleo');
      expect(oleo.anterior!.precoUnitarioBase, 1700);
      expect(oleo.contas.precoUnitarioBase, 1900);
      expect(formatarPercentagem(oleo.contas.variacao, sinal: true), '+11,8%');
      expect(d.resumo.diferenca, 2000);
      expect(d.saldoMes, 190000);
    });

    test('relatório de Setembro face a Agosto (§24 a §29)', () async {
      final (_, setembro) = await cenarioAgostoSetembro();
      await compras.concluirCompra((await compraSetembro(setembro)).id);
      final r = await relatorio.relatorioMes(setembro.id);
      expect(r.gasto, 60000);
      expect(r.sobrou, 190000);
      expect(r.previsto, 58000);
      expect(r.diferencaPrevisto, 2000);
      expect(r.mesAnteriorNome, 'Agosto');
      expect(r.precos.map((p) => p.nome).join(','), 'Óleo alimentar,Arroz,Feijão,Açúcar');
      expect(r.precos.map((p) => formatarPercentagem(p.variacao, sinal: true)).join(' '), ui('+11,8% +6,7% 0% -8,3%'));
      expect(r.maiorAumento!.nome, 'Óleo alimentar');
      expect(r.maiorReducao!.nome, 'Açúcar');
      expect(r.maiorDespesaNome, 'Arroz');
      expect(r.maiorDespesaTotal, 32000);
      expect(r.ondeGastou.single.proporcao, 100);
      expect(r.cabaz!.actual, 60000);
      expect(r.cabaz!.anterior, 58000);
      expect(formatarPercentagem(r.cabaz!.variacao), '3,4%');
      expect(r.congelado, isFalse);
    });

    test('fechar o mês congela o resumo e bloqueia alterações (§30, §44)', () async {
      final (_, setembro) = await cenarioAgostoSetembro();
      final compra = await compraSetembro(setembro);
      relogio(2026, 9, 30);
      await deveFalhar(() => meses.fecharMes(setembro.id), 'compra por concluir');
      await compras.concluirCompra(compra.id);
      await meses.fecharMes(setembro.id);
      final r = await relatorio.relatorioMes(setembro.id);
      expect(r.congelado, isTrue);
      expect(r.sobrou, 190000);
      final arroz = await itemDe(setembro.id, 'cat-arroz');
      await deveFalhar(() => lista.definirPrecoPrevisto(arroz.id, 1), 'fechado');
      await deveFalhar(() => meses.alterarPlafond(setembro.id, 300000), 'fechado');
      await deveFalhar(() => compras.iniciarCompra(estabelecimento: 'X'), 'Não há nenhum mês aberto');
    });

    test('novo mês sugere plafond pelo cabaz, como na tela Novo mês', () async {
      final (_, setembro) = await cenarioAgostoSetembro();
      await compras.concluirCompra((await compraSetembro(setembro)).id);
      relogio(2026, 9, 30);
      await meses.fecharMes(setembro.id);
      final n = await meses.prepararNovoMes();
      expect(n.rotulo, 'Outubro 2026');
      expect(n.anterior!.nome, 'Setembro');
      expect(n.anterior!.sobrou, 190000);
      expect(formatarPercentagem(n.anterior!.variacaoCabaz), '3,4%');
      expect(n.plafondSugerido, 258500);
      expect(n.itens.firstWhere((i) => i.item.produtoId == 'cat-oleo').precoTotalPrevisto, 9500);
      final arroz = n.itens.firstWhere((i) => i.item.produtoId == 'cat-arroz');
      final outubro = await meses.criarMes(plafond: 258500, copiarDe: setembro.id, itensSeleccionados: [arroz.item.id]);
      expect(outubro.id, '2026-10');
      final l = await lista.obterLista(outubro.id);
      expect(l.itens.length, 1);
      expect(l.itens.first.precoTotalPrevisto, 32000);
      await deveFalhar(() => meses.criarMes(plafond: 1000), 'Já existe um mês aberto');
    });

    test('cartão de produto com último preço, médio e variação (§11)', () async {
      final (_, setembro) = await cenarioAgostoSetembro();
      await compras.concluirCompra((await compraSetembro(setembro)).id);
      final d = await produtos.detalheProduto('cat-arroz');
      expect(d.preco!.ultimo.precoTotal, 32000);
      expect(d.preco!.anterior!.precoUnitarioBase, 1200);
      expect(formatarPercentagem(d.preco!.variacao, sinal: true), '+6,7%');
      expect(d.preco!.medio, 1240);
      expect((await produtos.detalheProduto('cat-gas')).preco, isNull);
    });
  });
}
