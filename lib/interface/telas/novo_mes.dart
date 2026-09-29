// Tela Novo mês (prompt mestre, §16 e §30; tela de referência 6).

import 'package:flutter/material.dart';

import '../../nucleo/alertas.dart';
import '../../nucleo/formatos.dart';
import '../../nucleo/unidades.dart';
import '../../servicos/comum.dart';
import '../../servicos/meses.dart';
import '../avisos.dart';
import '../componentes.dart';
import '../encaminhador.dart';
import '../tema.dart';
import '../textos.dart';

/// Frase sobre o mês que fechou: sobra (ou excesso) e variação do cabaz habitual.
String? _notaDoFecho(MesAnteriorResumido anterior) {
  final sobrou = anterior.sobrou;
  if (sobrou == null) return null;
  final inicio = sobrou >= 0
      ? '${anterior.nome} fechou com ${formatarKz(sobrou)} de sobra'
      : '${anterior.nome} fechou ${formatarKz(-sobrou)} acima do plafond';
  final v = anterior.variacaoCabaz;
  if (v == null) return '$inicio.';
  final arredondada = double.parse(v.toStringAsFixed(1));
  if (arredondada > 0) return '$inicio e o cabaz ficou ${formatarPercentagem(v)} mais caro.';
  if (arredondada < 0) return '$inicio e o cabaz ficou ${formatarPercentagem(-v)} mais barato.';
  return '$inicio e o cabaz ficou ao mesmo preço.';
}

class TelaNovoMes extends StatefulWidget {
  const TelaNovoMes({super.key});

  @override
  State<TelaNovoMes> createState() => _TelaNovoMesEstado();
}

class _TelaNovoMesEstado extends State<TelaNovoMes> with CarregarDados<TelaNovoMes, NovoMesPreparado> {
  final _plafond = TextEditingController();
  final _focoPlafond = FocusNode();
  bool _copiar = true;
  bool _mostrarArtigos = false;
  Set<String> _seleccionados = {};
  String? _erroPlafond;
  String? _erroLista;

  @override
  Future<NovoMesPreparado> carregar() async {
    final p = await prepararNovoMes();
    if (p.mesAberto == null) {
      _plafond.text = formatarValorInicial(p.anterior?.plafond);
      _seleccionados = {for (final i in p.itens) i.item.id};
      _copiar = p.itens.isNotEmpty;
    }
    return p;
  }

  @override
  void dispose() {
    _plafond.dispose();
    _focoPlafond.dispose();
    super.dispose();
  }

  Future<void> _criar(NovoMesPreparado p) async {
    final anterior = p.anterior!;
    if (_copiar && _seleccionados.isEmpty) {
      setState(() => _erroLista = 'Escolhe pelo menos um artigo para copiar, ou começa com a lista vazia.');
      return;
    }
    final encaminhador = Encaminhador.de(context);
    final plafond = lerKz(_plafond.text);
    if (pareceEngano(plafond, anterior.plafond) &&
        !await confirmar(
          context,
          titulo: 'Confirmas este plafond?',
          texto: 'Em ${anterior.nome} era ${formatarKz(anterior.plafond)}; indicaste ${formatarKz(plafond)}.',
          confirmar: 'Sim, está certo',
          cancelar: 'Corrigir',
        )) {
      return;
    }
    try {
      await criarMes(
        plafond: plafond,
        copiarDe: _copiar ? anterior.id : null,
        itensSeleccionados: _copiar ? [for (final i in p.itens) if (_seleccionados.contains(i.item.id)) i.item.id] : null,
      );
    } on ErroKussumba catch (erro) {
      if (RegExp('plafond', caseSensitive: false).hasMatch(erro.mensagem)) {
        setState(() => _erroPlafond = erro.mensagem);
        _focoPlafond.requestFocus();
        return;
      }
      rethrow;
    }
    if (mounted) mostrarAviso(context, '${p.nomeMes} começou.');
    encaminhador.separador('lista');
  }

  @override
  Widget build(BuildContext context) {
    final p = dados;
    if (p == null) return esperaOuFalha();
    final encaminhador = Encaminhador.de(context);
    if (p.mesAberto != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => encaminhador.substituir('mes'));
      return const SizedBox.expand();
    }
    final anterior = p.anterior!;
    final nota = _notaDoFecho(anterior);
    final sugestao = p.plafondSugerido != null && p.plafondSugerido != anterior.plafond ? p.plafondSugerido : null;
    final itens = p.itens;
    const estiloLegenda = TextStyle(fontFamily: fonte, fontSize: Letra.destaque, fontWeight: FontWeight.w600, color: Cores.tinta);

    return PaginaCheia(children: [
      Align(
        alignment: Alignment.centerLeft,
        child: BotaoVoltar(rotulo: 'Voltar ao relatório', aoPremir: () => encaminhador.voltar('relatorio')),
      ),
      const SizedBox(height: 16),
      Cabecalho(sobre: 'Novo mês', titulo: p.rotulo),
      if (nota != null) ...[
        AlertaLinha(nivel: (anterior.sobrou ?? 0) >= 0 ? 'positivo' : 'aviso', texto: nota, comIcone: false),
        const SizedBox(height: 24),
      ],
      CampoKz(
        controlador: _plafond,
        foco: _focoPlafond,
        rotulo: 'Plafond do mês',
        estiloRotulo: estiloLegenda,
        erro: _erroPlafond,
        aoMudar: () {
          if (_erroPlafond != null) setState(() => _erroPlafond = null);
        },
      ),
      if (sugestao != null) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Tocavel(
            aoPremir: () => setState(() {
              _plafond.text = formatarDigitacaoKz('$sugestao');
              _erroPlafond = null;
            }),
            raio: BorderRadius.circular(8),
            escala: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: Text.rich(
                  TextSpan(style: Estilos.nota, children: [
                    TextSpan(text: 'Sugestão com base ${(anterior.variacaoCabaz ?? 0) > 0 ? 'no aumento' : 'na descida'} de preços: '),
                    TextSpan(
                      text: formatarKz(sugestao),
                      style: const TextStyle(
                        color: Cores.verde,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: Cores.verde,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 28),
      Semantics(header: true, child: const Text('Lista de compras', style: estiloLegenda)),
      const SizedBox(height: 12),
      if (itens.isNotEmpty) ...[
        OpcaoRadio(
          titulo: 'Copiar lista de ${anterior.nome}',
          meta: '${artigos(itens.length)}, com os últimos preços pagos',
          escolhida: _copiar,
          aoEscolher: () => setState(() {
            _copiar = true;
            _erroLista = null;
          }),
        ),
        if (_copiar) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Semantics(
              expanded: _mostrarArtigos,
              child: Ligacao('Escolher artigos (${_seleccionados.length} de ${itens.length})',
                  aoPremir: () => setState(() => _mostrarArtigos = !_mostrarArtigos)),
            ),
          ),
          if (_mostrarArtigos)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final i in itens)
                  MergeSemantics(
                    child: Tocavel(
                      botao: false,
                      escala: 1,
                      aoPremir: () => setState(() {
                        _erroLista = null;
                        _seleccionados.contains(i.item.id) ? _seleccionados.remove(i.item.id) : _seleccionados.add(i.item.id);
                      }),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: Medidas.toque),
                        child: Row(children: [
                          Checkbox(
                            value: _seleccionados.contains(i.item.id),
                            onChanged: (v) => setState(() {
                              _erroLista = null;
                              v == true ? _seleccionados.add(i.item.id) : _seleccionados.remove(i.item.id);
                            }),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(i.nome, style: Estilos.forte),
                              Nota('${formatarQuantidade(i.item.quantidadePrevista, i.item.unidade, i.item.unidadeTexto)}'
                                  '${i.precoTotalPrevisto == null ? ' · sem preço' : ' · ${formatarKz(i.precoTotalPrevisto)}'}'),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
        ],
        const SizedBox(height: 12),
      ],
      OpcaoRadio(
        titulo: 'Começar lista vazia',
        escolhida: !_copiar,
        aoEscolher: () => setState(() {
          _copiar = false;
          _erroLista = null;
        }),
      ),
      if (_erroLista != null) ...[const SizedBox(height: 12), ErroCampo(_erroLista!)],
      const SizedBox(height: 28),
      const Spacer(),
      Botao('Criar mês', aoPremir: () => _criar(p)),
    ]);
  }
}
