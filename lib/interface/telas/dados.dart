// Tela Cópia de segurança (prompt mestre, §33; auditoria SEC-003).

import 'package:flutter/material.dart';

import '../../dados/modelos.dart';
import '../../nucleo/datas.dart';
import '../avisos.dart';
import '../componentes.dart';
import '../copia_ui.dart';
import '../encaminhador.dart';
import '../tema.dart';

class TelaDados extends StatelessWidget {
  const TelaDados({super.key, required this.utilizador});
  final Utilizador utilizador;

  @override
  Widget build(BuildContext context) {
    final encaminhador = Encaminhador.de(context);
    final ultima = utilizador.ultimaCopiaEm;
    const titulo = TextStyle(fontFamily: fonte, fontSize: Letra.destaque, fontWeight: FontWeight.w700, color: Cores.tinta);

    return Pagina(children: [
      Align(
        alignment: Alignment.centerLeft,
        child: BotaoVoltar(rotulo: 'Voltar ao mês', aoPremir: () => encaminhador.voltar('mes')),
      ),
      const SizedBox(height: 16),
      const Cabecalho(titulo: 'Cópia de segurança'),
      Cartao(
        child: Coluna(intervalo: 12, children: [
          Semantics(header: true, child: const Text('Guardar uma cópia', style: titulo)),
          const Nota('Um ficheiro com todos os teus dados: meses, listas, compras e preços. Os dados só existem neste telefone; '
              'se desinstalares a aplicação ou mudares de telefone, é esta cópia que os recupera.'),
          const Nota('Guarda o ficheiro fora do telefone, por exemplo no teu email ou no Google Drive.'),
          Text(
            ultima != null ? 'Última cópia: ${formatarDataLonga(ultima.substring(0, 10))}.' : 'Ainda não guardaste nenhuma cópia.',
            style: Estilos.forte,
          ),
          Botao('Guardar cópia', aoPremir: () async {
            if (!await guardarCopia()) return;
            if (context.mounted) mostrarAviso(context, 'Cópia guardada.');
            encaminhador.redesenhar();
          }),
        ]),
      ),
      const SizedBox(height: 16),
      Cartao(
        child: Coluna(intervalo: 12, children: [
          Semantics(header: true, child: const Text('Repor a partir de uma cópia', style: titulo)),
          const Nota('Substitui todos os dados deste telefone pelos do ficheiro. Serve para mudar de telefone.'),
          Botao('Escolher ficheiro', tipo: TipoBotao.secundario, aoPremir: () async {
            if (!await reporDeFicheiro(context, substituir: true)) return;
            if (context.mounted) mostrarAviso(context, 'Cópia reposta.');
            encaminhador.separador('mes');
          }),
        ]),
      ),
    ]);
  }
}
