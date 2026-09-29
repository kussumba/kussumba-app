// Tela Catálogo (prompt mestre, §10 a §13; tela de referência 2).

import 'package:flutter/material.dart';

import '../../dados/catalogo_inicial.dart';
import '../../dados/modelos.dart';
import '../../nucleo/formatos.dart';
import '../../nucleo/unidades.dart';
import '../../servicos/comum.dart';
import '../../servicos/lista.dart';
import '../../servicos/produtos.dart';
import '../avisos.dart';
import '../componentes.dart';
import '../encaminhador.dart';
import '../icones.dart';
import '../tema.dart';

// A categoria escolhida mantém-se enquanto a aplicação estiver aberta.
String _categoriaEscolhida = categorias.first.id;

class _DadosCatalogo {
  const _DadosCatalogo(this.produtos, this.lista);
  final List<Produto> produtos;
  final ListaDoMes lista;
}

class TelaCatalogo extends StatefulWidget {
  const TelaCatalogo({super.key, required this.mesId});
  final String mesId;

  @override
  State<TelaCatalogo> createState() => _TelaCatalogoEstado();
}

class _TelaCatalogoEstado extends State<TelaCatalogo> with CarregarDados<TelaCatalogo, _DadosCatalogo> {
  final _pesquisa = TextEditingController();

  @override
  Future<_DadosCatalogo> carregar() async => _DadosCatalogo(await listarProdutos(), await obterLista(widget.mesId));

  @override
  void dispose() {
    _pesquisa.dispose();
    super.dispose();
  }

  void _escolherCategoria(String id) {
    setState(() {
      _categoriaEscolhida = id;
      _pesquisa.clear();
    });
  }

  Future<void> _alternar(Produto produto, ItemDaLista? item) async {
    if (item != null && item.comprado) {
      mostrarAviso(context, 'Este artigo já foi comprado este mês.');
      return;
    }
    if (item != null) {
      await removerDaLista(item.id);
    } else {
      await adicionarProduto(widget.mesId, produto.id);
    }
    await recarregar();
  }

  Future<void> _novoProduto() async {
    final criado = await abrirFolha<Produto>(
      context,
      rotulo: 'Novo produto',
      construtor: (_) => _FolhaNovoProduto(mesId: widget.mesId, categoriaInicial: _categoriaEscolhida, nomeInicial: _pesquisa.text),
    );
    if (criado == null || !mounted) return;
    mostrarAviso(context, '${criado.nome} entrou no catálogo e na lista.');
    _categoriaEscolhida = criado.categoria;
    _pesquisa.clear();
    await recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final d = dados;
    if (d == null) return esperaOuFalha();
    final encaminhador = Encaminhador.de(context);
    final porProduto = {for (final i in d.lista.itens) i.produtoId: i};
    final termo = normalizarNome(_pesquisa.text);
    final visiveis = termo.isNotEmpty
        ? d.produtos.where((p) => p.nomeNormalizado.contains(termo)).toList()
        : d.produtos.where((p) => p.categoria == _categoriaEscolhida).toList();
    final n = d.lista.itens.length;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: Medidas.larguraMaxima),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Medidas.margem),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Row(children: [
                            BotaoVoltar(rotulo: 'Voltar à lista', aoPremir: () => encaminhador.separador('lista')),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Destaque(Text('O que vais comprar?', style: Estilos.titulo.copyWith(fontSize: 26))),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 16),
                          CampoPesquisa(controlador: _pesquisa, aoMudar: (_) => setState(() {})),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      Semantics(
                        label: 'Categorias',
                        explicitChildNodes: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(Medidas.margem, 0, Medidas.margem, 4),
                          child: Row(children: [
                            for (final c in categorias) ...[
                              if (c != categorias.first) const SizedBox(width: 8),
                              Pastilha(
                                c.nome,
                                escolhida: termo.isEmpty && c.id == _categoriaEscolhida,
                                aoPremir: () => _escolherCategoria(c.id),
                              ),
                            ],
                          ]),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Medidas.margem),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (termo.isNotEmpty) ...[const SizedBox(height: 10), const Nota('Resultados de todas as categorias.')],
                          const SizedBox(height: 18),
                          _Grelha(
                            produtos: visiveis,
                            itens: porProduto,
                            semResultados: termo.isNotEmpty && visiveis.isEmpty,
                            aoAlternar: (p, i) => executar(context, () => _alternar(p, i)),
                            aoMudarQuantidade: (item, nova) => executar(context, () async {
                              // O número já mudou no ecrã; só se grava e se actualizam os dados.
                              await alterarQuantidade(item.id, nova);
                              await recarregar();
                            }),
                            aoCriar: _novoProduto,
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _Rodape(
            quantos: n,
            aoVerLista: () => encaminhador.separador('lista'),
          ),
        ],
      ),
    );
  }
}

/// Três colunas com a letra normal; menos quando a letra está grande ou o ecrã é estreito.
class _Grelha extends StatelessWidget {
  const _Grelha({
    required this.produtos,
    required this.itens,
    required this.semResultados,
    required this.aoAlternar,
    required this.aoMudarQuantidade,
    required this.aoCriar,
  });

  final List<Produto> produtos;
  final Map<String, ItemDaLista> itens;
  final bool semResultados;
  final void Function(Produto produto, ItemDaLista? item) aoAlternar;
  final void Function(ItemDaLista item, double nova) aoMudarQuantidade;
  final VoidCallback aoCriar;

  @override
  Widget build(BuildContext context) {
    const intervalo = 12.0;
    final largura = MediaQuery.sizeOf(context).width.clamp(0.0, Medidas.larguraMaxima) - 2 * Medidas.margem;
    final minimo = MediaQuery.textScalerOf(context).scale(104);
    final colunas = ((largura + intervalo) / (minimo + intervalo)).floor().clamp(1, 6);

    final cartoes = <Widget>[
      for (final p in produtos)
        _CartaoProduto(
          key: ValueKey(p.id),
          produto: p,
          item: itens[p.id],
          aoAlternar: () => aoAlternar(p, itens[p.id]),
          aoMudarQuantidade: (nova) => aoMudarQuantidade(itens[p.id]!, nova),
        ),
      _CartaoNovo(aoPremir: aoCriar),
    ];

    final linhas = <Widget>[];
    if (semResultados) {
      linhas.add(const Padding(padding: EdgeInsets.only(bottom: intervalo), child: Nota('Nenhum produto com este nome. Podes criá-lo.')));
    }
    for (var i = 0; i < cartoes.length; i += colunas) {
      final fila = cartoes.sublist(i, (i + colunas).clamp(0, cartoes.length));
      linhas.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : intervalo),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < colunas; c++) ...[
                if (c > 0) const SizedBox(width: intervalo),
                Expanded(child: c < fila.length ? fila[c] : const SizedBox()),
              ],
            ],
          ),
        ),
      ));
    }
    return Semantics(
      label: 'Produtos',
      explicitChildNodes: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: linhas),
    );
  }
}

class _CartaoProduto extends StatelessWidget {
  const _CartaoProduto({super.key, required this.produto, required this.item, required this.aoAlternar, required this.aoMudarQuantidade});
  final Produto produto;
  final ItemDaLista? item;
  final VoidCallback aoAlternar;
  final ValueChanged<double> aoMudarQuantidade;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    final naLista = item != null;
    final estado = item != null && item.comprado
        ? 'Já comprado'
        : naLista
            ? 'Na lista'
            : 'Sugestão: ${formatarQuantidade(produto.quantidadeSugerida, produto.unidade, produto.unidadeTexto)}';
    final raio = BorderRadius.circular(14);
    return Container(
      decoration: BoxDecoration(
        color: Cores.superficie,
        borderRadius: raio,
        border: Border.all(color: naLista ? Cores.verde : Cores.borda, width: naLista ? 2 : 1),
      ),
      child: ClipRRect(
        borderRadius: raio,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Tocavel(
                      aoPremir: aoAlternar,
                      alternado: naLista,
                      escala: 0.97,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: 58,
                              decoration: BoxDecoration(color: Cores.iconeFundo, borderRadius: BorderRadius.circular(10)),
                              alignment: Alignment.center,
                              child: IconeProduto(produto.icone, tamanho: 34),
                            ),
                            const SizedBox(height: 8),
                            Text(produto.nome,
                                style: const TextStyle(fontFamily: fonte, fontSize: 15, fontWeight: FontWeight.w700, height: 1.2, color: Cores.tinta)),
                            const SizedBox(height: 2),
                            Text(estado, style: const TextStyle(fontFamily: fonte, fontSize: 13, height: 1.3, color: Cores.tinta2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (item != null && !item.comprado)
                    SeletorQuantidade(
                      key: ValueKey('qtd-${item.id}'),
                      quantidade: item.item.quantidadePrevista,
                      unidade: item.item.unidade,
                      unidadeTexto: item.item.unidadeTexto,
                      compacto: true,
                      aoMudar: aoMudarQuantidade,
                    ),
                ],
              ),
              if (naLista)
                Positioned(
                  top: 6,
                  right: 6,
                  child: ExcludeSemantics(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(color: Cores.verde, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Icone('check', tamanho: 15, cor: Colors.white, espessura: 2.6),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoNovo extends StatelessWidget {
  const _CartaoNovo({required this.aoPremir});
  final VoidCallback aoPremir;

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(14);
    return CustomPaint(
      foregroundPainter: const BordaTracejada(cor: Cores.tracejado, raio: 14),
      child: Tocavel(
        aoPremir: aoPremir,
        raio: raio,
        escala: 0.97,
        child: Container(
          constraints: const BoxConstraints(minHeight: 132),
          padding: const EdgeInsets.all(8),
          alignment: Alignment.center,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icone('mais', tamanho: 26, cor: Cores.verde),
              SizedBox(height: 6),
              Text('Novo produto',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: fonte, fontSize: 15, fontWeight: FontWeight.w700, color: Cores.verde)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape({required this.quantos, required this.aoVerLista});
  final int quantos;
  final VoidCallback aoVerLista;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(color: Cores.superficie, border: Border(top: BorderSide(color: Cores.borda))),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Medidas.larguraMaxima),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Medidas.margem, vertical: 14),
                // Contagem à esquerda e botão à direita; com letra grande, o botão passa para baixo.
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    MergeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${formatarNumero(quantos)} ${quantos == 1 ? 'artigo' : 'artigos'}',
                              style: const TextStyle(fontFamily: fonte, fontSize: Letra.destaque, fontWeight: FontWeight.w700, color: Cores.tinta)),
                          Text(quantos == 1 ? 'seleccionado' : 'seleccionados', style: Estilos.nota),
                        ],
                      ),
                    ),
                    Botao('Ver lista', larguraTotal: false, aoPremir: aoVerLista),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// Folha para criar um produto que não está no catálogo; entra logo na lista.
class _FolhaNovoProduto extends StatefulWidget {
  const _FolhaNovoProduto({required this.mesId, required this.categoriaInicial, required this.nomeInicial});
  final String mesId;
  final String categoriaInicial;
  final String nomeInicial;

  @override
  State<_FolhaNovoProduto> createState() => _FolhaNovoProdutoEstado();
}

class _FolhaNovoProdutoEstado extends State<_FolhaNovoProduto> {
  late final _nome = TextEditingController(text: widget.nomeInicial);
  final _unidadeTexto = TextEditingController();
  final _quantidade = TextEditingController(text: '1');
  late String _categoria = widget.categoriaInicial;
  String _unidade = unidades.first.id;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _unidadeTexto.dispose();
    _quantidade.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    try {
      final produto = await criarProduto(
        nome: _nome.text,
        categoria: _categoria,
        unidade: _unidade,
        unidadeTexto: _unidadeTexto.text,
        quantidadeSugerida: lerDecimal(_quantidade.text) ?? 0,
      );
      await adicionarProduto(widget.mesId, produto.id);
      if (mounted) Navigator.of(context).pop(produto);
    } on ErroKussumba catch (erro) {
      setState(() => _erro = erro.mensagem);
    }
  }

  Widget _escolha<T>({required String rotulo, required T valor, required List<(T, String)> opcoes, required ValueChanged<T> aoMudar}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ExcludeSemantics(child: Text(rotulo, style: Estilos.forte)),
        const SizedBox(height: 8),
        Semantics(
          label: rotulo,
          child: DropdownButtonFormField<T>(
            initialValue: valor,
            isExpanded: true,
            icon: const Icone('abrir', tamanho: 20, cor: Cores.tinta2),
            decoration: decoracaoCampo(),
            style: Estilos.corpo,
            dropdownColor: Cores.superficie,
            borderRadius: BorderRadius.circular(14),
            items: [for (final (v, texto) in opcoes) DropdownMenuItem(value: v, child: Text(texto, overflow: TextOverflow.ellipsis))],
            onChanged: (v) {
              if (v != null) aoMudar(v);
            },
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final lado = MediaQuery.textScalerOf(context).scale(1) <= 1.3;
    final categoria = _escolha(
      rotulo: 'Categoria',
      valor: _categoria,
      opcoes: [for (final c in categorias) (c.id, c.nome)],
      aoMudar: (v) => setState(() => _categoria = v),
    );
    final unidade = _escolha(
      rotulo: 'Unidade',
      valor: _unidade,
      opcoes: [for (final u in unidades) (u.id, u.id == 'outro' ? 'outra' : u.singular)],
      aoMudar: (v) => setState(() => _unidade = v),
    );
    return Coluna(children: [
      const CabecalhoFolha(titulo: 'Novo produto', nota: 'Fica no teu catálogo e entra já na lista.'),
      CampoTexto(rotulo: 'Nome', controlador: _nome, exemplo: 'Ex.: Farinha de mandioca', maximo: 40, autofocus: true),
      // Com letra grande, os dois campos ficam um por baixo do outro.
      if (lado)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: categoria),
          const SizedBox(width: 12),
          Expanded(child: unidade),
        ])
      else ...[categoria, unidade],
      if (_unidade == 'outro') CampoTexto(rotulo: 'Nome da unidade', controlador: _unidadeTexto, exemplo: 'Ex.: molho', maximo: 20),
      CampoTexto(
        rotulo: 'Quantidade habitual',
        controlador: _quantidade,
        teclado: const TextInputType.numberWithOptions(decimal: true),
      ),
      if (_erro != null) ErroCampo(_erro!),
      Botao('Criar e pôr na lista', aoPremir: _criar),
    ]);
  }
}
