// Avisos temporários, tratamento de erros, diálogos de confirmação e folhas que sobem do fundo.

import 'dart:async';

import 'package:flutter/material.dart';

import '../dados/base_dados.dart';
import '../nucleo/formatos.dart';
import '../servicos/comum.dart';
import 'componentes.dart';
import 'icones.dart';
import 'tema.dart';

/// Aviso curto no fundo do ecrã. Os erros ficam mais tempo e têm outra cor.
void mostrarAviso(BuildContext context, String texto, {bool erro = false}) {
  final mensageiro = ScaffoldMessenger.maybeOf(context);
  if (mensageiro == null) return;
  mensageiro
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto, style: const TextStyle(fontFamily: fonte, fontSize: 15, color: Colors.white, height: 1.4)),
      backgroundColor: erro ? Cores.subida : Cores.tinta,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Medidas.raioPequeno)),
      duration: Duration(milliseconds: erro ? 5000 : 3500),
    ));
}

/// Mostra ao utilizador os erros previstos; os imprevistos ficam registados para quem desenvolve.
void tratarErro(BuildContext context, Object erro, [StackTrace? pilha]) {
  if (erro is ErroKussumba) {
    mostrarAviso(context, erro.mensagem, erro: true);
    return;
  }
  if (erro is ErroArmazenamento) {
    mostrarAviso(context, erro.mensagem, erro: true);
    return;
  }
  debugPrint('Erro imprevisto: $erro\n$pilha');
  mostrarAviso(context, 'Não foi possível concluir a operação. Tenta outra vez.', erro: true);
}

/// Executa uma acção e trata os erros; devolve true se correu bem.
Future<bool> executar(BuildContext context, FutureOr<void> Function() accao) async {
  try {
    await accao();
    return true;
  } catch (erro, pilha) {
    if (context.mounted) tratarErro(context, erro, pilha);
    return false;
  }
}

class _Dialogo extends StatelessWidget {
  const _Dialogo({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Cores.superficie,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: Medidas.margem, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Medidas.raio)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      );
}

/// Pede confirmação antes de uma acção. Devolve true só se o utilizador confirmar.
/// Algumas confirmações não se desfazem (fechar o mês, cancelar a compra):
/// o foco começa na opção que não altera nada.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  String? texto,
  String confirmar = 'Confirmar',
  String cancelar = 'Cancelar',
  bool perigo = false,
}) async {
  final resposta = await showDialog<bool>(
    context: context,
    barrierColor: Cores.veu,
    builder: (contexto) => _Dialogo(children: [
      Semantics(header: true, child: Text(titulo, style: Estilos.subtitulo)),
      if (texto != null) ...[
        const SizedBox(height: 8),
        Text(texto, style: Estilos.corpo.copyWith(color: Cores.tinta2)),
      ],
      const SizedBox(height: 20),
      Botao(confirmar, tipo: perigo ? TipoBotao.perigo : TipoBotao.primario, aoPremir: () => Navigator.of(contexto).pop(true)),
      const SizedBox(height: 8),
      Focus(autofocus: true, child: Botao(cancelar, tipo: TipoBotao.texto, aoPremir: () => Navigator.of(contexto).pop(false))),
    ]),
  );
  return resposta ?? false;
}

/// Pede um valor em Kz num diálogo. A função guardar recebe o valor e pode lançar ErroKussumba;
/// nesse caso a mensagem aparece no próprio diálogo. Devolve o valor guardado, ou null se cancelar.
Future<int?> pedirKz(
  BuildContext context, {
  required String titulo,
  required String rotulo,
  int? valor,
  String confirmar = 'Guardar',
  required Future<void> Function(int? valor) guardar,
}) =>
    showDialog<int>(
      context: context,
      barrierColor: Cores.veu,
      builder: (_) => _DialogoKz(titulo: titulo, rotulo: rotulo, valor: valor, textoConfirmar: confirmar, guardar: guardar),
    );

class _DialogoKz extends StatefulWidget {
  const _DialogoKz({required this.titulo, required this.rotulo, this.valor, required this.textoConfirmar, required this.guardar});
  final String titulo;
  final String rotulo;
  final int? valor;
  final String textoConfirmar;
  final Future<void> Function(int? valor) guardar;

  @override
  State<_DialogoKz> createState() => _DialogoKzEstado();
}

class _DialogoKzEstado extends State<_DialogoKz> {
  late final TextEditingController _campo = TextEditingController(text: formatarValorInicial(widget.valor));
  String? _erro;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final valor = lerKz(_campo.text);
    try {
      await widget.guardar(valor);
    } on ErroKussumba catch (erro) {
      setState(() => _erro = erro.mensagem);
      return;
    }
    if (mounted) Navigator.of(context).pop(valor);
  }

  @override
  Widget build(BuildContext context) => _Dialogo(children: [
        Semantics(header: true, child: Text(widget.titulo, style: Estilos.subtitulo)),
        const SizedBox(height: 16),
        CampoKz(
          controlador: _campo,
          rotulo: widget.rotulo,
          erro: _erro,
          autofocus: true,
          aoMudar: () {
            if (_erro != null) setState(() => _erro = null);
          },
          aoSubmeter: _guardar,
        ),
        const SizedBox(height: 20),
        Botao(widget.textoConfirmar, aoPremir: _guardar),
        const SizedBox(height: 8),
        Botao('Cancelar', tipo: TipoBotao.texto, aoPremir: () => Navigator.of(context).pop()),
      ]);
}

/// Folha que sobe do fundo do ecrã, para editar sem sair da tela.
/// Fecha ao tocar fora dela, com o botão de voltar do telefone ou com Navigator.pop.
Future<T?> abrirFolha<T>(BuildContext context, {required String rotulo, required WidgetBuilder construtor}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Cores.superficie,
      barrierColor: Cores.veu,
      constraints: const BoxConstraints(maxWidth: Medidas.larguraMaxima),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (contexto) => Semantics(
        scopesRoute: true,
        namesRoute: true,
        label: rotulo,
        explicitChildNodes: true,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(contexto).bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(contexto).height * 0.88),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Medidas.margem, 20, Medidas.margem, 20),
              child: construtor(contexto),
            ),
          ),
        ),
      ),
    );

/// Cabeçalho de uma folha: ícone opcional, título, nota e botão de fechar.
class CabecalhoFolha extends StatelessWidget {
  const CabecalhoFolha({super.key, required this.titulo, this.nota, this.icone});
  final String titulo;
  final String? nota;
  final Widget? icone;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icone != null) ...[icone!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(titulo,
                      style: const TextStyle(fontFamily: fonte, fontSize: 20, fontWeight: FontWeight.w700, color: Cores.tinta, height: 1.3)),
                ),
                if (nota != null) Nota(nota!),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(8, -8),
            child: Tocavel(
              aoPremir: () => Navigator.of(context).maybePop(),
              rotulo: 'Fechar',
              raio: BorderRadius.circular(Medidas.raioPequeno),
              child: const SizedBox(
                width: Medidas.toque,
                height: Medidas.toque,
                child: Center(child: Icone('fechar', cor: Cores.tinta2)),
              ),
            ),
          ),
        ],
      );
}

/// Coluna com intervalos iguais entre os elementos (o "gap" da versão web).
class Coluna extends StatelessWidget {
  const Coluna({super.key, required this.children, this.intervalo = 18});
  final List<Widget> children;
  final double intervalo;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: intervalo),
            children[i],
          ],
        ],
      );
}

/// Texto inicial de um campo em Kz: vazio quando não há valor.
String formatarValorInicial(int? valor) => valor == null || valor == 0 ? '' : formatarDigitacaoKz('$valor');
