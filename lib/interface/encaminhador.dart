// Navegação entre telas, com os mesmos caminhos e as mesmas guardas da versão web (js/ui/router.js):
// sem utilizador vai para as boas-vindas; sem mês aberto, as telas que precisam dele levam ao Novo mês.
// O botão de voltar do telefone volta à tela anterior; nos separadores, volta ao Mês e depois sai.

import 'package:flutter/material.dart';

import '../dados/base_dados.dart';
import '../dados/modelos.dart';
import '../servicos/compras.dart' as compras;
import '../servicos/meses.dart' as meses;
import 'avisos.dart';
import 'componentes.dart';
import 'icones.dart';
import 'tema.dart';

/// Caminho de uma tela: `compra/<id>/concluida` tem o nome "compra" e dois parâmetros.
class Rota {
  Rota(this.caminho)
      : nome = caminho.split('/').first,
        parametros = caminho.split('/').skip(1).where((p) => p.isNotEmpty).toList();

  final String caminho;
  final String nome;
  final List<String> parametros;
}

/// O que as telas precisam de saber do estado geral da aplicação.
class ContextoApp {
  const ContextoApp({this.utilizador, this.mesAberto, this.compraEmAndamento});
  final Utilizador? utilizador;
  final Mes? mesAberto;
  final Compra? compraEmAndamento;
}

class DefinicaoTela {
  const DefinicaoTela({required this.construir, this.separador, this.precisaMesAberto = false});

  final Widget Function(Rota rota, ContextoApp contexto) construir;

  /// Separador da barra inferior que fica marcado; null esconde a barra.
  final String? Function(ContextoApp contexto)? separador;
  final bool precisaMesAberto;
}

class Encaminhador extends ChangeNotifier {
  Encaminhador([String inicial = 'mes']) : _historico = [inicial];

  final List<String> _historico;
  int _versao = 0;

  String get actual => _historico.last;
  int get versao => _versao;
  bool get podeVoltar => _historico.length > 1;

  /// Abre uma tela. Se já estiver aberta, volta a desenhá-la.
  void navegar(String caminho) {
    if (caminho == actual) {
      redesenhar();
      return;
    }
    _historico.add(caminho);
    notifyListeners();
  }

  /// Troca a tela actual por outra, sem a guardar no histórico.
  void substituir(String caminho) {
    _historico[_historico.length - 1] = caminho;
    notifyListeners();
  }

  /// Toque num separador da barra inferior: o histórico passa a ser o Mês e esse separador.
  void separador(String id) {
    _historico
      ..clear()
      ..add('mes');
    if (id != 'mes') _historico.add(id);
    _versao++;
    notifyListeners();
  }

  /// Volta à tela anterior. Com destino, vai para essa tela se ela não for a anterior.
  void voltar([String? destino]) {
    if (destino != null && (!podeVoltar || _historico[_historico.length - 2] != destino)) {
      substituir(destino);
      return;
    }
    if (!podeVoltar) return;
    _historico.removeLast();
    notifyListeners();
  }

  /// Volta a desenhar a tela actual, com os dados acabados de ler (depois de gravar alguma coisa).
  void redesenhar() {
    _versao++;
    notifyListeners();
  }

  static Encaminhador de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_EncaminhadorPartilhado>()!.notifier!;
}

class _EncaminhadorPartilhado extends InheritedNotifier<Encaminhador> {
  const _EncaminhadorPartilhado({required Encaminhador encaminhador, required super.child}) : super(notifier: encaminhador);
}

/// Decide para onde ir quando a tela pedida ainda não faz sentido.
String? _guarda(String nome, DefinicaoTela tela, ContextoApp contexto) {
  if (contexto.utilizador == null) return nome == 'boas-vindas' ? null : 'boas-vindas';
  if (nome == 'boas-vindas') return 'mes';
  if (tela.precisaMesAberto && contexto.mesAberto == null) return 'novo-mes';
  return null;
}

class _Desenho {
  const _Desenho(this.chave, this.tela, this.separador);
  final String chave;
  final Widget tela;
  final String? separador;
}

/// Raiz da aplicação: carrega o estado, aplica as guardas e desenha a tela actual com a barra inferior.
class AplicacaoKussumba extends StatefulWidget {
  const AplicacaoKussumba({super.key, required this.telas, this.encaminhador});
  final Map<String, DefinicaoTela> telas;
  final Encaminhador? encaminhador;

  @override
  State<AplicacaoKussumba> createState() => _AplicacaoKussumbaEstado();
}

class _AplicacaoKussumbaEstado extends State<AplicacaoKussumba> {
  late final Encaminhador _encaminhador = widget.encaminhador ?? Encaminhador();
  _Desenho? _desenho;
  Object? _falha;
  int _pedido = 0;

  @override
  void initState() {
    super.initState();
    _encaminhador.addListener(_desenhar);
    _desenhar();
  }

  @override
  void dispose() {
    _encaminhador.removeListener(_desenhar);
    super.dispose();
  }

  Future<void> _desenhar() async {
    final pedido = ++_pedido;
    final rota = Rota(_encaminhador.actual);
    final tela = widget.telas[rota.nome] ?? widget.telas['mes']!;
    final nome = widget.telas.containsKey(rota.nome) ? rota.nome : 'mes';
    try {
      final utilizador = await meses.obterUtilizador();
      final mesAberto = utilizador == null ? null : await meses.obterMesAberto();
      final emAndamento = mesAberto == null ? null : await compras.compraEmAndamento();
      final contexto = ContextoApp(utilizador: utilizador, mesAberto: mesAberto, compraEmAndamento: emAndamento);
      if (pedido != _pedido || !mounted) return;
      final desvio = _guarda(nome, tela, contexto);
      if (desvio != null) {
        _encaminhador.substituir(desvio);
        return;
      }
      setState(() {
        _falha = null;
        _desenho = _Desenho(
          '${rota.caminho}#${_encaminhador.versao}',
          tela.construir(rota, contexto),
          tela.separador?.call(contexto),
        );
      });
    } catch (erro, pilha) {
      if (pedido != _pedido || !mounted) return;
      if (erro is! ErroArmazenamento) debugPrint('Tela não abriu: $erro\n$pilha');
      setState(() => _falha = erro);
    }
  }

  @override
  Widget build(BuildContext context) {
    final desenho = _desenho;
    final semMovimento = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget corpo;
    if (_falha != null) {
      corpo = _TelaFalha(erro: _falha!, tentar: _desenhar);
    } else if (desenho == null) {
      corpo = const SizedBox.expand();
    } else {
      corpo = KeyedSubtree(key: ValueKey(desenho.chave), child: desenho.tela);
    }
    final separador = _falha == null ? desenho?.separador : null;

    return _EncaminhadorPartilhado(
      encaminhador: _encaminhador,
      child: PopScope(
        canPop: !_encaminhador.podeVoltar,
        onPopInvokedWithResult: (saiu, _) {
          if (!saiu) _encaminhador.voltar();
        },
        child: Scaffold(
          backgroundColor: Cores.fundo,
          body: AnimatedSwitcher(
            duration: Duration(milliseconds: semMovimento ? 0 : 150),
            child: corpo,
          ),
          bottomNavigationBar: separador == null
              ? null
              : BarraNavegacao(activo: separador, aoEscolher: _encaminhador.separador),
        ),
      ),
    );
  }
}

class _TelaFalha extends StatelessWidget {
  const _TelaFalha({required this.erro, required this.tentar});
  final Object erro;
  final Future<void> Function() tentar;

  @override
  Widget build(BuildContext context) {
    final semArmazenamento = erro is ErroArmazenamento;
    return Pagina(children: [
      const SizedBox(height: 40),
      Text(semArmazenamento ? 'Não é possível guardar dados' : 'Esta tela não abriu',
          textAlign: TextAlign.center, style: Estilos.titulo),
      const SizedBox(height: 16),
      Nota(
        semArmazenamento ? (erro as ErroArmazenamento).mensagem : 'Os teus dados continuam guardados. Tenta abrir outra vez.',
        alinhamento: TextAlign.center,
      ),
      const SizedBox(height: 16),
      Botao('Tentar outra vez', aoPremir: tentar),
    ]);
  }
}

// ---------- Barra inferior ----------

const _separadores = [('mes', 'Mês'), ('lista', 'Lista'), ('comprar', 'Comprar'), ('relatorio', 'Relatório')];

class BarraNavegacao extends StatelessWidget {
  const BarraNavegacao({super.key, required this.activo, required this.aoEscolher});
  final String activo;
  final void Function(String id) aoEscolher;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(color: Cores.superficie, border: Border(top: BorderSide(color: Cores.borda))),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Medidas.larguraMaxima),
              child: Row(
                children: [
                  for (final (id, rotulo) in _separadores)
                    Expanded(
                      child: Tocavel(
                        aoPremir: () => aoEscolher(id),
                        actual: id == activo,
                        escala: 0.96,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: Medidas.alturaNav),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icone(id, tamanho: 24, cor: id == activo ? Cores.verde : Cores.tinta2),
                              const SizedBox(height: 4),
                              // Com letra grande, o nome encolhe para caber numa linha em vez de partir a palavra.
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    rotulo,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontFamily: fonte,
                                      fontSize: 13,
                                      fontWeight: id == activo ? FontWeight.w700 : FontWeight.w500,
                                      color: id == activo ? Cores.verde : Cores.tinta2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ---------- Páginas ----------

/// Página com deslocamento, a largura máxima da versão web e as margens da tela.
class Pagina extends StatelessWidget {
  const Pagina({super.key, required this.children, this.controlador});
  final List<Widget> children;
  final ScrollController? controlador;

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          controller: controlador,
          padding: const EdgeInsets.fromLTRB(Medidas.margem, 24, Medidas.margem, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Medidas.larguraMaxima - 2 * Medidas.margem),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ),
      );
}

/// Página que ocupa pelo menos o ecrã todo, para o botão principal ficar em baixo
/// (boas-vindas, primeira lista, novo mês). Com letra grande, a página desliza.
class PaginaCheia extends StatelessWidget {
  const PaginaCheia({super.key, required this.children});

  /// Um Spacer entre os elementos empurra o que vem depois para o fundo.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: LayoutBuilder(
          builder: (context, limites) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Medidas.margem, 24, Medidas.margem, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Medidas.larguraMaxima - 2 * Medidas.margem,
                  minHeight: (limites.maxHeight - 48).clamp(0, double.infinity),
                ),
                child: IntrinsicHeight(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Carrega os dados de uma tela e volta a carregá-los quando a tela pede,
/// sem apagar o que está no ecrã enquanto lê.
mixin CarregarDados<W extends StatefulWidget, T> on State<W> {
  T? dados;
  Object? falhaAoCarregar;

  Future<T> carregar();

  @override
  void initState() {
    super.initState();
    recarregar();
  }

  Future<void> recarregar() async {
    try {
      final lidos = await carregar();
      if (!mounted) return;
      setState(() {
        dados = lidos;
        falhaAoCarregar = null;
      });
    } catch (erro, pilha) {
      if (!mounted) return;
      if (dados == null) {
        setState(() => falhaAoCarregar = erro);
      } else {
        tratarErro(context, erro, pilha);
      }
    }
  }

  /// Desenho enquanto os dados não chegam, ou se falharem.
  Widget esperaOuFalha() {
    final falha = falhaAoCarregar;
    if (falha == null) return const SizedBox.expand();
    return _TelaFalha(erro: falha, tentar: recarregar);
  }
}
