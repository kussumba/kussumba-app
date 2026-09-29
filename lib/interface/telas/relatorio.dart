// Tela Relatório (prompt mestre, §24 a §28 e §30; tela de referência 5).

import 'package:flutter/material.dart';

import '../../dados/modelos.dart';
import '../../nucleo/datas.dart';
import '../../nucleo/estados.dart';
import '../../nucleo/formatos.dart';
import '../../nucleo/unidades.dart';
import '../../servicos/meses.dart';
import '../../servicos/relatorio.dart';
import '../avisos.dart';
import '../componentes.dart';
import '../encaminhador.dart';
import '../icones.dart';
import '../tema.dart';

class _DadosRelatorio {
  const _DadosRelatorio(this.mes, this.relatorio);
  final Mes? mes;
  final Relatorio? relatorio;
}

class TelaRelatorio extends StatefulWidget {
  const TelaRelatorio({super.key});

  @override
  State<TelaRelatorio> createState() => _TelaRelatorioEstado();
}

class _TelaRelatorioEstado extends State<TelaRelatorio> with CarregarDados<TelaRelatorio, _DadosRelatorio> {
  @override
  Future<_DadosRelatorio> carregar() async {
    final mes = await mesParaRelatorio();
    return _DadosRelatorio(mes, mes == null ? null : await relatorioMes(mes.id));
  }

  Future<void> _fechar(Mes mes, Relatorio r) async {
    final faltam = diasRestantes(mes.ano, mes.mes, agora());
    final saldo = r.ultrapassado ? 'ultrapassou o plafond em ${formatarKz(-r.sobrou)}' : 'sobram ${formatarKz(r.sobrou)}';
    final ok = await confirmar(
      context,
      titulo: 'Fechar ${r.nomeMes}?',
      texto: 'Gasto ${formatarKz(r.gasto)} de ${formatarKz(r.plafond)}; $saldo. '
          '${faltam > 0 ? 'Ainda ${faltam == 1 ? 'falta 1 dia' : 'faltam $faltam dias'} para o fim do mês. ' : ''}'
          'Depois de fechado, o mês fica guardado como está e já não pode ser alterado. Nada é apagado.',
      confirmar: 'Fechar mês',
      cancelar: 'Ainda não',
    );
    if (!ok || !mounted) return;
    final encaminhador = Encaminhador.de(context);
    await fecharMes(mes.id);
    encaminhador.navegar('novo-mes');
  }

  @override
  Widget build(BuildContext context) {
    final d = dados;
    if (d == null) return esperaOuFalha();
    final mes = d.mes;
    final r = d.relatorio;
    if (mes == null || r == null) {
      return const Pagina(children: [Cabecalho(titulo: 'Relatório'), Nota('Ainda não há nenhum mês para mostrar.')]);
    }
    final hoje = agora();
    final fechado = mes.estado == 'fechado';
    final terminado = compararMeses(mesDaData(hoje), AnoMes(mes.ano, mes.mes)) > 0;
    final seguinte = nomeMes(proximoMes(AnoMes(mes.ano, mes.mes), hoje).mes);
    final encaminhador = Encaminhador.de(context);

    return Pagina(children: [
      Cabecalho(
        sobre: fechado || terminado ? 'Fecho do mês' : 'Relatório até hoje',
        titulo: r.rotulo,
        abaixo: fechado
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(alignment: Alignment.centerLeft, child: Etiqueta(rotulos['mes']!['fechado']!, tipo: TipoEtiqueta.neutra)),
              )
            : null,
      ),
      _NumerosDoMes(relatorio: r, fechado: fechado),
      _PlaneadoRealizado(relatorio: r),
      _PrecosFaceAoAnterior(relatorio: r),
      if (r.maiorAumento != null || r.maiorReducao != null || r.maiorDespesaNome != null) _MaioresAlteracoes(relatorio: r),
      _OndeGastou(relatorio: r),
      const SizedBox(height: 28),
      if (fechado) ...[
        Nota('${r.nomeMes} está fechado. Os números acima ficaram guardados no fecho.'),
        const SizedBox(height: 12),
        Botao('Começar $seguinte', aoPremir: () => encaminhador.navegar('novo-mes')),
      ] else
        Botao('Fechar mês e começar $seguinte', tipo: TipoBotao.secundario, aoPremir: () => _fechar(mes, r)),
    ]);
  }
}

/// Variação com seta e palavra: a cor reforça, mas não é a única pista.
class Variacao extends StatelessWidget {
  const Variacao(this.valor, {super.key});
  final double? valor;

  @override
  Widget build(BuildContext context) {
    final v = valor ?? 0;
    final arredondada = double.parse(v.toStringAsFixed(1));
    final (seta, texto, cor, leitura) = arredondada > 0
        ? ('subiu', formatarPercentagem(v), Cores.subida, 'subiu ${formatarPercentagem(v)}')
        : arredondada < 0
            ? ('desceu', formatarPercentagem(-v), Cores.descida, 'desceu ${formatarPercentagem(-v)}')
            : (null, '= 0%', Cores.tinta2, 'sem variação, 0%');
    final estilo = TextStyle(fontFamily: fonte, fontSize: Letra.corpo, fontWeight: FontWeight.w700, color: cor);
    return Semantics(
      label: leitura,
      child: ExcludeSemantics(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (seta != null) ...[
            Icone(seta, tamanho: MediaQuery.textScalerOf(context).scale(11), cor: cor),
            const SizedBox(width: 4),
          ],
          Text(texto, softWrap: false, style: estilo),
        ]),
      ),
    );
  }
}

class _NumerosDoMes extends StatelessWidget {
  const _NumerosDoMes({required this.relatorio, required this.fechado});
  final Relatorio relatorio;
  final bool fechado;

  Widget _numero(String rotulo, int valor, double tamanhoLetra, {bool destaque = false, bool excedido = false}) {
    final fundo = excedido ? Cores.subida : (destaque ? Cores.verde : Cores.superficie);
    final frente = destaque ? Colors.white : Cores.tinta;
    return Expanded(
      child: MergeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          decoration: BoxDecoration(
            color: fundo,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: destaque ? fundo : Cores.borda),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Três caixas lado a lado: com letra grande, o texto encolhe em vez de partir a palavra.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(rotulo,
                  style: TextStyle(fontFamily: fonte, fontSize: 13, color: destaque ? Colors.white.withValues(alpha: 0.85) : Cores.tinta2)),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatarNumero(valor),
                  style: TextStyle(fontFamily: fonte, fontSize: tamanhoLetra, fontWeight: FontWeight.w700, color: frente)),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = relatorio;
    final rotuloSobra = r.ultrapassado ? 'Ultrapassou' : (fechado ? 'Sobrou' : 'Sobra');
    // Como na versão web (clamp(15px, 4,4vw, 17px)): os três números com a mesma letra, que acompanha
    // a largura do ecrã. Com letra grande, se ainda não couberem, encolhem dentro da caixa.
    final tamanhoLetra = (MediaQuery.sizeOf(context).width * 0.044).clamp(15.0, Letra.destaque);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        label: 'Resumo em Kz',
        explicitChildNodes: true,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _numero('Plafond', r.plafond, tamanhoLetra),
            const SizedBox(width: 8),
            _numero('Gasto', r.gasto, tamanhoLetra),
            const SizedBox(width: 8),
            _numero(rotuloSobra, r.sobrou.abs(), tamanhoLetra, destaque: true, excedido: r.ultrapassado),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      const Text('Valores em Kz.', style: TextStyle(fontFamily: fonte, fontSize: 13, color: Cores.tinta2)),
    ]);
  }
}

class _PlaneadoRealizado extends StatelessWidget {
  const _PlaneadoRealizado({required this.relatorio});
  final Relatorio relatorio;

  @override
  Widget build(BuildContext context) {
    final r = relatorio;
    final dif = r.diferencaPrevisto;
    return Seccao(
      titulo: 'Planeado e realizado',
      child: Cartao(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Pares(children: [
            Par.texto('Compras previstas', formatarKz(r.previsto)),
            Par.texto('Compras realizadas', formatarKz(r.gasto)),
            if (dif != null) Par.texto('Diferença', formatarKzComSinal(dif), cor: dif > 0 ? Cores.subida : (dif < 0 ? Cores.verde : null)),
          ]),
          if (r.artigosNaLista == 0) ...[
            const SizedBox(height: 10),
            const Nota('Este mês não teve lista, por isso não há previsto para comparar.'),
          ],
          if (r.artigosNaLista > 0 && r.previstoSemPreco > 0) ...[
            const SizedBox(height: 10),
            Nota('${r.previstoSemPreco == 1 ? '1 artigo da lista não tinha' : '${r.previstoSemPreco} artigos da lista não tinham'} '
                'preço previsto e não entram no previsto.'),
          ],
        ]),
      ),
    );
  }
}

class _PrecosFaceAoAnterior extends StatelessWidget {
  const _PrecosFaceAoAnterior({required this.relatorio});
  final Relatorio relatorio;

  @override
  Widget build(BuildContext context) {
    final r = relatorio;
    final anterior = r.mesAnteriorNome;
    final Widget corpo;
    if (anterior == null) {
      corpo = const Nota('Ainda não há um mês anterior com compras para comparar.');
    } else if (r.precos.isEmpty) {
      corpo = const Nota('Nenhum produto foi comprado nos dois meses na mesma unidade.');
    } else {
      corpo = ListaLinhas(children: [
        for (final p in r.precos)
          Linha(
            titulo: p.nome,
            meta: '${formatarPrecoUnitario(p.anterior, p.unidadeBase)} → ${formatarPrecoUnitario(p.actual, p.unidadeBase)}',
            valorWidget: Variacao(p.variacao),
          ),
      ]);
    }
    return Seccao(
      titulo: anterior == null ? 'Preços face ao mês anterior' : 'Preços face a $anterior (por unidade)',
      child: corpo,
    );
  }
}

class _MaioresAlteracoes extends StatelessWidget {
  const _MaioresAlteracoes({required this.relatorio});
  final Relatorio relatorio;

  Widget _comVariacao(String nome, double? variacao) => Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [Text(nome, style: Estilos.forte), Variacao(variacao)],
      );

  @override
  Widget build(BuildContext context) {
    final r = relatorio;
    return Seccao(
      titulo: 'Maiores alterações',
      child: Cartao(
        child: Pares(children: [
          if (r.maiorAumento != null) Par('Maior aumento', _comVariacao(r.maiorAumento!.nome, r.maiorAumento!.variacao)),
          if (r.maiorReducao != null) Par('Maior redução', _comVariacao(r.maiorReducao!.nome, r.maiorReducao!.variacao)),
          if (r.maiorDespesaNome != null) Par.texto('Maior despesa', '${r.maiorDespesaNome} · ${formatarKz(r.maiorDespesaTotal)}'),
        ]),
      ),
    );
  }
}

class _OndeGastou extends StatelessWidget {
  const _OndeGastou({required this.relatorio});
  final Relatorio relatorio;

  @override
  Widget build(BuildContext context) {
    final lojas = relatorio.ondeGastou;
    return Seccao(
      titulo: 'Onde gastou',
      child: lojas.isEmpty
          ? const Nota('Ainda não há compras registadas.')
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final l in lojas) ...[
                if (l != lojas.first) const SizedBox(height: 14),
                MergeSemantics(
                  child: Row(children: [
                    Expanded(child: Text(l.estabelecimento, style: Estilos.corpo.copyWith(fontSize: 15))),
                    const SizedBox(width: 12),
                    Text(formatarKz(l.total), style: Estilos.corpo.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: 6),
                ExcludeSemantics(
                  child: BarraProgresso(largura: l.proporcao, rotulo: l.estabelecimento, altura: 8),
                ),
              ],
            ]),
    );
  }
}
