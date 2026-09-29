// Tela Comprar (prompt mestre, §18 a §23; tela de referência 4).
// Sem compra em andamento, pergunta onde e quando. Com compra em andamento, regista artigo a artigo.

import 'package:flutter/material.dart';

import '../../dados/catalogo_inicial.dart';
import '../../dados/modelos.dart';
import '../../nucleo/alertas.dart';
import '../../nucleo/datas.dart';
import '../../nucleo/formatos.dart';
import '../../nucleo/unidades.dart';
import '../../servicos/comum.dart';
import '../../servicos/compras.dart';
import '../../servicos/lista.dart';
import '../../servicos/produtos.dart';
import '../avisos.dart';
import '../componentes.dart';
import '../encaminhador.dart';
import '../icones.dart';
import '../tema.dart';
import '../textos.dart';

const int _maximoDigitos = 10;
const List<String> _teclas = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '000', '0'];

/// Estado do registo em curso. Mantém-se se o utilizador for ao Mês e voltar.
class _EstadoRegisto {
  String? compraId;
  Set<String> ignorados = {};
  ItemDaLista? extra;
  String? actualId;
  String valor = '';
  double? quantidade;
  bool verTodos = false;

  void reiniciar(String? id) {
    compraId = id;
    ignorados = {};
    verTodos = false;
    limparArtigo();
  }

  void limparArtigo() {
    extra = null;
    actualId = null;
    valor = '';
    quantidade = null;
  }
}

final _estado = _EstadoRegisto();

class TelaComprar extends StatelessWidget {
  const TelaComprar({super.key, required this.contexto});
  final ContextoApp contexto;

  @override
  Widget build(BuildContext context) {
    final compra = contexto.compraEmAndamento;
    if (compra == null) {
      _estado.reiniciar(null);
      return _InicioCompra(mes: contexto.mesAberto!);
    }
    return _RegistoCompra(compraId: compra.id);
  }
}

// ---------- Começar uma ida às compras ----------

class _DadosInicio {
  const _DadosInicio(this.lojas, this.resumo);
  final List<String> lojas;
  final ResumoLista resumo;
}

class _InicioCompra extends StatefulWidget {
  const _InicioCompra({required this.mes});
  final Mes mes;

  @override
  State<_InicioCompra> createState() => _InicioCompraEstado();
}

class _InicioCompraEstado extends State<_InicioCompra> with CarregarDados<_InicioCompra, _DadosInicio> {
  final _loja = TextEditingController();
  final _focoLoja = FocusNode();
  late String _data = dataIso();
  String? _erroLoja;
  String? _erroData;

  @override
  Future<_DadosInicio> carregar() async =>
      _DadosInicio(await estabelecimentosRecentes(), (await obterLista(widget.mes.id)).resumo);

  @override
  void dispose() {
    _loja.dispose();
    _focoLoja.dispose();
    super.dispose();
  }

  DateTime _lerData(String iso) {
    final p = iso.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  Future<void> _escolherData() async {
    final intervalo = intervaloDataCompra(AnoMes(widget.mes.ano, widget.mes.mes));
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _lerData(_data),
      firstDate: _lerData(intervalo.min),
      lastDate: _lerData(intervalo.max),
      helpText: 'Data da compra',
      cancelText: 'Cancelar',
      confirmText: 'Escolher',
    );
    if (escolhida != null) {
      setState(() {
        _data = dataIso(escolhida);
        _erroData = null;
      });
    }
  }

  Future<void> _comecar() async {
    final encaminhador = Encaminhador.de(context);
    try {
      final compra = await iniciarCompra(estabelecimento: _loja.text, data: _data);
      _estado.reiniciar(compra.id);
    } on ErroKussumba catch (erro) {
      if (RegExp('onde', caseSensitive: false).hasMatch(erro.mensagem)) {
        setState(() => _erroLoja = erro.mensagem);
        _focoLoja.requestFocus();
        return;
      }
      if (RegExp('data', caseSensitive: false).hasMatch(erro.mensagem)) {
        setState(() => _erroData = erro.mensagem);
        return;
      }
      rethrow;
    }
    encaminhador.redesenhar();
  }

  @override
  Widget build(BuildContext context) {
    final d = dados;
    if (d == null) return esperaOuFalha();
    final resumo = d.resumo;
    return Pagina(children: [
      const Cabecalho(titulo: 'Nova ida às compras'),
      Coluna(intervalo: 22, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CampoTexto(
            rotulo: 'Onde vais comprar?',
            controlador: _loja,
            foco: _focoLoja,
            exemplo: 'Ex.: Grossista Kikolo',
            maximo: 60,
            erro: _erroLoja,
            accao: TextInputAction.next,
            aoMudar: (_) {
              if (_erroLoja != null) setState(() => _erroLoja = null);
            },
          ),
          if (d.lojas.isNotEmpty) ...[
            const SizedBox(height: 10),
            Semantics(
              label: 'Lojas onde já compraste',
              explicitChildNodes: true,
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final l in d.lojas)
                  Pastilha(l, aoPremir: () {
                    _loja.text = l;
                    setState(() => _erroLoja = null);
                  }),
              ]),
            ),
          ],
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const ExcludeSemantics(child: Text('Data', style: Estilos.forte)),
          const SizedBox(height: 8),
          Tocavel(
            aoPremir: _escolherData,
            rotulo: 'Data: ${formatarDataLonga(_data)}. Mudar a data',
            raio: BorderRadius.circular(14),
            escala: 0.99,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Cores.superficie,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Cores.borda, width: 1.5),
              ),
              child: Row(children: [
                Expanded(child: Text(formatarDataLonga(_data), style: Estilos.corpo)),
                const Icone('mes', tamanho: 20, cor: Cores.tinta2),
              ]),
            ),
          ),
          if (_erroData != null) ...[const SizedBox(height: 8), ErroCampo(_erroData!)],
        ]),
        Cartao(
          child: resumo.pendentes > 0
              ? TextoComDestaques([
                  (artigos(resumo.pendentes), true),
                  (' por comprar na lista', false),
                  if (resumo.pendentePrevisto > 0) ...[(', previsto ', false), (formatarKz(resumo.pendentePrevisto), true)],
                  ('.', false),
                ])
              : const Nota('Não há artigos por comprar na lista. Podes registar artigos fora da lista.'),
        ),
        Botao('Começar a registar', aoPremir: _comecar),
      ]),
    ]);
  }
}

// ---------- Registo artigo a artigo ----------

class _RegistoCompra extends StatefulWidget {
  const _RegistoCompra({required this.compraId});
  final String compraId;

  @override
  State<_RegistoCompra> createState() => _RegistoCompraEstado();
}

class _RegistoCompraEstado extends State<_RegistoCompra> with CarregarDados<_RegistoCompra, DetalheCompra> {
  @override
  Future<DetalheCompra> carregar() => detalheCompra(widget.compraId);

  @override
  void initState() {
    super.initState();
    if (_estado.compraId != widget.compraId) _estado.reiniciar(widget.compraId);
  }

  List<ItemDaLista> _porComprar(DetalheCompra d) => d.pendentes.where((p) => !_estado.ignorados.contains(p.id)).toList();

  /// Artigo que está a ser registado: o de fora da lista escolhido, ou o próximo da lista.
  ItemDaLista? _actual(DetalheCompra d) {
    if (_estado.extra != null) return _estado.extra;
    final porComprar = _porComprar(d);
    final actual = porComprar.where((p) => p.id == _estado.actualId).firstOrNull ?? porComprar.firstOrNull;
    if (actual != null && actual.id != _estado.actualId) {
      _estado
        ..actualId = actual.id
        ..valor = ''
        ..quantidade = null;
    }
    if (actual != null) _estado.quantidade ??= actual.item.quantidadePrevista;
    return actual;
  }

  ContasArtigo _contas(ItemDaLista actual, int? pago) => simularArtigo(
        quantidade: _estado.quantidade ?? actual.item.quantidadePrevista,
        unidade: actual.item.unidade,
        unidadeTexto: actual.item.unidadeTexto,
        precoUnitarioPrevisto: actual.item.precoUnitarioPrevisto,
        precoReal: pago,
        anterior: actual.anterior,
      );

  int? get _pago {
    final v = lerKz(_estado.valor);
    return v == null || v == 0 ? null : v;
  }

  void _premir(String tecla) {
    setState(() {
      if (tecla == 'apagar') {
        if (_estado.valor.isNotEmpty) _estado.valor = _estado.valor.substring(0, _estado.valor.length - 1);
      } else {
        final novo = (_estado.valor + tecla).replaceFirst(RegExp(r'^0+'), '');
        if (novo.length <= _maximoDigitos) _estado.valor = novo;
      }
    });
  }

  /// Pede confirmação quando o preço parece engano de digitação. Devolve true se pode gravar.
  Future<bool> _precoConfirmado(DetalheCompra d, String nome, int pago, ContasArtigo contas, RegistoPreco? anterior) async {
    final motivo = motivoPrecoEstranho(
      precoReal: pago,
      plafond: d.mes.plafond,
      precoUnitarioBase: contas.precoUnitarioBase,
      anteriorUnitarioBase: anterior?.precoUnitarioBase,
      previsto: contas.previsto,
    );
    if (motivo == null) return true;
    return confirmar(
      context,
      titulo: 'Confirmas este preço?',
      texto: '${formatarKz(pago)} por $nome $motivo. Confirma que não é engano de digitação.',
      confirmar: 'Sim, está certo',
      cancelar: 'Corrigir',
    );
  }

  Future<void> _guardar(DetalheCompra d, ItemDaLista actual) async {
    final pago = _pago;
    if (pago == null) return;
    final contas = _contas(actual, pago);
    if (!await _precoConfirmado(d, actual.nome, pago, contas, actual.anterior)) return;
    final extra = _estado.extra != null;
    await registarArtigo(
      compraId: widget.compraId,
      itemListaId: extra ? null : actual.id,
      produtoId: extra ? actual.produtoId : null,
      quantidade: _estado.quantidade,
      precoReal: pago,
    );
    final aviso = alertaPreco(nomeProduto: actual.nome, genero: actual.genero, variacao: contas.variacao);
    if (!mounted) return;
    mostrarAviso(context, aviso?.texto ?? '${actual.nome}: ${formatarKz(pago)} registado.');
    _estado.limparArtigo();
    await recarregar();
  }

  Future<void> _abrirQuantidade(ItemDaLista actual) async {
    final extra = _estado.extra != null;
    final planeada = actual.item.quantidadePrevista;
    final nova = await abrirFolha<double>(
      context,
      rotulo: 'Quantidade comprada',
      construtor: (contexto) => _FolhaQuantidade(
        quantidade: _estado.quantidade ?? planeada,
        unidade: actual.item.unidade,
        unidadeTexto: actual.item.unidadeTexto,
        planeada: extra ? null : planeada,
      ),
    );
    if (nova != null && mounted) setState(() => _estado.quantidade = nova);
  }

  Future<void> _abrirRegistado(DetalheCompra d, ArtigoRegistado artigo) async {
    final resultado = await abrirFolha<Object>(
      context,
      rotulo: 'Corrigir ${artigo.nome}',
      construtor: (_) => _FolhaRegistado(
        artigo: artigo,
        guardar: (quantidade, pago) async {
          final contas = simularArtigo(
            quantidade: quantidade,
            unidade: artigo.item.unidade,
            unidadeTexto: artigo.item.unidadeTexto,
            precoUnitarioPrevisto: artigo.item.precoUnitarioPrevisto,
            precoReal: pago,
            anterior: artigo.anterior,
          );
          if (pago != null && !await _precoConfirmado(d, artigo.nome, pago, contas, artigo.anterior)) return false;
          await registarArtigo(
            compraId: widget.compraId,
            itemListaId: artigo.item.itemListaId,
            produtoId: artigo.item.itemListaId == null ? artigo.item.produtoId : null,
            quantidade: quantidade,
            precoReal: pago,
          );
          return true;
        },
        retirar: () async {
          await anularArtigo(artigo.item.id);
          return artigo.item.itemListaId != null ? '${artigo.nome} voltou a ficar por comprar.' : '${artigo.nome} saiu desta compra.';
        },
      ),
    );
    if (resultado == null || !mounted) return;
    if (resultado is String) mostrarAviso(context, resultado);
    await recarregar();
  }

  Future<void> _abrirForaDaLista(DetalheCompra d) async {
    final produtos = await listarProdutos();
    if (!mounted) return;
    final produtoId = await abrirFolha<String>(
      context,
      rotulo: 'Artigo fora da lista',
      construtor: (_) => _FolhaForaDaLista(produtos: produtos),
    );
    if (produtoId == null || !mounted) return;
    if (d.itens.any((i) => i.item.produtoId == produtoId)) {
      mostrarAviso(context, 'Este produto já está registado nesta compra. Toca nele para corrigir.');
      return;
    }
    final naLista = d.pendentes.where((p) => p.produtoId == produtoId).firstOrNull;
    if (naLista != null) {
      // Está na lista: regista-se como artigo da lista, para a lista ficar certa.
      setState(() {
        _estado.ignorados.remove(naLista.id);
        _estado
          ..extra = null
          ..actualId = naLista.id
          ..valor = ''
          ..quantidade = null;
      });
      return;
    }
    final extra = await produtoParaCompra(widget.compraId, produtoId);
    setState(() {
      _estado
        ..extra = extra
        ..valor = ''
        ..quantidade = null;
    });
  }

  Future<void> _concluir(DetalheCompra d) async {
    final n = d.pendentes.length;
    if (n > 0 &&
        !await confirmar(
          context,
          titulo: 'Concluir esta compra?',
          texto: '${artigos(n)} da lista ${n == 1 ? 'fica' : 'ficam'} por comprar, para outra ida.',
          confirmar: 'Concluir compra',
          cancelar: 'Continuar a registar',
        )) {
      return;
    }
    if (!mounted) return;
    final encaminhador = Encaminhador.de(context);
    await concluirCompra(widget.compraId);
    _estado.reiniciar(null);
    encaminhador.substituir('compra/${widget.compraId}/concluida');
  }

  Future<void> _cancelar(DetalheCompra d) async {
    final n = d.itens.length;
    final ok = await confirmar(
      context,
      titulo: 'Cancelar esta compra?',
      texto: n > 0
          ? '${n == 1 ? 'O artigo registado deixa' : 'Os $n artigos registados deixam'} de contar como gasto e a lista volta ao que estava.'
          : 'Ainda não registaste nenhum artigo.',
      confirmar: 'Cancelar compra',
      cancelar: 'Continuar a registar',
      perigo: true,
    );
    if (!ok || !mounted) return;
    final encaminhador = Encaminhador.de(context);
    await cancelarCompra(widget.compraId);
    _estado.reiniciar(null);
    if (mounted) mostrarAviso(context, 'Compra cancelada.');
    encaminhador.separador('mes');
  }

  @override
  Widget build(BuildContext context) {
    final d = dados;
    if (d == null) return esperaOuFalha();
    final encaminhador = Encaminhador.de(context);
    final porComprar = _porComprar(d);
    final actual = _actual(d);
    final extra = _estado.extra != null;

    final daLista = d.itens.where((i) => i.item.itemListaId != null).length;
    final foraDaLista = d.itens.length - daLista;
    final totalLista = daLista + d.pendentes.length;
    String registados(int n) => n == 1 ? 'registado' : 'registados';
    final progresso = totalLista > 0
        ? '$daLista de ${artigos(totalLista)} ${registados(totalLista)} · faltam ${d.pendentes.length}'
        : '${artigos(d.itens.length)} ${registados(d.itens.length)}';

    return Pagina(children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BotaoVoltar(rotulo: 'Voltar ao mês', aoPremir: () => encaminhador.separador('mes')),
          const SizedBox(width: 12),
          Expanded(
            child: MergeSemantics(
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Sobra no mês', style: Estilos.nota),
                Text(
                  formatarKz(d.saldoMes),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: fonte,
                    fontSize: Letra.destaque,
                    fontWeight: FontWeight.w700,
                    color: d.saldoMes < 0 ? Cores.subida : Cores.verde,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Semantics(header: true, child: Destaque(Text(d.compra.estabelecimento, style: Estilos.titulo.copyWith(fontSize: 26)))),
      const SizedBox(height: 2),
      Text(
        '$progresso${totalLista > 0 && foraDaLista > 0 ? ' · $foraDaLista fora da lista' : ''}',
        style: Estilos.corpo.copyWith(fontSize: 15, color: Cores.tinta2),
      ),
      ..._registados(d),
      if (actual != null) ...[
        const SizedBox(height: 14),
        _CartaoActual(
          actual: actual,
          extra: extra,
          quantidade: _estado.quantidade ?? actual.item.quantidadePrevista,
          pago: _pago,
          contas: _contas(actual, _pago),
          aoMudarQuantidade: () => _abrirQuantidade(actual),
        ),
        const SizedBox(height: 14),
        _Teclado(aoPremir: _premir),
        const SizedBox(height: 14),
        Botao(
          porComprar.length > 1 || extra ? 'Guardar e seguinte' : 'Guardar',
          activo: _pago != null,
          aoPremir: () => _guardar(d, actual),
        ),
      ] else ...[
        const SizedBox(height: 14),
        _BlocoFim(
          detalhe: d,
          porComprar: porComprar,
          aoMostrarIgnorados: () => setState(() => _estado.ignorados.clear()),
        ),
      ],
      const SizedBox(height: 8),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 4,
        children: [
          if (actual != null && !extra)
            Botao('Não comprei aqui',
                tipo: TipoBotao.texto,
                compacto: true,
                larguraTotal: false,
                aoPremir: () => setState(() {
                      _estado.ignorados.add(actual.id);
                      _estado.limparArtigo();
                    })),
          if (extra)
            Botao('Voltar à lista',
                tipo: TipoBotao.texto, compacto: true, larguraTotal: false, aoPremir: () => setState(_estado.limparArtigo)),
          Botao('Artigo fora da lista',
              tipo: TipoBotao.texto, compacto: true, larguraTotal: false, icone: 'mais', aoPremir: () => _abrirForaDaLista(d)),
        ],
      ),
      if (d.resumo.artigos > 0) ...[const SizedBox(height: 12), _Totais(detalhe: d)],
      const SizedBox(height: 20),
      Botao(
        'Concluir compra',
        tipo: actual != null ? TipoBotao.secundario : TipoBotao.primario,
        activo: d.itens.isNotEmpty,
        aoPremir: () => _concluir(d),
      ),
      const SizedBox(height: 4),
      Botao('Cancelar compra', tipo: TipoBotao.textoPerigo, aoPremir: () => _cancelar(d)),
    ]);
  }

  List<Widget> _registados(DetalheCompra d) {
    final itens = d.itens;
    if (itens.isEmpty) return const [];
    final mostrar = _estado.verTodos || itens.length <= 3 ? itens : itens.sublist(itens.length - 2);
    return [
      const SizedBox(height: 14),
      Semantics(
        label: 'Artigos registados',
        explicitChildNodes: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final i in mostrar) ...[
            if (i != mostrar.first) const SizedBox(height: 8),
            _LinhaRegistada(artigo: i, aoPremir: () => executar(context, () => _abrirRegistado(d, i))),
          ],
        ]),
      ),
      if (mostrar.length < itens.length)
        Align(
          alignment: Alignment.centerLeft,
          child: Botao('Ver os ${itens.length} artigos registados',
              tipo: TipoBotao.texto, larguraTotal: false, aoPremir: () => setState(() => _estado.verTodos = true)),
        ),
    ];
  }
}

class _LinhaRegistada extends StatelessWidget {
  const _LinhaRegistada({required this.artigo, required this.aoPremir});
  final ArtigoRegistado artigo;
  final VoidCallback aoPremir;

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(Medidas.raioPequeno);
    final i = artigo.item;
    return Tocavel(
      aoPremir: aoPremir,
      raio: raio,
      escala: 0.99,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: Cores.superficie, borderRadius: raio, border: Border.all(color: Cores.borda)),
        child: Row(children: [
          const Icone('check', tamanho: 18, cor: Cores.verde),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${artigo.nome} · ${formatarQuantidade(i.quantidade, i.unidade, i.unidadeTexto)}',
                style: Estilos.corpo.copyWith(fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Text(formatarKz(i.precoReal), style: Estilos.corpo.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _CartaoActual extends StatelessWidget {
  const _CartaoActual({
    required this.actual,
    required this.extra,
    required this.quantidade,
    required this.pago,
    required this.contas,
    required this.aoMudarQuantidade,
  });

  final ItemDaLista actual;
  final bool extra;
  final double quantidade;
  final int? pago;
  final ContasArtigo contas;
  final VoidCallback aoMudarQuantidade;

  @override
  Widget build(BuildContext context) {
    final partes = [contas.previsto == null ? 'Sem preço previsto' : 'Previsto ${formatarKz(contas.previsto)}'];
    if (contas.precoUnitarioBase != null) partes.add('agora ${formatarPrecoUnitario(contas.precoUnitarioBase, contas.unidadeBase)}');
    final dif = contas.diferenca;
    final anterior = actual.anterior;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Cores.superficie,
        borderRadius: BorderRadius.circular(Medidas.raio),
        border: Border.all(color: Cores.verde, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(actual.nome,
                    style: const TextStyle(fontFamily: fonte, fontSize: Letra.destaque, fontWeight: FontWeight.w700, color: Cores.tinta)),
              ),
            ),
            const SizedBox(width: 12),
            Tocavel(
              aoPremir: aoMudarQuantidade,
              raio: BorderRadius.circular(Medidas.raioPequeno),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Quantidade: ${formatarQuantidade(quantidade, actual.item.unidade, actual.item.unidadeTexto)}',
                  style: const TextStyle(
                    fontFamily: fonte,
                    fontSize: 15,
                    color: Cores.tinta2,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: Cores.tinta2,
                  ),
                ),
              ),
            ),
          ]),
          if (extra) const Padding(padding: EdgeInsets.only(top: 6), child: Align(alignment: Alignment.centerLeft, child: Etiqueta('Fora da lista', tipo: TipoEtiqueta.aviso))),
          const SizedBox(height: 10),
          const Text('Preço pago', style: Estilos.nota),
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            label: 'Preço pago: ${formatarKz(pago ?? 0)}',
            child: ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Cores.superficie2, borderRadius: BorderRadius.circular(Medidas.raioPequeno)),
                child: Destaque(
                  Text(
                    formatarKz(pago ?? 0),
                    style: TextStyle(
                      fontFamily: fonte,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.64,
                      color: pago == null ? Cores.marcador : Cores.tinta,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Nota(partes.join(' · '))),
              if (dif != null) ...[
                const SizedBox(width: 8),
                Text(
                  formatarKzComSinal(dif),
                  style: TextStyle(
                    fontFamily: fonte,
                    fontSize: Letra.meta,
                    fontWeight: FontWeight.w700,
                    color: dif > 0 ? Cores.subida : (dif < 0 ? Cores.verde : Cores.tinta),
                  ),
                ),
              ],
            ],
          ),
          if (anterior != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Nota('Última compra: ${formatarPrecoUnitario(anterior.precoUnitarioBase, contas.unidadeBase)}'
                  '${contas.variacao == null ? '' : ' · agora ${formatarPercentagem(contas.variacao, sinal: true)}'}'),
            ),
        ],
      ),
    );
  }
}

class _Teclado extends StatelessWidget {
  const _Teclado({required this.aoPremir});
  final ValueChanged<String> aoPremir;

  Widget _tecla(String tecla) {
    final raio = BorderRadius.circular(Medidas.raioPequeno);
    return Tocavel(
      aoPremir: () => aoPremir(tecla),
      rotulo: tecla == 'apagar' ? 'Apagar' : tecla,
      raio: raio,
      escala: 0.96,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Cores.superficie, borderRadius: raio, border: Border.all(color: Cores.borda)),
        child: tecla == 'apagar'
            ? const Icone('apagarTecla', tamanho: 26, cor: Cores.tinta, espessura: 1.5)
            : Text(tecla, style: const TextStyle(fontFamily: fonte, fontSize: 22, fontWeight: FontWeight.w400, color: Cores.tinta)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teclas = [..._teclas, 'apagar'];
    return Semantics(
      label: 'Teclado do preço pago',
      explicitChildNodes: true,
      child: Column(children: [
        for (var linha = 0; linha < 4; linha++) ...[
          if (linha > 0) const SizedBox(height: 8),
          Row(children: [
            for (var coluna = 0; coluna < 3; coluna++) ...[
              if (coluna > 0) const SizedBox(width: 8),
              Expanded(child: _tecla(teclas[linha * 3 + coluna])),
            ],
          ]),
        ],
      ]),
    );
  }
}

class _BlocoFim extends StatelessWidget {
  const _BlocoFim({required this.detalhe, required this.porComprar, required this.aoMostrarIgnorados});
  final DetalheCompra detalhe;
  final List<ItemDaLista> porComprar;
  final VoidCallback aoMostrarIgnorados;

  @override
  Widget build(BuildContext context) {
    final d = detalhe;
    final ignorados = d.pendentes.where((p) => _estado.ignorados.contains(p.id)).toList();
    final totalLista = d.itens.where((i) => i.item.itemListaId != null).length + d.pendentes.length;
    final String texto;
    if (totalLista == 0) {
      texto = 'A lista deste mês está vazia. Usa "Artigo fora da lista" para registar o que compraste.';
    } else if (d.pendentes.isEmpty) {
      texto = 'Registaste todos os artigos da lista.';
    } else {
      texto = 'Não compraste aqui: ${ignorados.map((p) => p.nome).join(', ')}. Ficam na lista para outra ida.';
    }
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(texto, style: Estilos.corpo),
        if (ignorados.isNotEmpty) ...[
          const SizedBox(height: 8),
          Botao('Mostrar outra vez os que saltei', tipo: TipoBotao.texto, larguraTotal: false, aoPremir: aoMostrarIgnorados),
        ],
      ]),
    );
  }
}

class _Totais extends StatelessWidget {
  const _Totais({required this.detalhe});
  final DetalheCompra detalhe;

  @override
  Widget build(BuildContext context) {
    final r = detalhe.resumo;
    final dif = r.diferenca;
    return Semantics(
      label: 'Totais desta compra',
      explicitChildNodes: true,
      child: Cartao(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Pares(children: [
            Par.texto('Total previsto', formatarKz(r.previsto)),
            Par.texto('Total real', formatarKz(r.real)),
            if (dif != null)
              Par.texto(
                'Diferença',
                '${formatarKzComSinal(dif)} ${dif > 0 ? 'acima do previsto' : dif < 0 ? 'abaixo do previsto' : 'igual ao previsto'}',
                cor: dif > 0 ? Cores.subida : (dif < 0 ? Cores.verde : null),
              ),
            Par.texto('Saldo do mês', formatarKz(detalhe.saldoMes), cor: detalhe.saldoMes < 0 ? Cores.subida : null),
          ]),
          if (r.semPrevisaoArtigos > 0) ...[
            const SizedBox(height: 10),
            Nota('O total real inclui ${formatarKz(r.semPrevisaoTotal)} de ${artigos(r.semPrevisaoArtigos)} sem preço previsto. '
                'Esse valor não entra na diferença.'),
          ],
        ]),
      ),
    );
  }
}

// ---------- Folhas ----------

class _FolhaQuantidade extends StatefulWidget {
  const _FolhaQuantidade({required this.quantidade, required this.unidade, this.unidadeTexto, this.planeada});
  final double quantidade;
  final String unidade;
  final String? unidadeTexto;
  final double? planeada;

  @override
  State<_FolhaQuantidade> createState() => _FolhaQuantidadeEstado();
}

class _FolhaQuantidadeEstado extends State<_FolhaQuantidade> {
  late double _valor = widget.quantidade;

  Future<void> _feito() async {
    FocusScope.of(context).unfocus();
    final planeada = widget.planeada;
    if (planeada != null && pareceEngano(_valor, planeada)) {
      final ok = await confirmar(
        context,
        titulo: 'Confirmas esta quantidade?',
        texto: 'Planeaste ${formatarQuantidade(planeada, widget.unidade, widget.unidadeTexto)} e indicaste '
            '${formatarQuantidade(_valor, widget.unidade, widget.unidadeTexto)}.',
        confirmar: 'Sim, está certo',
        cancelar: 'Corrigir',
      );
      if (!ok) return;
    }
    if (mounted) Navigator.of(context).pop(_valor);
  }

  @override
  Widget build(BuildContext context) {
    final planeada = widget.planeada;
    return Coluna(children: [
      CabecalhoFolha(
        titulo: 'Quantidade comprada',
        nota: planeada == null ? null : 'Planeado: ${formatarQuantidade(planeada, widget.unidade, widget.unidadeTexto)}',
      ),
      SeletorQuantidade(
        quantidade: _valor,
        unidade: widget.unidade,
        unidadeTexto: widget.unidadeTexto,
        aoMudar: (v) => _valor = v,
      ),
      Botao('Feito', aoPremir: _feito),
    ]);
  }
}

class _FolhaRegistado extends StatefulWidget {
  const _FolhaRegistado({required this.artigo, required this.guardar, required this.retirar});
  final ArtigoRegistado artigo;
  final Future<bool> Function(double quantidade, int? pago) guardar;
  final Future<String> Function() retirar;

  @override
  State<_FolhaRegistado> createState() => _FolhaRegistadoEstado();
}

class _FolhaRegistadoEstado extends State<_FolhaRegistado> {
  late double _quantidade = widget.artigo.item.quantidade;
  late final TextEditingController _preco = TextEditingController(text: formatarValorInicial(widget.artigo.item.precoReal));
  String? _erro;

  @override
  void dispose() {
    _preco.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    try {
      if (!await widget.guardar(_quantidade, lerKz(_preco.text))) return;
    } on ErroKussumba catch (erro) {
      if (RegExp('preço', caseSensitive: false).hasMatch(erro.mensagem)) {
        setState(() => _erro = erro.mensagem);
        return;
      }
      rethrow;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _retirar() async {
    final aviso = await widget.retirar();
    if (mounted) Navigator.of(context).pop(aviso);
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.artigo.item;
    return Coluna(children: [
      CabecalhoFolha(titulo: widget.artigo.nome, nota: 'Corrigir o que registaste'),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const ExcludeSemantics(child: Text('Quantidade', style: Estilos.forte)),
        const SizedBox(height: 8),
        SeletorQuantidade(quantidade: i.quantidade, unidade: i.unidade, unidadeTexto: i.unidadeTexto, aoMudar: (v) => _quantidade = v),
      ]),
      CampoKz(controlador: _preco, rotulo: 'Preço pago', erro: _erro, aoMudar: () {
        if (_erro != null) setState(() => _erro = null);
      }),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Botao('Guardar', aoPremir: _guardar),
        const SizedBox(height: 4),
        Botao('Retirar desta compra', tipo: TipoBotao.textoPerigo, aoPremir: _retirar),
      ]),
    ]);
  }
}

class _FolhaForaDaLista extends StatefulWidget {
  const _FolhaForaDaLista({required this.produtos});
  final List<Produto> produtos;

  @override
  State<_FolhaForaDaLista> createState() => _FolhaForaDaListaEstado();
}

class _FolhaForaDaListaEstado extends State<_FolhaForaDaLista> {
  final _pesquisa = TextEditingController();

  @override
  void dispose() {
    _pesquisa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final termo = normalizarNome(_pesquisa.text);
    final visiveis = widget.produtos.where((p) => termo.isEmpty || p.nomeNormalizado.contains(termo)).toList();
    return Coluna(children: [
      const CabecalhoFolha(titulo: 'Artigo fora da lista', nota: 'Escolhe o produto que compraste.'),
      CampoPesquisa(controlador: _pesquisa, aoMudar: (_) => setState(() {})),
      visiveis.isEmpty
          ? const Padding(padding: EdgeInsets.all(16), child: Nota('Nenhum produto com este nome. Cria-o primeiro no catálogo.'))
          : ListaLinhas(children: [
              for (final p in visiveis)
                Linha(
                  titulo: p.nome,
                  depois: const Icone('seguinte', tamanho: 20, cor: Cores.tinta2),
                  aoPremir: () => Navigator.of(context).pop(p.id),
                ),
            ]),
    ]);
  }
}
