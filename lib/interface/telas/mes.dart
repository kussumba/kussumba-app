// Tela Mês (prompt mestre, §5 a §8 e §38; tela de referência 1).
// Todos os números vêm do painel calculado nos serviços.

import 'package:flutter/material.dart';

import '../../dados/modelos.dart';
import '../../nucleo/alertas.dart';
import '../../nucleo/datas.dart';
import '../../nucleo/formatos.dart';
import '../../servicos/comum.dart';
import '../../servicos/meses.dart';
import '../../servicos/relatorio.dart';
import '../avisos.dart';
import '../componentes.dart';
import '../encaminhador.dart';
import '../icones.dart';
import '../tema.dart';
import '../textos.dart';

class TelaMes extends StatefulWidget {
  const TelaMes({super.key, required this.mesId, required this.utilizador});
  final String mesId;
  final Utilizador utilizador;

  @override
  State<TelaMes> createState() => _TelaMesEstado();
}

class _TelaMesEstado extends State<TelaMes> with CarregarDados<TelaMes, Painel> {
  @override
  Future<Painel> carregar() => painelMes(widget.mesId);

  Future<void> _alterarPlafond(Painel painel) async {
    final actual = painel.orcamento.plafond;
    final novo = await pedirKz(
      context,
      titulo: 'Plafond do mês',
      rotulo: 'Quanto tens para as compras de ${painel.rotulo}?',
      valor: actual,
      guardar: (valor) async {
        // Um plafond cinco vezes maior ou menor do que o actual parece engano de digitação.
        if (pareceEngano(valor, actual) &&
            !(await confirmar(
              context,
              titulo: 'Confirmas este plafond?',
              texto: 'Passa de ${formatarKz(actual)} para ${formatarKz(valor)}.',
              confirmar: 'Sim, está certo',
              cancelar: 'Corrigir',
            ))) {
          throw const ErroKussumba('Corrige o valor do plafond.');
        }
        await alterarPlafond(painel.mes.id, valor);
      },
    );
    if (novo == null || !mounted) return;
    mostrarAviso(context, 'Plafond actualizado.');
    await recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final painel = dados;
    if (painel == null) return esperaOuFalha();
    final encaminhador = Encaminhador.de(context);
    // A ultrapassagem já aparece no cartão do saldo; o alerta mostra a mensagem seguinte, se houver.
    final primeiroAlerta = painel.alertas.where((a) => a.tipo != 'orcamento_ultrapassado').firstOrNull;
    final emAndamento = painel.compraEmAndamento;
    final ultimaCopia = widget.utilizador.ultimaCopiaEm;

    return Pagina(children: [
      Cabecalho(sobre: 'Mês em curso', titulo: painel.rotulo),
      _CartaoSaldo(orcamento: painel.orcamento, aoAlterarPlafond: () => _alterarPlafond(painel)),
      if (primeiroAlerta != null) ...[const SizedBox(height: 16), AlertaLinha.de(primeiroAlerta)],
      const SizedBox(height: 20),
      emAndamento == null
          ? Botao('Nova ida às compras', icone: 'mais', aoPremir: () => encaminhador.separador('comprar'))
          : Botao('Continuar compra em ${emAndamento.compra.estabelecimento}',
              icone: 'comprar', aoPremir: () => encaminhador.separador('comprar')),
      _Previsao(painel: painel),
      _RitmoDeGastos(painel: painel),
      Seccao(
        titulo: 'Idas deste mês',
        child: painel.compras.isEmpty
            ? const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Nota('Ainda não há idas às compras este mês.'))
            : ListaLinhas(separadas: true, children: [
                for (final c in painel.compras)
                  Linha(
                    titulo: c.compra.estabelecimento,
                    meta: '${formatarDataCurta(c.compra.data)} · ${artigos(c.artigos)}',
                    abaixo: c.compra.estado == 'em_andamento'
                        ? const Padding(
                            padding: EdgeInsets.only(top: 6), child: Etiqueta('Em andamento', tipo: TipoEtiqueta.aviso))
                        : null,
                    valor: formatarKz(c.total),
                    aoPremir: () => c.compra.estado == 'em_andamento'
                        ? encaminhador.separador('comprar')
                        : encaminhador.navegar('compra/${c.compra.id}'),
                  ),
              ]),
      ),
      const SizedBox(height: 28),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Ligacao('Cópia de segurança', aoPremir: () => encaminhador.navegar('dados')),
          Nota(ultimaCopia != null
              ? 'Última cópia: ${formatarDataLonga(ultimaCopia.substring(0, 10))}.'
              : 'Os teus dados só existem neste telefone. Guarda uma cópia de vez em quando.'),
        ],
      ),
    ]);
  }
}

class _CartaoSaldo extends StatelessWidget {
  const _CartaoSaldo({required this.orcamento, required this.aoAlterarPlafond});
  final Orcamento orcamento;
  final VoidCallback aoAlterarPlafond;

  @override
  Widget build(BuildContext context) {
    final excedido = orcamento.ultrapassado;
    const rotulo = TextStyle(fontFamily: fonte, fontSize: Letra.meta, color: Cores.tinta2, height: 1.45);
    const valor = TextStyle(fontFamily: fonte, fontSize: 15, fontWeight: FontWeight.w700, color: Cores.tinta, height: 1.45);
    final percentagem = orcamento.percentagem;
    return Cartao(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(excedido ? 'Orçamento ultrapassado em' : 'Sobra disponível',
                    style: const TextStyle(fontFamily: fonte, fontSize: 15, color: Cores.tinta2, height: 1.45)),
                const SizedBox(height: 2),
                Destaque(
                  Text(
                    formatarKz(excedido ? -orcamento.saldo : orcamento.saldo),
                    style: TextStyle(
                      fontFamily: fonte,
                      fontSize: Letra.valor,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.26,
                      color: excedido ? Cores.subida : Cores.verde,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BarraProgresso(
            largura: orcamento.larguraBarra,
            excedido: excedido,
            rotulo: 'Plafond utilizado: ${percentagem == null ? 0 : arredondar(percentagem)}%',
          ),
          const SizedBox(height: 14),
          // Gasto à esquerda e plafond à direita; com letra grande, o plafond passa para baixo.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            runSpacing: 4,
            children: [
              MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [const Text('Gasto', style: rotulo), Text(formatarKz(orcamento.gasto), style: valor)],
                ),
              ),
              Transform.translate(
                offset: const Offset(8, 6),
                child: Tocavel(
                  aoPremir: aoAlterarPlafond,
                  rotulo: 'Plafond ${formatarKz(orcamento.plafond)}. Alterar plafond',
                  raio: BorderRadius.circular(Medidas.raioPequeno),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: Medidas.toque),
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Plafond', style: rotulo),
                          SizedBox(width: 4),
                          Icone('editar', tamanho: 14, cor: Cores.tinta2),
                        ]),
                        Text(formatarKz(orcamento.plafond), style: valor),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Previsão das compras restantes (§6): saldo actual comparado com o que falta comprar na lista.
class _Previsao extends StatelessWidget {
  const _Previsao({required this.painel});
  final Painel painel;

  @override
  Widget build(BuildContext context) {
    final lista = painel.lista;
    final encaminhador = Encaminhador.de(context);
    final Widget corpo;
    if (lista.artigos == 0) {
      corpo = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ainda não tens lista para este mês.', style: Estilos.corpo),
        const SizedBox(height: 8),
        Ligacao('Criar a lista', aoPremir: () => encaminhador.separador('lista')),
      ]);
    } else if (lista.pendentes == 0) {
      corpo = const Text('Já compraste tudo o que estava na lista.', style: Estilos.corpo);
    } else if (lista.pendentePrevisto == 0) {
      corpo = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Os artigos por comprar ainda não têm preço previsto.', style: Estilos.corpo),
        const SizedBox(height: 8),
        Ligacao('Indicar preços na lista', aoPremir: () => encaminhador.separador('lista')),
      ]);
    } else {
      final cobertura = painel.cobertura ?? 0;
      corpo = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Pares(children: [
          Par.texto('Lista por comprar · ${artigos(lista.pendentes)}', formatarKz(lista.pendentePrevisto)),
          Par.texto('Saldo actual', formatarKz(painel.orcamento.saldo)),
        ]),
        const Divisor(),
        cobertura < 0
            ? Resultado(icone: 'aviso', cor: Cores.subida, partes: [
                ('Faltam ', false),
                (formatarKz(-cobertura), true),
                (' para cumprir a lista.', false),
              ])
            : const Resultado(icone: 'positivo', cor: Cores.verde, partes: [('O saldo disponível cobre as compras previstas.', false)]),
        if (lista.pendenteSemPreco > 0) ...[
          const SizedBox(height: 10),
          Nota(lista.pendenteSemPreco == 1
              ? '1 artigo sem preço previsto não entra nesta conta.'
              : '${lista.pendenteSemPreco} artigos sem preço previsto não entram nesta conta.'),
        ],
      ]);
    }
    return Seccao(titulo: 'Previsão das compras restantes', child: Cartao(child: corpo));
  }
}

/// Ritmo de gastos (§7): informativo, nunca julgador.
class _RitmoDeGastos extends StatelessWidget {
  const _RitmoDeGastos({required this.painel});
  final Painel painel;

  @override
  Widget build(BuildContext context) {
    final ritmo = painel.ritmo;
    final Widget corpo;
    if (ritmo.disponivel) {
      final face = ritmo.faceAoPlafond ?? 0;
      corpo = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Pares(children: [Par.texto('Média diária', formatarKz(ritmo.mediaDiaria))]),
        const SizedBox(height: 12),
        Text.rich(TextSpan(style: Estilos.corpo, children: [
          const TextSpan(text: 'Se mantiveres este ritmo, a previsão de gasto mensal é '),
          TextSpan(text: formatarKz(ritmo.previsaoMensal), style: const TextStyle(fontWeight: FontWeight.w700)),
          if (face > 0) ...[
            const TextSpan(text: ', '),
            TextSpan(text: '${formatarKz(face)} acima do plafond', style: const TextStyle(color: Cores.subida)),
            const TextSpan(text: '.'),
          ] else
            const TextSpan(text: ', dentro do plafond.'),
        ])),
        const SizedBox(height: 8),
        Nota('Estimativa feita com ${plural(ritmo.diasDecorridos, 'dia', 'dias')} de ${ritmo.diasNoMes}.'),
      ]);
    } else if (painel.orcamento.gasto == 0) {
      corpo = const Nota('Ainda não registaste compras este mês.');
    } else if (ritmo.diasDecorridos == 0) {
      corpo = const Nota('Este mês ainda não começou no calendário.');
    } else {
      corpo = Nota(
          'A média diária aparece a partir do dia ${ritmo.diasMinimos} do mês, quando já há dias suficientes para uma estimativa.');
    }
    return Seccao(titulo: 'Ritmo de gastos', child: Cartao(child: corpo));
  }
}
