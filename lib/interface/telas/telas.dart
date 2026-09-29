// Mapa das telas da KUSSUMBA: caminho, separador da barra inferior e se precisam de um mês aberto
// (as mesmas regras da versão web, js/app.js e o "precisaMesAberto" de cada tela).

import '../encaminhador.dart';
import 'boas_vindas.dart';
import 'catalogo.dart';
import 'compra.dart';
import 'comprar.dart';
import 'dados.dart';
import 'lista.dart';
import 'mes.dart';
import 'novo_mes.dart';
import 'primeira_lista.dart';
import 'relatorio.dart';

final Map<String, DefinicaoTela> telasKussumba = {
  'boas-vindas': DefinicaoTela(construir: (rota, contexto) => const TelaBoasVindas()),
  'primeira-lista': DefinicaoTela(
    precisaMesAberto: true,
    construir: (rota, contexto) => TelaPrimeiraLista(mesId: contexto.mesAberto!.id),
  ),
  'mes': DefinicaoTela(
    precisaMesAberto: true,
    separador: (_) => 'mes',
    construir: (rota, contexto) => TelaMes(mesId: contexto.mesAberto!.id, utilizador: contexto.utilizador!),
  ),
  'lista': DefinicaoTela(
    precisaMesAberto: true,
    separador: (_) => 'lista',
    construir: (rota, contexto) => TelaLista(mesId: contexto.mesAberto!.id),
  ),
  'catalogo': DefinicaoTela(
    precisaMesAberto: true,
    construir: (rota, contexto) => TelaCatalogo(mesId: contexto.mesAberto!.id),
  ),
  // Durante o registo de uma compra, a barra inferior esconde-se para dar lugar ao teclado do preço.
  'comprar': DefinicaoTela(
    precisaMesAberto: true,
    separador: (contexto) => contexto.compraEmAndamento == null ? 'comprar' : null,
    construir: (rota, contexto) => TelaComprar(contexto: contexto),
  ),
  'compra': DefinicaoTela(
    separador: (_) => 'mes',
    construir: (rota, contexto) => TelaCompra(
      compraId: rota.parametros.firstOrNull ?? '',
      acabadaDeConcluir: rota.parametros.length > 1 && rota.parametros[1] == 'concluida',
    ),
  ),
  'relatorio': DefinicaoTela(separador: (_) => 'relatorio', construir: (rota, contexto) => const TelaRelatorio()),
  'novo-mes': DefinicaoTela(construir: (rota, contexto) => const TelaNovoMes()),
  'dados': DefinicaoTela(
    separador: (_) => 'mes',
    construir: (rota, contexto) => TelaDados(utilizador: contexto.utilizador!),
  ),
};
