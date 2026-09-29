// Depois do plafond (prompt mestre, §45 e §46): criar a primeira lista.

import 'package:flutter/material.dart';

import '../../servicos/lista.dart';
import '../avisos.dart';
import '../componentes.dart';
import '../encaminhador.dart';
import '../tema.dart';

class TelaPrimeiraLista extends StatelessWidget {
  const TelaPrimeiraLista({super.key, required this.mesId});
  final String mesId;

  @override
  Widget build(BuildContext context) {
    final encaminhador = Encaminhador.de(context);
    return PaginaCheia(children: [
      const SizedBox(height: 24),
      Semantics(
        header: true,
        child: Destaque(Text('Queres criar a tua primeira lista?',
            style: Estilos.titulo.copyWith(fontSize: 34, height: 1.1, letterSpacing: -1.02))),
      ),
      const SizedBox(height: 10),
      Text('Começa pelos produtos básicos ou escolhe no catálogo. Podes mudar tudo depois.',
          style: Estilos.corpo.copyWith(fontSize: Letra.destaque, color: Cores.tinta2)),
      const SizedBox(height: 32),
      OpcaoGrande(
        titulo: 'Começar com produtos sugeridos',
        meta: 'Arroz, óleo, açúcar, feijão, fuba e outros básicos da casa',
        aoPremir: () async {
          final n = await adicionarSugeridos(mesId);
          if (!context.mounted) return;
          mostrarAviso(context, n == 1 ? '1 produto adicionado à lista.' : '$n produtos adicionados à lista.');
          encaminhador.separador('lista');
        },
      ),
      const SizedBox(height: 12),
      OpcaoGrande(
        titulo: 'Adicionar produtos',
        meta: 'Escolhes no catálogo só o que precisas',
        aoPremir: () => encaminhador.navegar('catalogo'),
      ),
      const SizedBox(height: 24),
      const Spacer(),
      Botao('Agora não', tipo: TipoBotao.texto, aoPremir: () => encaminhador.separador('mes')),
    ]);
  }
}
