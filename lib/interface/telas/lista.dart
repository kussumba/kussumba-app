// Tela Lista (prompt mestre, §9, §11, §13, §14; tela de referência 3).

import 'package:flutter/material.dart';

import '../../dados/catalogo_inicial.dart';
import '../../nucleo/alertas.dart';
import '../../nucleo/calculos.dart' show precoTotal, precoUnitario;
import '../../nucleo/datas.dart';
import '../../nucleo/estados.dart';
import '../../nucleo/formatos.dart';
import '../../nucleo/unidades.dart';
import '../../servicos/comum.dart';
import '../../servicos/lista.dart';
import '../../servicos/precos.dart';
import '../../servicos/produtos.dart';
import '../../servicos/relatorio.dart';
import '../avisos.dart';
import '../componentes.dart';
import '../encaminhador.dart';
import '../icones.dart';
import '../tema.dart';
import '../textos.dart';

class _DadosLista {
  const _DadosLista(this.lista, this.painel);
  final ListaDoMes lista;
  final Painel painel;
}

class TelaLista extends StatefulWidget {
  const TelaLista({super.key, required this.mesId});
  final String mesId;

  @override
  State<TelaLista> createState() => _TelaListaEstado();
}

class _TelaListaEstado extends State<TelaLista> with CarregarDados<TelaLista, _DadosLista> {
  @override
  Future<_DadosLista> carregar() async {
    final resultados = await Future.wait([obterLista(widget.mesId), painelMes(widget.mesId)]);
    return _DadosLista(resultados[0] as ListaDoMes, resultados[1] as Painel);
  }

  Future<void> _sugeridos() async {
    final n = await adicionarSugeridos(widget.mesId);
    if (!mounted) return;
    mostrarAviso(context, n == 1 ? '1 produto adicionado à lista.' : '$n produtos adicionados à lista.');
    await recarregar();
  }

  Future<void> _editar(ItemDaLista item) async {
    final detalhe = await detalheProduto(item.produtoId);
    if (!mounted) return;
    final resultado = await abrirFolha<Object>(
      context,
      rotulo: 'Editar ${item.nome}',
      construtor: (_) => _FolhaArtigo(item: item, preco: detalhe.preco),
    );
    if (resultado == null || !mounted) return;
    if (resultado is String) mostrarAviso(context, resultado);
    await recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final d = dados;
    if (d == null) return esperaOuFalha();
    final ListaDoMes(:mes, :itens, :resumo) = d.lista;
    final nome = nomeMes(mes.mes);
    final copiada = mes.listaCopiadaDe;
    final copiadaDe = copiada == null ? null : nomeMes(partesIdMes(copiada).mes);
    final pendentes = itens.where((i) => !i.comprado);
    final comprados = itens.where((i) => i.comprado);

    return Pagina(children: [
      Cabecalho(
        titulo: 'Lista de $nome',
        abaixo: copiadaDe != null || resumo.comprados > 0
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  if (copiadaDe != null) Etiqueta('Copiada de $copiadaDe'),
                  if (resumo.comprados > 0) Etiqueta(rotulos['lista']![resumo.estado]!, tipo: TipoEtiqueta.neutra),
                ]),
              )
            : null,
      ),
      if (itens.isNotEmpty) ...[
        _CartaoResumo(resumo: resumo, painel: d.painel),
        if (d.painel.alertaLista != null) ...[const SizedBox(height: 16), AlertaLinha.de(d.painel.alertaLista!)],
        const SizedBox(height: 16),
        Semantics(
          label: 'Artigos da lista',
          explicitChildNodes: true,
          child: ListaLinhas(children: [
            for (final item in pendentes) _linhaPorComprar(item),
            for (final item in comprados) _linhaComprada(item),
          ]),
        ),
      ] else
        Cartao(
          child: Coluna(intervalo: 16, children: [
            Text('A lista de $nome ainda está vazia.', style: Estilos.corpo),
            Botao('Começar com produtos sugeridos', tipo: TipoBotao.secundario, aoPremir: _sugeridos),
          ]),
        ),
      const SizedBox(height: 20),
      Botao('Adicionar artigos do catálogo',
          tipo: TipoBotao.tracejado, icone: 'mais', aoPremir: () => Encaminhador.de(context).navegar('catalogo')),
    ]);
  }

  Widget _linhaPorComprar(ItemDaLista item) {
    final quantidade = formatarQuantidade(item.item.quantidadePrevista, item.item.unidade, item.item.unidadeTexto);
    final total = item.precoTotalPrevisto;
    return Linha(
      titulo: item.nome,
      meta: quantidade,
      alturaMinima: 66,
      pesoValor: FontWeight.w500,
      valor: total == null ? null : formatarKz(total),
      valorPequeno: total == null ? null : formatarPrecoUnitario(item.precoUnitarioBasePrevisto, item.unidadeBase),
      valorWidget: total == null ? const _SemPreco() : null,
      aoPremir: () => executar(context, () => _editar(item)),
    );
  }

  Widget _linhaComprada(ItemDaLista item) {
    final quantidade = formatarQuantidade(item.item.quantidadePrevista, item.item.unidade, item.item.unidadeTexto);
    final total = item.precoTotalPrevisto;
    return Linha(
      tituloWidget: Row(children: [
        const Icone('check', tamanho: 18, cor: Cores.verde),
        const SizedBox(width: 6),
        Flexible(child: Text(item.nome, style: Estilos.forte.copyWith(color: Cores.tinta2))),
      ]),
      meta: '$quantidade · comprado',
      alturaMinima: 66,
      pesoValor: FontWeight.w500,
      corValor: Cores.tinta2,
      valor: total == null ? null : formatarKz(total),
    );
  }
}

class _SemPreco extends StatelessWidget {
  const _SemPreco();

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: const BordaTracejada(cor: Cores.bordaForte, raio: 20, espessura: 1, traco: 3, intervalo: 3),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text('Sem preço', style: TextStyle(fontFamily: fonte, fontSize: Letra.meta, fontWeight: FontWeight.w500, color: Cores.tinta2)),
        ),
      );
}

/// Totais da lista e comparação com o saldo (§9).
class _CartaoResumo extends StatelessWidget {
  const _CartaoResumo({required this.resumo, required this.painel});
  final ResumoLista resumo;
  final Painel painel;

  @override
  Widget build(BuildContext context) {
    final cobertura = painel.cobertura ?? 0;
    const rotulo = TextStyle(fontFamily: fonte, fontSize: 15, color: Cores.tinta2, height: 1.45);
    const valor = TextStyle(fontFamily: fonte, fontSize: 18, fontWeight: FontWeight.w700, color: Cores.tinta, height: 1.45);
    Widget? resultado;
    if (resumo.pendentes == 0) {
      resultado = const Resultado(icone: 'positivo', cor: Cores.verde, partes: [('Já compraste tudo o que estava na lista.', false)]);
    } else if (resumo.pendentePrevisto > 0) {
      resultado = cobertura < 0
          ? Resultado(icone: 'aviso', cor: Cores.subida, partes: [('Faltam ', false), (formatarKz(-cobertura), true)])
          : Resultado(
              icone: 'positivo', cor: Cores.verde, partes: [('Sobram ', false), (formatarKz(cobertura), true), (' depois da lista', false)]);
    }
    return Semantics(
      label: 'Resumo da lista',
      explicitChildNodes: true,
      child: Cartao(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MergeSemantics(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Total previsto', style: rotulo),
                      Text(formatarKz(resumo.totalPrevisto), style: valor),
                    ]),
                  ),
                ),
                const SizedBox(width: 12),
                MergeSemantics(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('Artigos', style: rotulo),
                    Text(formatarNumero(resumo.artigos), style: valor),
                  ]),
                ),
              ],
            ),
            const Divisor(margem: 12),
            Pares(children: [
              if (resumo.comprados > 0)
                Par.texto('Por comprar · ${artigos(resumo.pendentes)}', formatarKz(resumo.pendentePrevisto)),
              Par.texto('Saldo disponível', formatarKz(painel.orcamento.saldo)),
            ]),
            if (resultado != null) ...[const SizedBox(height: 10), resultado],
            if (resumo.semPreco > 0) ...[
              const SizedBox(height: 10),
              Nota('${resumo.semPreco == 1 ? '1 artigo ainda sem preço previsto.' : '${resumo.semPreco} artigos ainda sem preço previsto.'}'
                  ' Toca num artigo para indicar o preço.'),
            ],
          ],
        ),
      ),
    );
  }
}

/// Folha de edição de um artigo: quantidade, preço previsto e histórico do produto (§11, §13).
class _FolhaArtigo extends StatefulWidget {
  const _FolhaArtigo({required this.item, required this.preco});
  final ItemDaLista item;
  final ResumoPreco? preco;

  @override
  State<_FolhaArtigo> createState() => _FolhaArtigoEstado();
}

class _FolhaArtigoEstado extends State<_FolhaArtigo> {
  late double _quantidade = widget.item.item.quantidadePrevista;

  // O preço unitário mantém-se quando a quantidade muda; o total acompanha (§13).
  late double? _precoPorUnidade = widget.item.item.precoUnitarioPrevisto;
  late final TextEditingController _preco = TextEditingController(text: formatarValorInicial(widget.item.precoTotalPrevisto));
  String? _erro;

  ItemDaLista get _item => widget.item;

  @override
  void dispose() {
    _preco.dispose();
    super.dispose();
  }

  String _unitario() {
    final total = lerKz(_preco.text);
    if (total == null || total == 0) return '';
    return formatarPrecoUnitario(precoUnitario(total, paraBase(_quantidade, _item.item.unidade)), _item.unidadeBase);
  }

  void _mudouQuantidade(double nova) {
    setState(() {
      _quantidade = nova;
      if (_precoPorUnidade != null) _preco.text = formatarNumero(precoTotal(_quantidade, _precoPorUnidade));
    });
  }

  void _mudouPreco() {
    final total = lerKz(_preco.text);
    setState(() {
      _erro = null;
      _precoPorUnidade = total == null || total == 0 ? null : precoUnitario(total, _quantidade);
    });
  }

  Future<void> _guardar() async {
    final lido = lerKz(_preco.text);
    final total = lido == null || lido == 0 ? null : lido;
    final porBase = total == null ? null : precoUnitario(total, paraBase(_quantidade, _item.item.unidade));
    final preco = widget.preco;
    if (preco != null &&
        preco.unidadeBase == _item.unidadeBase &&
        pareceEngano(porBase, preco.ultimo.precoUnitarioBase) &&
        !(await confirmar(
          context,
          titulo: 'Confirmas este preço?',
          texto: 'Dá ${formatarPrecoUnitario(porBase, _item.unidadeBase)}; na última compra pagaste '
              '${formatarPrecoUnitario(preco.ultimo.precoUnitarioBase, _item.unidadeBase)}.',
          confirmar: 'Sim, está certo',
          cancelar: 'Corrigir',
        ))) {
      return;
    }
    try {
      await actualizarItem(_item.id, quantidade: _quantidade, precoTotalPrevisto: total);
    } on ErroKussumba catch (erro) {
      if (RegExp('preço', caseSensitive: false).hasMatch(erro.mensagem)) {
        setState(() => _erro = erro.mensagem);
        return;
      }
      rethrow;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  // Fecha a folha com o texto do aviso; a tela mostra-o depois de a folha fechar.
  Future<void> _retirar() async {
    await removerDaLista(_item.id);
    if (mounted) Navigator.of(context).pop('${_item.nome} saiu da lista.');
  }

  @override
  Widget build(BuildContext context) {
    final categoria = categorias.where((c) => c.id == _item.categoria).firstOrNull?.nome ?? '';
    final unitario = _unitario();
    return Coluna(children: [
      CabecalhoFolha(titulo: _item.nome, nota: categoria, icone: QuadradoProduto(_item.icone)),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const ExcludeSemantics(child: Text('Quantidade', style: Estilos.forte)),
        const SizedBox(height: 8),
        SeletorQuantidade(
          quantidade: _quantidade,
          unidade: _item.item.unidade,
          unidadeTexto: _item.item.unidadeTexto,
          aoMudar: _mudouQuantidade,
        ),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CampoKz(controlador: _preco, rotulo: 'Preço previsto para esta quantidade', erro: _erro, aoMudar: _mudouPreco),
        if (unitario.isNotEmpty) ...[const SizedBox(height: 8), Nota(unitario)],
      ]),
      _HistoricoDoProduto(preco: widget.preco),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Botao('Guardar', aoPremir: _guardar),
        const SizedBox(height: 4),
        Botao('Retirar da lista', tipo: TipoBotao.textoPerigo, aoPremir: _retirar),
      ]),
    ]);
  }
}

/// Cartão de produto (§11): último preço, preço médio e variação, quando há histórico.
class _HistoricoDoProduto extends StatelessWidget {
  const _HistoricoDoProduto({required this.preco});
  final ResumoPreco? preco;

  @override
  Widget build(BuildContext context) {
    final p = preco;
    if (p == null) return const Nota('Ainda não compraste este produto. O preço previsto é uma estimativa tua.');
    final ultimo = p.ultimo;
    final variacao = p.variacao;
    const estiloValor = TextStyle(fontFamily: fonte, fontSize: 15, fontWeight: FontWeight.w600, color: Cores.tinta);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Cores.superficie2, borderRadius: BorderRadius.circular(Medidas.raioPequeno)),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 15),
        child: Pares(children: [
          Par('Última compra · ${formatarDataCurta(ultimo.data)}', Text(formatarKz(ultimo.precoTotal), style: estiloValor)),
          Par(
            '${formatarQuantidade(ultimo.quantidade, ultimo.unidade, ultimo.unidadeTexto)} · ${ultimo.estabelecimento ?? ''}',
            Text.rich(
              TextSpan(style: estiloValor, children: [
                TextSpan(text: formatarPrecoUnitario(ultimo.precoUnitarioBase, p.unidadeBase)),
                if (variacao != null)
                  TextSpan(
                    text: ' ${formatarPercentagem(variacao, sinal: true)}',
                    style: TextStyle(color: variacao > 0 ? Cores.subida : (variacao < 0 ? Cores.descida : null)),
                  ),
              ]),
              textAlign: TextAlign.right,
            ),
          ),
          if (p.registos > 1) Par('Preço médio', Text(formatarPrecoUnitario(p.medio, p.unidadeBase), style: estiloValor)),
        ]),
      ),
    );
  }
}
