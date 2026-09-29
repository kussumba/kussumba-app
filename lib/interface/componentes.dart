// Componentes de interface partilhados pelas telas (versão web: js/ui/componentes.js e css/componentes.css).

import 'dart:async';
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../nucleo/alertas.dart';
import '../nucleo/formatos.dart';
import '../nucleo/unidades.dart';
import 'avisos.dart';
import 'icones.dart';
import 'tema.dart';

// ---------- Toque ----------

/// Área tocável com a resposta da versão web: encolhe um pouco ao premir e mostra
/// um contorno verde quando recebe o foco pelo teclado.
class Tocavel extends StatefulWidget {
  const Tocavel({
    super.key,
    required this.child,
    this.aoPremir,
    this.raio = BorderRadius.zero,
    this.rotulo,
    this.escala = 0.98,
    this.alternado,
    this.actual = false,
    this.botao = true,
  });

  final Widget child;
  final VoidCallback? aoPremir;
  final BorderRadius raio;

  /// Substitui o que o leitor de ecrã lê dentro do elemento.
  final String? rotulo;
  final double escala;

  /// Botão de ligar e desligar (aria-pressed na versão web).
  final bool? alternado;

  /// Separador ou opção actual (aria-current).
  final bool actual;
  final bool botao;

  @override
  State<Tocavel> createState() => _TocavelEstado();
}

class _TocavelEstado extends State<Tocavel> {
  bool _premido = false;
  bool _foco = false;

  @override
  Widget build(BuildContext context) {
    final semMovimento = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final activo = widget.aoPremir != null;
    return Semantics(
      button: widget.botao,
      enabled: activo,
      label: widget.rotulo,
      toggled: widget.alternado,
      selected: widget.actual,
      excludeSemantics: widget.rotulo != null,
      child: InkWell(
        onTap: widget.aoPremir,
        borderRadius: widget.raio,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        onHighlightChanged: (v) => setState(() => _premido = v),
        onFocusChange: (v) => setState(() => _foco = v),
        child: AnimatedScale(
          scale: _premido && !semMovimento ? widget.escala : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            foregroundDecoration: _foco
                ? BoxDecoration(border: Border.all(color: Cores.verde, width: 3), borderRadius: widget.raio)
                : null,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ---------- Botões ----------

enum TipoBotao { primario, secundario, tracejado, texto, perigo, textoPerigo }

/// Botão da KUSSUMBA. Enquanto a acção decorre, não aceita toques repetidos;
/// os erros previstos aparecem num aviso.
class Botao extends StatefulWidget {
  const Botao(
    this.texto, {
    super.key,
    this.aoPremir,
    this.tipo = TipoBotao.primario,
    this.icone,
    this.larguraTotal = true,
    this.activo = true,
    this.compacto = false,
    this.rotulo,
  });

  final String texto;
  final FutureOr<void> Function()? aoPremir;
  final TipoBotao tipo;
  final String? icone;
  final bool larguraTotal;
  final bool activo;

  /// Botões de texto pequenos, lado a lado (tela Comprar).
  final bool compacto;
  final String? rotulo;

  @override
  State<Botao> createState() => _BotaoEstado();
}

class _BotaoEstado extends State<Botao> {
  bool _ocupado = false;

  Future<void> _premir() async {
    if (_ocupado || widget.aoPremir == null) return;
    setState(() => _ocupado = true);
    try {
      await widget.aoPremir!();
    } catch (erro, pilha) {
      if (mounted) tratarErro(context, erro, pilha);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipo = widget.tipo;
    final texto = tipo == TipoBotao.texto || tipo == TipoBotao.textoPerigo;
    final (fundo, frente, borda) = switch (tipo) {
      TipoBotao.primario => (Cores.verde, Colors.white, Colors.transparent),
      TipoBotao.secundario => (Cores.superficie, Cores.verde, Cores.verde),
      TipoBotao.tracejado => (Colors.transparent, Cores.verde, Colors.transparent),
      TipoBotao.texto => (Colors.transparent, Cores.verde, Colors.transparent),
      TipoBotao.perigo => (Cores.subida, Colors.white, Colors.transparent),
      TipoBotao.textoPerigo => (Colors.transparent, Cores.subida, Colors.transparent),
    };
    final disponivel = widget.activo && widget.aoPremir != null;
    final peso = texto || tipo == TipoBotao.tracejado ? FontWeight.w600 : FontWeight.w700;
    final tamanhoLetra = widget.compacto ? 15.0 : Letra.destaque;
    final raio = BorderRadius.circular(Medidas.raio);

    Widget conteudo = Row(
      mainAxisSize: widget.larguraTotal ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: widget.larguraTotal ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        if (widget.icone != null) ...[
          Icone(widget.icone!, tamanho: widget.compacto ? 18 : 22, cor: frente),
          SizedBox(width: widget.compacto ? 6 : 10),
        ],
        Flexible(
          child: Text(
            widget.texto,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: fonte, fontSize: tamanhoLetra, fontWeight: peso, color: frente, height: 1.25),
          ),
        ),
      ],
    );

    conteudo = Container(
      constraints: BoxConstraints(minHeight: texto ? Medidas.toque : 56),
      padding: widget.compacto
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 10)
          : EdgeInsets.symmetric(horizontal: texto ? 0 : 20, vertical: 14),
      alignment: widget.larguraTotal ? Alignment.center : null,
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: raio,
        border: tipo == TipoBotao.secundario ? Border.all(color: borda, width: 1.5) : null,
      ),
      child: conteudo,
    );
    if (tipo == TipoBotao.tracejado) {
      conteudo = CustomPaint(foregroundPainter: const BordaTracejada(cor: Cores.tracejado, raio: Medidas.raio), child: conteudo);
    }
    return Opacity(
      opacity: disponivel ? 1 : 0.45,
      child: Tocavel(
        aoPremir: disponivel && !_ocupado ? _premir : null,
        raio: raio,
        rotulo: widget.rotulo,
        child: conteudo,
      ),
    );
  }
}

/// Contorno tracejado de um rectângulo arredondado (botão "Adicionar artigos do catálogo").
class BordaTracejada extends CustomPainter {
  const BordaTracejada({required this.cor, required this.raio, this.espessura = 1.5, this.traco = 5, this.intervalo = 4});

  final Color cor;
  final double raio;
  final double espessura;
  final double traco;
  final double intervalo;

  @override
  void paint(Canvas canvas, Size size) {
    final meio = espessura / 2;
    final contorno = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(meio, meio, size.width - espessura, size.height - espessura), Radius.circular(raio)));
    final pincel = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura;
    for (final PathMetric medida in contorno.computeMetrics()) {
      var distancia = 0.0;
      while (distancia < medida.length) {
        canvas.drawPath(medida.extractPath(distancia, distancia + traco), pincel);
        distancia += traco + intervalo;
      }
    }
  }

  @override
  bool shouldRepaint(BordaTracejada antigo) => antigo.cor != cor || antigo.raio != raio;
}

class BotaoVoltar extends StatelessWidget {
  const BotaoVoltar({super.key, required this.rotulo, required this.aoPremir});
  final String rotulo;
  final VoidCallback aoPremir;

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(Medidas.raioPequeno);
    return Tocavel(
      aoPremir: aoPremir,
      raio: raio,
      rotulo: rotulo,
      child: Container(
        width: Medidas.toque,
        height: Medidas.toque,
        decoration: BoxDecoration(color: Cores.superficie, borderRadius: raio, border: Border.all(color: Cores.borda)),
        alignment: Alignment.center,
        child: const Icone('voltar', cor: Cores.tinta),
      ),
    );
  }
}

/// Ligação em texto verde (por exemplo "Cópia de segurança").
class Ligacao extends StatelessWidget {
  const Ligacao(this.texto, {super.key, required this.aoPremir, this.alinhamento = TextAlign.start});
  final String texto;
  final VoidCallback aoPremir;
  final TextAlign alinhamento;

  @override
  Widget build(BuildContext context) => Tocavel(
        aoPremir: aoPremir,
        raio: BorderRadius.circular(6),
        escala: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Medidas.toque),
          child: Align(
            alignment: alinhamento == TextAlign.center ? Alignment.center : Alignment.centerLeft,
            widthFactor: 1,
            child: Text(texto,
                textAlign: alinhamento,
                style: const TextStyle(fontFamily: fonte, fontSize: Letra.corpo, fontWeight: FontWeight.w700, color: Cores.verde)),
          ),
        ),
      );
}

// ---------- Estrutura ----------

class Cartao extends StatelessWidget {
  const Cartao({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.corBorda = Cores.borda, this.espessuraBorda = 1});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color corBorda;
  final double espessuraBorda;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Cores.superficie,
          borderRadius: BorderRadius.circular(Medidas.raio),
          border: Border.all(color: corBorda, width: espessuraBorda),
        ),
        child: child,
      );
}

/// Secção com título (por exemplo "Idas deste mês").
class Seccao extends StatelessWidget {
  const Seccao({super.key, required this.titulo, required this.child, this.margemTopo = 28});
  final String titulo;
  final Widget child;
  final double margemTopo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: margemTopo),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text(titulo, style: Estilos.subtitulo)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

/// Cabeçalho de tela: texto pequeno por cima e título grande.
class Cabecalho extends StatelessWidget {
  const Cabecalho({super.key, this.sobre, required this.titulo, this.abaixo, this.tamanhoTitulo});
  final String? sobre;
  final String titulo;
  final Widget? abaixo;
  final double? tamanhoTitulo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sobre != null) ...[
              Text(sobre!, style: Estilos.nota),
              const SizedBox(height: 2),
            ],
            Semantics(
              header: true,
              child: Destaque(
                Text(titulo, style: tamanhoTitulo == null ? Estilos.titulo : Estilos.titulo.copyWith(fontSize: tamanhoTitulo)),
              ),
            ),
            ?abaixo,
          ],
        ),
      );
}

class Nota extends StatelessWidget {
  const Nota(this.texto, {super.key, this.alinhamento, this.cor});
  final String texto;
  final TextAlign? alinhamento;
  final Color? cor;

  @override
  Widget build(BuildContext context) =>
      Text(texto, textAlign: alinhamento, style: cor == null ? Estilos.nota : Estilos.nota.copyWith(color: cor));
}

class Divisor extends StatelessWidget {
  const Divisor({super.key, this.margem = 14});
  final double margem;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: EdgeInsets.symmetric(vertical: margem), child: const SizedBox(height: 1, child: ColoredBox(color: Cores.borda)));
}

// ---------- Alertas, progresso e etiquetas ----------

/// Alerta em linha. O ícone e o texto dizem o estado; a cor só reforça.
class AlertaLinha extends StatelessWidget {
  const AlertaLinha({super.key, required this.nivel, required this.texto, this.comIcone = true});

  AlertaLinha.de(Alerta alerta, {Key? key}) : this(key: key, nivel: alerta.nivel, texto: alerta.texto);

  final String nivel;
  final String texto;
  final bool comIcone;

  @override
  Widget build(BuildContext context) {
    final (fundo, borda, frente, icone) = switch (nivel) {
      'perigo' => (Cores.alertaFundo, Cores.subida, Cores.alertaTinta, 'aviso'),
      'positivo' => (Cores.verdeSuave, Cores.verdeSuave, Cores.verdeTinta, 'positivo'),
      'info' => (Cores.superficie, Cores.borda, Cores.tinta2, 'info'),
      _ => (Cores.alertaFundo, Cores.alertaBorda, Cores.alertaTinta, 'aviso'),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(Medidas.raioPequeno),
        border: Border.all(color: borda),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (comIcone) ...[
            Padding(padding: const EdgeInsets.only(top: 1), child: Icone(icone, tamanho: 20, cor: frente)),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(texto, style: TextStyle(fontFamily: fonte, fontSize: 15, height: 1.4, color: frente))),
        ],
      ),
    );
  }
}

class BarraProgresso extends StatelessWidget {
  const BarraProgresso({super.key, required this.largura, this.excedido = false, required this.rotulo, this.altura = 12});
  final double largura;
  final bool excedido;
  final String rotulo;
  final double altura;

  @override
  Widget build(BuildContext context) => Semantics(
        label: rotulo,
        child: ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: altura,
              child: ColoredBox(
                color: Cores.trilho,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (largura / 100).clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: excedido ? Cores.subida : Cores.verde,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

enum TipoEtiqueta { normal, aviso, neutra }

class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, this.tipo = TipoEtiqueta.normal});
  final String texto;
  final TipoEtiqueta tipo;

  @override
  Widget build(BuildContext context) {
    final (fundo, frente) = switch (tipo) {
      TipoEtiqueta.normal => (Cores.verdeSuave, Cores.verdeTinta),
      TipoEtiqueta.aviso => (Cores.alertaFundo, Cores.alertaTinta),
      TipoEtiqueta.neutra => (Cores.superficie, Cores.tinta2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(999),
        border: tipo == TipoEtiqueta.neutra ? Border.all(color: Cores.borda) : null,
      ),
      child: Text(texto, style: TextStyle(fontFamily: fonte, fontSize: 13, fontWeight: FontWeight.w600, color: frente, height: 1.4)),
    );
  }
}

// ---------- Pares e linhas ----------

/// Par rótulo / valor: o rótulo à esquerda e o valor encostado à direita.
/// Se não couberem lado a lado (letra grande), o valor passa para a linha de baixo.
class Par extends StatelessWidget {
  const Par(this.rotulo, this.valor, {super.key});

  Par.texto(String rotulo, String valor, {Key? key, Color? cor})
      : this(rotulo, Text(valor, textAlign: TextAlign.right, style: Estilos.forte.copyWith(color: cor)), key: key);

  final String rotulo;
  final Widget valor;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: OverflowBar(
          alignment: MainAxisAlignment.spaceBetween,
          spacing: 12,
          overflowSpacing: 2,
          overflowAlignment: OverflowBarAlignment.start,
          children: [
            Text(rotulo, style: Estilos.corpo.copyWith(color: Cores.tinta2)),
            valor,
          ],
        ),
      );
}

class Pares extends StatelessWidget {
  const Pares({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      );
}

/// Linhas dentro de um cartão, separadas por um traço; ou cartões separados (Idas deste mês).
class ListaLinhas extends StatelessWidget {
  const ListaLinhas({super.key, required this.children, this.separadas = false});
  final List<Widget> children;
  final bool separadas;

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(Medidas.raio);
    if (separadas) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: Cores.superficie, borderRadius: raio, border: Border.all(color: Cores.borda)),
              child: ClipRRect(borderRadius: raio, child: Material(type: MaterialType.transparency, child: children[i])),
            ),
          ],
        ],
      );
    }
    return Container(
      decoration: BoxDecoration(color: Cores.superficie, borderRadius: raio, border: Border.all(color: Cores.borda)),
      child: ClipRRect(
        borderRadius: raio,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 1, child: ColoredBox(color: Cores.borda)),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class Linha extends StatelessWidget {
  const Linha({
    super.key,
    this.titulo,
    this.tituloWidget,
    this.meta,
    this.abaixo,
    this.valor,
    this.valorWidget,
    this.valorPequeno,
    this.aoPremir,
    this.alturaMinima = 64,
    this.pesoValor = FontWeight.w600,
    this.corValor,
    this.corTitulo,
    this.depois,
  });

  final String? titulo;
  final Widget? tituloWidget;
  final String? meta;
  final Widget? abaixo;
  final String? valor;
  final Widget? valorWidget;
  final String? valorPequeno;
  final VoidCallback? aoPremir;
  final double alturaMinima;
  final FontWeight pesoValor;
  final Color? corValor;
  final Color? corTitulo;

  /// Elemento no fim da linha, depois do valor (por exemplo a seta de escolher).
  final Widget? depois;

  @override
  Widget build(BuildContext context) {
    final lado = valorWidget ??
        (valor == null && valorPequeno == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (valor != null)
                    Text(valor!,
                        textAlign: TextAlign.right,
                        style: TextStyle(fontFamily: fonte, fontSize: Letra.corpo, fontWeight: pesoValor, color: corValor ?? Cores.tinta, height: 1.45)),
                  if (valorPequeno != null)
                    Text(valorPequeno!, textAlign: TextAlign.right, style: const TextStyle(fontFamily: fonte, fontSize: 13, color: Cores.tinta2, height: 1.45)),
                ],
              ));
    final conteudo = Container(
      constraints: BoxConstraints(minHeight: alturaMinima),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tituloWidget ??
                    Text(titulo ?? '', style: Estilos.forte.copyWith(color: corTitulo)),
                if (meta != null) Text(meta!, style: Estilos.nota),
                ?abaixo,
              ],
            ),
          ),
          if (lado != null) ...[const SizedBox(width: 12), lado],
          if (depois != null) ...[const SizedBox(width: 8), depois!],
        ],
      ),
    );
    if (aoPremir == null) return MergeSemantics(child: conteudo);
    return Tocavel(aoPremir: aoPremir, escala: 0.99, child: conteudo);
  }
}

// ---------- Campos ----------

/// Formata os valores em Kz enquanto o utilizador escreve: "250000" aparece "250 000".
class FormatadorKz extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue antigo, TextEditingValue novo) {
    final texto = formatarDigitacaoKz(novo.text);
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}

const _estiloKz = TextStyle(fontFamily: fonte, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.64, color: Cores.tinta, height: 1.2);

/// Títulos e números grandes já nascem grandes: com a letra grande do telefone crescem só até
/// uma vez e meia, para não partirem palavras nem números a meio. O resto do texto cresce até ao dobro.
const double escalaMaximaDestaque = 1.5;

/// Texto de destaque (títulos, saldo, preço pago) com o limite de crescimento acima.
class Destaque extends StatelessWidget {
  const Destaque(this.child, {super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(maxScaleFactor: escalaMaximaDestaque, child: child);
}

/// Campo de valor em Kz, grande, com o "Kz" colado ao número (telas 1 e 6).
class CampoKz extends StatefulWidget {
  const CampoKz({
    super.key,
    required this.controlador,
    this.rotulo,
    this.estiloRotulo,
    this.ajuda,
    this.erro,
    this.aoMudar,
    this.aoSubmeter,
    this.foco,
    this.autofocus = false,
  });

  final TextEditingController controlador;
  final String? rotulo;
  final TextStyle? estiloRotulo;
  final String? ajuda;
  final String? erro;
  final VoidCallback? aoMudar;
  final VoidCallback? aoSubmeter;
  final FocusNode? foco;
  final bool autofocus;

  @override
  State<CampoKz> createState() => _CampoKzEstado();
}

class _CampoKzEstado extends State<CampoKz> {
  late final FocusNode _foco = widget.foco ?? FocusNode();
  bool _focado = false;

  @override
  void initState() {
    super.initState();
    _foco.addListener(_mudouFoco);
    widget.controlador.addListener(_mudouTexto);
  }

  @override
  void didUpdateWidget(CampoKz antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.controlador != widget.controlador) {
      antigo.controlador.removeListener(_mudouTexto);
      widget.controlador.addListener(_mudouTexto);
    }
  }

  void _mudouFoco() => setState(() => _focado = _foco.hasFocus);
  void _mudouTexto() => setState(() {});

  @override
  void dispose() {
    widget.controlador.removeListener(_mudouTexto);
    _foco.removeListener(_mudouFoco);
    if (widget.foco == null) _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // O número já é grande: acompanha a letra do telefone só até uma vez e meia, para caber no campo.
    final escala = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: escalaMaximaDestaque);
    final texto = widget.controlador.text;
    // Mede o número para o "Kz" ficar colado a ele, como na versão web.
    final medida = TextPainter(
      text: TextSpan(text: texto.isEmpty ? '0' : texto, style: _estiloKz),
      textDirection: TextDirection.ltr,
      textScaler: escala,
      maxLines: 1,
    )..layout();
    final larguraNumero = medida.width + 2;
    medida.dispose();

    final caixa = GestureDetector(
      onTap: () => _foco.requestFocus(),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Cores.superficie,
          borderRadius: BorderRadius.circular(Medidas.raio),
          border: Border.all(color: _focado ? Cores.verde : Cores.borda, width: 1.5),
        ),
        // O número ocupa só a sua largura; se for maior do que o espaço, o Flexible encolhe-o.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: SizedBox(
                width: larguraNumero,
                child: Semantics(
                  label: widget.rotulo ?? 'Valor em Kz',
                  child: TextField(
                    controller: widget.controlador,
                    focusNode: _foco,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FormatadorKz()],
                    style: _estiloKz,
                    cursorColor: Cores.verde,
                    decoration: const InputDecoration.collapsed(
                      hintText: '0',
                      hintStyle: TextStyle(color: Cores.marcador),
                    ),
                    onChanged: (_) => widget.aoMudar?.call(),
                    onSubmitted: (_) => widget.aoSubmeter?.call(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const ExcludeSemantics(child: Text('Kz', style: _estiloKz)),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.rotulo != null) ...[
          ExcludeSemantics(child: Text(widget.rotulo!, style: widget.estiloRotulo ?? Estilos.forte)),
          const SizedBox(height: 8),
        ],
        MediaQuery.withClampedTextScaling(maxScaleFactor: escalaMaximaDestaque, child: caixa),
        if (widget.ajuda != null) ...[const SizedBox(height: 8), Nota(widget.ajuda!)],
        if (widget.erro != null) ...[const SizedBox(height: 8), ErroCampo(widget.erro!)],
      ],
    );
  }
}

class ErroCampo extends StatelessWidget {
  const ErroCampo(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Text(texto, style: const TextStyle(fontFamily: fonte, fontSize: Letra.meta, color: Cores.subida, height: 1.45)),
      );
}

InputDecoration decoracaoCampo({String? exemplo}) => InputDecoration(
      hintText: exemplo,
      hintStyle: const TextStyle(color: Cores.marcador),
      filled: true,
      fillColor: Cores.superficie,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Cores.borda, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Cores.verde, width: 1.5)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );

/// Campo de texto simples com o rótulo por cima.
class CampoTexto extends StatelessWidget {
  const CampoTexto({
    super.key,
    required this.rotulo,
    required this.controlador,
    this.exemplo,
    this.erro,
    this.maximo,
    this.teclado,
    this.aoMudar,
    this.foco,
    this.autofocus = false,
    this.accao,
  });

  final String rotulo;
  final TextEditingController controlador;
  final String? exemplo;
  final String? erro;
  final int? maximo;
  final TextInputType? teclado;
  final ValueChanged<String>? aoMudar;
  final FocusNode? foco;
  final bool autofocus;
  final TextInputAction? accao;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(child: Text(rotulo, style: Estilos.forte)),
          const SizedBox(height: 8),
          Semantics(
            label: rotulo,
            child: TextField(
              controller: controlador,
              focusNode: foco,
              autofocus: autofocus,
              maxLength: maximo,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              keyboardType: teclado,
              textInputAction: accao,
              style: Estilos.corpo,
              decoration: decoracaoCampo(exemplo: exemplo).copyWith(counterText: ''),
              onChanged: aoMudar,
            ),
          ),
          if (erro != null) ...[const SizedBox(height: 8), ErroCampo(erro!)],
        ],
      );
}

class CampoPesquisa extends StatelessWidget {
  const CampoPesquisa({super.key, required this.controlador, required this.aoMudar, this.autofocus = false});
  final TextEditingController controlador;
  final ValueChanged<String> aoMudar;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Procurar produto',
        child: TextField(
          controller: controlador,
          autofocus: autofocus,
          textInputAction: TextInputAction.search,
          style: Estilos.corpo,
          decoration: decoracaoCampo(exemplo: 'Procurar produto'),
          onChanged: aoMudar,
        ),
      );
}

/// Opção em forma de pastilha: categorias do catálogo e lojas recentes.
class Pastilha extends StatelessWidget {
  const Pastilha(this.texto, {super.key, required this.aoPremir, this.escolhida});
  final String texto;
  final VoidCallback aoPremir;

  /// null: a pastilha não é de ligar e desligar (lojas recentes).
  final bool? escolhida;

  @override
  Widget build(BuildContext context) {
    final activa = escolhida ?? false;
    final raio = BorderRadius.circular(999);
    return Tocavel(
      aoPremir: aoPremir,
      raio: raio,
      alternado: escolhida,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: activa ? Cores.tinta : Cores.superficie,
          borderRadius: raio,
          border: Border.all(color: activa ? Cores.tinta : Cores.borda),
        ),
        // Só a largura do texto, mesmo quando as pastilhas estão num bloco que muda de linha.
        child: Center(
          widthFactor: 1,
          child: Text(texto,
              style: TextStyle(fontFamily: fonte, fontSize: 15, fontWeight: FontWeight.w600, color: activa ? Colors.white : Cores.tinta)),
        ),
      ),
    );
  }
}

// ---------- Quantidade: − 25 kg + ----------

/// Seletor de quantidade. Na versão compacta (cartões do catálogo), o número só muda com − e +;
/// a quantidade exacta escreve-se na folha de edição da lista.
class SeletorQuantidade extends StatefulWidget {
  const SeletorQuantidade({
    super.key,
    required this.quantidade,
    required this.unidade,
    this.unidadeTexto,
    this.compacto = false,
    this.aoMudar,
  });

  final double quantidade;
  final String unidade;
  final String? unidadeTexto;
  final bool compacto;
  final ValueChanged<double>? aoMudar;

  @override
  State<SeletorQuantidade> createState() => _SeletorQuantidadeEstado();
}

class _SeletorQuantidadeEstado extends State<SeletorQuantidade> {
  late double _valor = widget.quantidade;
  late final TextEditingController _texto = TextEditingController(text: formatarNumero(_valor, 3));
  final FocusNode _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (!_foco.hasFocus) _confirmarTexto();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _aplicar(double novo, {bool reescrever = true}) {
    final mudou = novo != _valor;
    setState(() => _valor = novo);
    if (reescrever) _texto.text = formatarNumero(novo, 3);
    if (mudou) widget.aoMudar?.call(novo);
  }

  bool _aceita(double? lido) => lido != null && lido > 0 && (aceitaDecimais(widget.unidade) || lido == lido.roundToDouble());

  // Cada número válido que se escreve conta logo; um número inválido volta ao anterior ao sair do campo.
  void _escreveu(String texto) {
    final lido = lerDecimal(texto);
    if (_aceita(lido)) _aplicar(lido!, reescrever: false);
  }

  void _confirmarTexto() {
    final lido = lerDecimal(_texto.text);
    if (_aceita(lido)) {
      _aplicar(lido!);
      return;
    }
    _texto.text = formatarNumero(_valor, 3);
    mostrarAviso(context,
        aceitaDecimais(widget.unidade) ? 'Indica uma quantidade maior do que zero.' : 'Esta unidade só aceita números inteiros.',
        erro: true);
  }

  Widget _botao(int direccao) {
    final compacto = widget.compacto;
    return Tocavel(
      aoPremir: () => _aplicar(passoQuantidade(_valor, widget.unidade, direccao)),
      rotulo: direccao < 0 ? 'Diminuir quantidade' : 'Aumentar quantidade',
      escala: 0.9,
      raio: BorderRadius.circular(10),
      child: SizedBox(
        width: compacto ? 34 : 52,
        height: compacto ? 44 : 52,
        child: Center(
          child: Icone(direccao < 0 ? 'menos' : 'mais', tamanho: compacto ? 16 : 22, cor: compacto ? Cores.tinta : Cores.verde),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unidadeTextual = rotuloUnidade(widget.unidade, _valor, widget.unidadeTexto);
    if (widget.compacto) {
      return Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Cores.borda))),
        child: Row(
          children: [
            _botao(-1),
            Expanded(
              child: Semantics(
                liveRegion: true,
                label: 'Quantidade ${formatarQuantidade(_valor, widget.unidade, widget.unidadeTexto)}',
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatarNumero(_valor, 3),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: fonte, fontSize: 14, fontWeight: FontWeight.w700, height: 1.15)),
                      Text(unidadeTextual,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: fonte, fontSize: 14, fontWeight: FontWeight.w700, height: 1.15)),
                    ],
                  ),
                ),
              ),
            ),
            _botao(1),
          ],
        ),
      );
    }

    final escala = MediaQuery.textScalerOf(context);
    const estilo = TextStyle(fontFamily: fonte, fontSize: 18, fontWeight: FontWeight.w700, color: Cores.tinta);
    final cinco = TextPainter(text: const TextSpan(text: '00000', style: estilo), textDirection: TextDirection.ltr, textScaler: escala)
      ..layout();
    final larguraCampo = cinco.width;
    cinco.dispose();
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        color: Cores.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Cores.borda, width: 1.5),
      ),
      child: Row(
        children: [
          _botao(-1),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: SizedBox(
                    width: larguraCampo,
                    child: CustomPaint(
                      foregroundPainter: _TracoInferior(_foco.hasFocus ? Cores.verde : Cores.bordaForte),
                      child: Semantics(
                        label: 'Quantidade',
                        child: TextField(
                          controller: _texto,
                          focusNode: _foco,
                          textAlign: TextAlign.right,
                          keyboardType: TextInputType.numberWithOptions(decimal: aceitaDecimais(widget.unidade)),
                          textInputAction: TextInputAction.done,
                          style: estilo,
                          decoration: const InputDecoration.collapsed(hintText: '').copyWith(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                          onChanged: _escreveu,
                          onSubmitted: (_) => _foco.unfocus(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(child: ExcludeSemantics(child: Text(unidadeTextual, style: estilo))),
              ],
            ),
          ),
          _botao(1),
        ],
      ),
    );
  }
}

class _TracoInferior extends CustomPainter {
  const _TracoInferior(this.cor);
  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = cor
      ..strokeWidth = 1.5;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height), Offset((x + 4).clamp(0, size.width), size.height), pincel);
      x += 7;
    }
  }

  @override
  bool shouldRepaint(_TracoInferior antigo) => antigo.cor != cor;
}

// ---------- Opções ----------

/// Cartão com botão de opção (tela Novo mês).
class OpcaoRadio extends StatelessWidget {
  const OpcaoRadio({super.key, required this.titulo, this.meta, required this.escolhida, required this.aoEscolher});
  final String titulo;
  final String? meta;
  final bool escolhida;
  final VoidCallback aoEscolher;

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(Medidas.raio);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: escolhida,
      child: Tocavel(
        aoPremir: aoEscolher,
        raio: raio,
        botao: false,
        escala: 0.99,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Cores.superficie,
            borderRadius: raio,
            border: Border.all(color: escolhida ? Cores.verde : Cores.borda, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: escolhida ? Cores.verde : Cores.tinta2, width: 1.5),
                ),
                alignment: Alignment.center,
                child: escolhida
                    ? Container(width: 12, height: 12, decoration: const BoxDecoration(color: Cores.verde, shape: BoxShape.circle))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: Estilos.corpo.copyWith(fontWeight: FontWeight.w700)),
                    if (meta != null) Padding(padding: const EdgeInsets.only(top: 2), child: Nota(meta!)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opção grande, uma por linha, com seta (primeira lista).
class OpcaoGrande extends StatelessWidget {
  const OpcaoGrande({super.key, required this.titulo, required this.meta, required this.aoPremir});
  final String titulo;
  final String meta;
  final FutureOr<void> Function() aoPremir;

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(Medidas.raio);
    return Tocavel(
      aoPremir: () async {
        try {
          await aoPremir();
        } catch (erro, pilha) {
          if (context.mounted) tratarErro(context, erro, pilha);
        }
      },
      raio: raio,
      escala: 0.99,
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(color: Cores.superficie, borderRadius: raio, border: Border.all(color: Cores.borda, width: 1.5)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: Estilos.corpo.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Nota(meta),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const Icone('seguinte', cor: Cores.tinta2),
          ],
        ),
      ),
    );
  }
}

/// Ícone de produto no quadrado bege.
class QuadradoProduto extends StatelessWidget {
  const QuadradoProduto(this.icone, {super.key, this.tamanho = 52, this.tamanhoIcone = 30});
  final String? icone;
  final double tamanho;
  final double tamanhoIcone;

  @override
  Widget build(BuildContext context) => Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(color: Cores.iconeFundo, borderRadius: BorderRadius.circular(Medidas.raioPequeno)),
        alignment: Alignment.center,
        child: IconeProduto(icone, tamanho: tamanhoIcone),
      );
}

/// Texto em várias partes, com algumas a negrito ("Faltam **12 000 Kz** para cumprir a lista.").
class TextoComDestaques extends StatelessWidget {
  const TextoComDestaques(this.partes, {super.key, this.estilo = Estilos.corpo});
  final List<(String, bool)> partes;
  final TextStyle estilo;

  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(
        style: estilo,
        children: [
          for (final (texto, forte) in partes) TextSpan(text: texto, style: forte ? const TextStyle(fontWeight: FontWeight.w700) : null),
        ],
      ));
}

/// Resultado com ícone: "Sobram 1 200 Kz depois da lista" ou "Faltam ...".
class Resultado extends StatelessWidget {
  const Resultado({super.key, required this.icone, required this.cor, required this.partes});
  final String icone;
  final Color cor;
  final List<(String, bool)> partes;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icone(icone, tamanho: 20, cor: cor)),
          const SizedBox(width: 10),
          Expanded(child: TextoComDestaques(partes, estilo: Estilos.corpo.copyWith(color: cor, fontWeight: FontWeight.w500))),
        ],
      );
}
