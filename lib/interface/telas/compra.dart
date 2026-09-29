// Detalhe de uma ida às compras (prompt mestre, §8 e §23).

import 'package:flutter/material.dart';

import '../../nucleo/alertas.dart';
import '../../nucleo/datas.dart';
import '../../nucleo/estados.dart';
import '../../nucleo/formatos.dart';
import '../../nucleo/unidades.dart';
import '../../servicos/comum.dart';
import '../../servicos/compras.dart';
import '../avisos.dart';
import '../componentes.dart';
import '../encaminhador.dart';
import '../tema.dart';
import '../textos.dart';

class TelaCompra extends StatefulWidget {
  const TelaCompra({super.key, required this.compraId, this.acabadaDeConcluir = false});
  final String compraId;
  final bool acabadaDeConcluir;

  @override
  State<TelaCompra> createState() => _TelaCompraEstado();
}

class _TelaCompraEstado extends State<TelaCompra> with CarregarDados<TelaCompra, DetalheCompra> {
  @override
  Future<DetalheCompra> carregar() => detalheCompra(widget.compraId);

  Future<void> _corrigir(DetalheCompra d, ArtigoRegistado artigo) async {
    final corrigido = await abrirFolha<bool>(
      context,
      rotulo: 'Corrigir ${artigo.nome}',
      construtor: (_) => _FolhaCorreccao(artigo: artigo, plafond: d.mes.plafond),
    );
    if (corrigido != true || !mounted) return;
    mostrarAviso(context, 'Correcção guardada.');
    await recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final d = dados;
    if (d == null) return esperaOuFalha();
    final encaminhador = Encaminhador.de(context);
    final concluida = d.compra.estado == 'concluida';
    final editavel = concluida && d.mes.estado != 'fechado';
    final fim = widget.acabadaDeConcluir && concluida ? alertaFimCompra(d.resumo.diferenca) : null;
    final r = d.resumo;

    return Pagina(children: [
      Align(
        alignment: Alignment.centerLeft,
        child: BotaoVoltar(rotulo: 'Voltar ao mês', aoPremir: () => encaminhador.voltar('mes')),
      ),
      const SizedBox(height: 16),
      Cabecalho(
        sobre: rotulos['compra']![d.compra.estado],
        titulo: d.compra.estabelecimento,
        abaixo: Nota('${formatarDataLonga(d.compra.data)} · ${artigos(d.itens.length)}'),
      ),
      if (fim != null) AlertaLinha.de(fim),
      if (d.itens.isNotEmpty) ...[
        if (fim != null) const SizedBox(height: 16),
        Semantics(
          label: 'Totais da compra',
          explicitChildNodes: true,
          child: Cartao(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Pares(children: [
                Par.texto('Total previsto', formatarKz(r.previsto)),
                Par.texto('Total real', formatarKz(r.real)),
                if (r.diferenca != null)
                  Par.texto('Diferença', formatarKzComSinal(r.diferenca),
                      cor: r.diferenca! > 0 ? Cores.subida : (r.diferenca! < 0 ? Cores.verde : null)),
              ]),
              if (r.semPrevisaoArtigos > 0) ...[
                const SizedBox(height: 10),
                Nota('Inclui ${formatarKz(r.semPrevisaoTotal)} de ${artigos(r.semPrevisaoArtigos)} sem preço previsto.'),
              ],
            ]),
          ),
        ),
      ],
      Seccao(
        titulo: 'Artigos',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          d.itens.isEmpty
              ? const Nota('Ainda não há artigos registados nesta compra.')
              : ListaLinhas(children: [for (final i in d.itens) _linha(i, editavel ? () => executar(context, () => _corrigir(d, i)) : null)]),
          if (editavel && d.itens.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Nota('Toca num artigo para corrigir um valor mal escrito.'),
          ],
        ]),
      ),
      if (!concluida) ...[
        const SizedBox(height: 24),
        Botao('Continuar a registar', aoPremir: () => encaminhador.separador('comprar')),
      ],
    ]);
  }

  Widget _linha(ArtigoRegistado artigo, VoidCallback? aoPremir) {
    final i = artigo.item;
    final variacao = artigo.contas.variacao;
    final meta = [
      formatarQuantidade(i.quantidade, i.unidade, i.unidadeTexto),
      formatarPrecoUnitario(artigo.contas.precoUnitarioBase, artigo.contas.unidadeBase),
      if (variacao != null) '${formatarPercentagem(variacao, sinal: true)} face à última compra',
      if (i.corrigidoEm != null) 'corrigido',
    ];
    return Linha(
      titulo: artigo.nome,
      meta: meta.join(' · '),
      valor: formatarKz(i.precoReal),
      valorPequeno: i.precoPrevisto == null ? 'sem previsão' : 'previsto ${formatarKz(i.precoPrevisto)}',
      aoPremir: aoPremir,
    );
  }
}

class _FolhaCorreccao extends StatefulWidget {
  const _FolhaCorreccao({required this.artigo, required this.plafond});
  final ArtigoRegistado artigo;
  final int plafond;

  @override
  State<_FolhaCorreccao> createState() => _FolhaCorreccaoEstado();
}

class _FolhaCorreccaoEstado extends State<_FolhaCorreccao> {
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
    final artigo = widget.artigo;
    final pago = lerKz(_preco.text);
    final contas = simularArtigo(
      quantidade: _quantidade,
      unidade: artigo.item.unidade,
      unidadeTexto: artigo.item.unidadeTexto,
      precoUnitarioPrevisto: artigo.item.precoUnitarioPrevisto,
      precoReal: pago,
      anterior: artigo.anterior,
    );
    final motivo = motivoPrecoEstranho(
      precoReal: pago,
      plafond: widget.plafond,
      precoUnitarioBase: contas.precoUnitarioBase,
      anteriorUnitarioBase: artigo.anterior?.precoUnitarioBase,
      previsto: contas.previsto,
    );
    if (motivo != null &&
        !await confirmar(
          context,
          titulo: 'Confirmas este preço?',
          texto: '${formatarKz(pago)} por ${artigo.nome} $motivo. Confirma que não é engano de digitação.',
          confirmar: 'Sim, está certo',
          cancelar: 'Corrigir',
        )) {
      return;
    }
    try {
      await corrigirArtigo(artigo.item.id, quantidade: _quantidade, precoReal: pago);
    } on ErroKussumba catch (erro) {
      if (RegExp('preço', caseSensitive: false).hasMatch(erro.mensagem)) {
        setState(() => _erro = erro.mensagem);
        return;
      }
      rethrow;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.artigo.item;
    return Coluna(children: [
      CabecalhoFolha(
        titulo: widget.artigo.nome,
        nota: 'Corrigir um valor mal escrito. O histórico de preços fica com a correcção.',
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const ExcludeSemantics(child: Text('Quantidade', style: Estilos.forte)),
        const SizedBox(height: 8),
        SeletorQuantidade(quantidade: i.quantidade, unidade: i.unidade, unidadeTexto: i.unidadeTexto, aoMudar: (v) => _quantidade = v),
      ]),
      CampoKz(controlador: _preco, rotulo: 'Preço pago', erro: _erro, aoMudar: () {
        if (_erro != null) setState(() => _erro = null);
      }),
      Botao('Guardar correcção', aoPremir: _guardar),
    ]);
  }
}
