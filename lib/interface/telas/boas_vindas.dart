// Primeira utilização (prompt mestre, §45): pergunta apenas o plafond mensal.

import 'package:flutter/material.dart';

import '../../nucleo/formatos.dart';
import '../../servicos/comum.dart';
import '../../servicos/meses.dart';
import '../avisos.dart';
import '../componentes.dart';
import '../copia_ui.dart';
import '../encaminhador.dart';
import '../icones.dart';
import '../tema.dart';

class TelaBoasVindas extends StatefulWidget {
  const TelaBoasVindas({super.key});

  @override
  State<TelaBoasVindas> createState() => _TelaBoasVindasEstado();
}

class _TelaBoasVindasEstado extends State<TelaBoasVindas> {
  final _plafond = TextEditingController();
  final _foco = FocusNode();
  String? _erro;

  @override
  void dispose() {
    _plafond.dispose();
    _foco.dispose();
    super.dispose();
  }

  Future<void> _continuar() async {
    try {
      await configurarInicio(plafond: lerKz(_plafond.text));
    } on ErroKussumba catch (erro) {
      setState(() => _erro = erro.mensagem);
      _foco.requestFocus();
      return;
    }
    if (mounted) Encaminhador.de(context).navegar('primeira-lista');
  }

  Future<void> _repor() async {
    final encaminhador = Encaminhador.de(context);
    await executar(context, () async {
      if (!await reporDeFicheiro(context, substituir: false)) return;
      if (!mounted) return;
      mostrarAviso(context, 'Cópia reposta. Bem-vinda de volta.');
      encaminhador.separador('mes');
    });
  }

  @override
  Widget build(BuildContext context) => PaginaCheia(children: [
        const SizedBox(height: 12),
        Row(children: [
          const MarcaKussumba(),
          const SizedBox(width: 12),
          ExcludeSemantics(
            child: Destaque(Text('KUSSUMBA',
                style: Estilos.titulo.copyWith(fontSize: 20, letterSpacing: 1.6, color: Cores.verde, height: 1.3))),
          ),
        ]),
        const SizedBox(height: 40),
        Semantics(
          header: true,
          child: Destaque(Text('Bem-vinda à KUSSUMBA', style: Estilos.titulo.copyWith(fontSize: 34, height: 1.1, letterSpacing: -1.02))),
        ),
        const SizedBox(height: 10),
        Text('A tua comadre nas compras de casa.', style: Estilos.corpo.copyWith(fontSize: Letra.destaque, color: Cores.tinta2)),
        const SizedBox(height: 40),
        CampoKz(
          controlador: _plafond,
          foco: _foco,
          rotulo: 'Qual é o teu plafond mensal para compras?',
          ajuda: 'O valor que reservas por mês para as compras de casa. Podes mudá-lo depois.',
          erro: _erro,
          aoMudar: () {
            if (_erro != null) setState(() => _erro = null);
          },
          aoSubmeter: _continuar,
        ),
        const SizedBox(height: 24),
        const Spacer(),
        Botao('Continuar', aoPremir: _continuar),
        const SizedBox(height: 12),
        Center(child: Ligacao('Já usaste a KUSSUMBA noutro telefone? Repor uma cópia', aoPremir: _repor, alinhamento: TextAlign.center)),
      ]);
}
