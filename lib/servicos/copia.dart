// Cópia de segurança (prompt mestre, §33; auditoria SEC-003).
// Mesmo formato da versão web: uma cópia feita no site pode ser reposta na aplicação e vice-versa.
//
// Um ficheiro de cópia vem de fora da aplicação e é tratado como não fiável: tamanho limitado,
// cada campo validado, campos desconhecidos descartados, referências entre registos verificadas.
// A reposição é uma única transacção: ou entra tudo, ou nada muda.

import 'dart:convert';

import '../dados/base_dados.dart';
import '../dados/catalogo_inicial.dart';
import '../dados/modelos.dart';
import '../nucleo/datas.dart';
import '../nucleo/unidades.dart';
import 'comum.dart';
import 'relatorio.dart';

const String formatoCopia = 'kussumba-copia';

/// Versão do formato do ficheiro de cópia (independente da versão da base de dados).
const int versaoFormatoCopia = 1;
const int tamanhoMaximo = 20 * 1024 * 1024;
const int _registosMaximos = 200000;

/// Colecções do ficheiro e tabelas correspondentes, pela ordem em que se repõem.
const Map<String, String> _tabelaDe = {
  'utilizador': 'utilizador',
  'meses': 'meses',
  'produtos': 'produtos',
  'itensLista': 'itens_lista',
  'compras': 'compras',
  'itensCompra': 'itens_compra',
  'historicoPrecos': 'historico_precos',
};

// Campos lógicos: na base de dados são 0 e 1, no ficheiro são true e false.
const Map<String, List<String>> _logicos = {
  'produtos': ['basico', 'activo', 'personalizado'],
  'itensLista': ['comprado'],
};

// ---------- Regras de cada campo ----------

typedef _Regra = bool Function(Object?);

_Regra _texto(int maximo) => (v) => v is String && v.isNotEmpty && v.length <= maximo;
_Regra _opcional(_Regra regra) => (v) => v == null || regra(v);
bool _inteiroPositivo(Object? v) => v is int && v > 0;
bool _kz(Object? v) => _inteiroPositivo(v) && (v! as int) <= maximoKz;
bool _positivo(Object? v) => v is num && v.isFinite && v > 0;
bool _naoNegativo(Object? v) => v is num && v.isFinite && v >= 0;
bool _numero(Object? v) => v is num && v.isFinite;
bool _booleano(Object? v) => v is bool;
_Regra _umDe(List<String> valores) => (v) => valores.contains(v);
bool _data(Object? v) => dataValida(v);
bool _idMes(Object? v) => v is String && RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(v);
final _Regra _id = _texto(80);
final _Regra _instante = _opcional(_texto(40));

// Só estes campos são repostos; qualquer outro é descartado.
// O resumo dos meses fechados não vem da cópia: é recalculado a partir dos dados.
final Map<String, Map<String, _Regra>> _esquema = {
  'utilizador': {
    'id': _umDe(['eu']), 'nome': _opcional(_texto(60)), 'moeda': _umDe(['AOA']), 'ultimaCopiaEm': _instante,
    'criadoEm': _instante, 'actualizadoEm': _instante,
  },
  'meses': {
    'id': _idMes, 'ano': _inteiroPositivo, 'mes': (v) => v is int && v >= 1 && v <= 12, 'plafond': _kz,
    'estado': _umDe(['aberto', 'fechado']), 'listaCopiadaDe': _opcional(_idMes),
    'criadoEm': _instante, 'fechadoEm': _instante, 'actualizadoEm': _instante,
  },
  'produtos': {
    'id': _id, 'nome': _texto(60), 'nomeNormalizado': _texto(80), 'categoria': _umDe(categorias.map((c) => c.id).toList()),
    'unidade': unidadeValida, 'unidadeTexto': _opcional(_texto(20)), 'quantidadeSugerida': _positivo,
    'icone': _opcional(_texto(20)), 'genero': _opcional(_umDe(['o', 'a', 'os', 'as'])),
    'basico': _opcional(_booleano), 'activo': _booleano, 'personalizado': _opcional(_booleano),
    'ordem': _opcional((v) => v is int && v >= 0), 'criadoEm': _instante, 'actualizadoEm': _instante,
  },
  'itensLista': {
    'id': _id, 'mesId': _idMes, 'produtoId': _id, 'unidade': unidadeValida, 'unidadeTexto': _opcional(_texto(20)),
    'quantidadePrevista': _positivo, 'precoUnitarioPrevisto': _opcional(_naoNegativo), 'comprado': _booleano,
    'compraId': _opcional(_id), 'ordem': _numero, 'criadoEm': _instante, 'actualizadoEm': _instante,
  },
  'compras': {
    'id': _id, 'mesId': _idMes, 'estabelecimento': _texto(60), 'data': _data,
    'estado': _umDe(['em_andamento', 'concluida']), 'origem': _opcional(_texto(20)),
    'totalPrevisto': _opcional(_naoNegativo), 'totalReal': _opcional(_naoNegativo), 'diferenca': _opcional(_numero),
    'artigos': _opcional(_naoNegativo), 'criadoEm': _instante, 'concluidaEm': _instante, 'actualizadoEm': _instante,
  },
  'itensCompra': {
    'id': _id, 'compraId': _id, 'mesId': _idMes, 'produtoId': _id, 'itemListaId': _opcional(_id),
    'quantidadePlaneada': _opcional(_positivo), 'quantidade': _positivo, 'unidade': unidadeValida,
    'unidadeTexto': _opcional(_texto(20)), 'precoUnitarioPrevisto': _opcional(_naoNegativo),
    'precoPrevisto': _opcional(_naoNegativo), 'precoReal': _kz, 'precoUnitarioReal': _positivo,
    'registadoEm': _instante, 'corrigidoEm': _instante, 'actualizadoEm': _instante,
  },
  'historicoPrecos': {
    'id': _id, 'produtoId': _id, 'itemCompraId': _id, 'compraId': _id, 'mesId': _idMes, 'data': _data,
    'estabelecimento': _texto(60), 'precoTotal': _kz, 'quantidade': _positivo, 'unidade': unidadeValida,
    'unidadeTexto': _opcional(_texto(20)), 'quantidadeBase': _positivo, 'unidadeBase': _texto(40),
    'precoUnitarioBase': _positivo, 'registadoEm': _instante, 'corrigidoEm': _instante,
  },
};

ErroKussumba _danificada(String detalhe) => ErroKussumba('A cópia está danificada ou não é da KUSSUMBA ($detalhe).');

/// Valida um registo e devolve-o só com os campos conhecidos.
Map<String, Object?> _limparRegisto(String colecao, Object? registo, int posicao) {
  if (registo is! Map) throw _danificada('$colecao, registo ${posicao + 1}');
  final limpo = <String, Object?>{};
  _esquema[colecao]!.forEach((campo, regra) {
    final valor = registo[campo];
    if (!regra(valor)) throw _danificada('$colecao, registo ${posicao + 1}, campo $campo');
    if (valor != null) limpo[campo] = valor;
  });
  return limpo;
}

void _verificarReferencias(Map<String, List<Map<String, Object?>>> d) {
  final ids = <String, Set<Object?>>{};
  for (final colecao in _tabelaDe.keys) {
    ids[colecao] = d[colecao]!.map((r) => r['id']).toSet();
    if (ids[colecao]!.length != d[colecao]!.length) throw _danificada('$colecao com identificadores repetidos');
  }
  void existe(String colecao, Object? valor, String onde) {
    if (!ids[colecao]!.contains(valor)) throw _danificada('$onde refere um registo que não existe');
  }

  if (d['utilizador']!.length != 1) throw _danificada('utilizador');
  if (d['meses']!.isEmpty) throw _danificada('sem meses');
  final abertos = d['meses']!.where((m) => m['estado'] == 'aberto').toList();
  if (abertos.length > 1) throw _danificada('mais do que um mês aberto');

  for (final i in d['itensLista']!) {
    existe('meses', i['mesId'], 'itensLista');
    existe('produtos', i['produtoId'], 'itensLista');
    if (i['compraId'] != null) existe('compras', i['compraId'], 'itensLista');
  }
  final compras = {for (final c in d['compras']!) c['id']: c};
  for (final c in d['compras']!) {
    existe('meses', c['mesId'], 'compras');
    if (c['estado'] == 'em_andamento' && (abertos.isEmpty || c['mesId'] != abertos.first['id'])) {
      throw _danificada('compra em andamento num mês fechado');
    }
  }
  if (d['compras']!.where((c) => c['estado'] == 'em_andamento').length > 1) {
    throw _danificada('mais do que uma compra em andamento');
  }
  for (final i in d['itensCompra']!) {
    existe('compras', i['compraId'], 'itensCompra');
    existe('produtos', i['produtoId'], 'itensCompra');
    if (compras[i['compraId']]!['mesId'] != i['mesId']) throw _danificada('itensCompra noutro mês');
    if (i['itemListaId'] != null) existe('itensLista', i['itemListaId'], 'itensCompra');
  }
  final historicoPorArtigo = <Object?>{};
  for (final h in d['historicoPrecos']!) {
    existe('produtos', h['produtoId'], 'historicoPrecos');
    existe('itensCompra', h['itemCompraId'], 'historicoPrecos');
    if (!historicoPorArtigo.add(h['itemCompraId'])) throw _danificada('historicoPrecos repetido');
  }
}

class ResumoCopia {
  const ResumoCopia(this.criadaEm, this.meses, this.compras, this.artigosComprados);
  final String? criadaEm;
  final int meses;
  final int compras;
  final int artigosComprados;
}

ResumoCopia _resumir(Map<String, List<Map<String, Object?>>> d, String? criadaEm) =>
    ResumoCopia(criadaEm, d['meses']!.length, d['compras']!.length, d['itensCompra']!.length);

class CopiaLida {
  const CopiaLida(this.dados, this.resumo);
  final Map<String, List<Map<String, Object?>>> dados;
  final ResumoCopia resumo;
}

// ---------- Exportar ----------

/// Todos os dados num texto JSON, pronto a guardar num ficheiro.
Future<String> exportarCopia() async {
  final dados = await transaccao((t) async {
    final resultado = <String, List<Map<String, Object?>>>{};
    for (final entrada in _tabelaDe.entries) {
      final logicos = _logicos[entrada.key] ?? const [];
      resultado[entrada.key] = (await todasAsLinhas(t, entrada.value)).map((linha) {
        final registo = Map<String, Object?>.from(linha);
        // O resumo dos meses fechados não vai na cópia: recalcula-se ao repor.
        if (entrada.key == 'meses') registo.remove('resumoFecho');
        for (final campo in logicos) {
          registo[campo] = registo[campo] == 1;
        }
        registo.removeWhere((_, valor) => valor == null);
        return registo;
      }).toList();
    }
    return resultado;
  });
  final criadaEm = carimbo();
  final r = _resumir(dados, criadaEm);
  return jsonEncode({
    'formato': formatoCopia,
    'versaoDados': versaoFormatoCopia,
    'criadaEm': criadaEm,
    'resumo': {'criadaEm': criadaEm, 'meses': r.meses, 'compras': r.compras, 'artigosComprados': r.artigosComprados},
    'dados': dados,
  });
}

/// Guarda a data da última cópia, para o utilizador saber quando fez a última.
Future<String?> registarCopiaFeita() => transaccao((t) async {
      final linha = await obterLinha(t, 'utilizador', 'eu');
      if (linha == null) return null;
      final utilizador = Utilizador.daLinha(linha)
        ..ultimaCopiaEm = carimbo();
      await guardarLinha(t, 'utilizador', utilizador.paraLinha());
      return utilizador.ultimaCopiaEm;
    });

// ---------- Repor ----------

/// Lê e valida o texto de um ficheiro de cópia. Não grava nada.
CopiaLida lerCopia(String textoDoFicheiro) {
  if (textoDoFicheiro.length > tamanhoMaximo) {
    throw const ErroKussumba('O ficheiro é demasiado grande para ser uma cópia da KUSSUMBA.');
  }
  Object? bruto;
  try {
    bruto = jsonDecode(textoDoFicheiro);
  } on FormatException {
    throw const ErroKussumba('Este ficheiro não é uma cópia da KUSSUMBA.');
  }
  if (bruto is! Map || bruto['formato'] != formatoCopia || bruto['dados'] is! Map) {
    throw const ErroKussumba('Este ficheiro não é uma cópia da KUSSUMBA.');
  }
  final versao = bruto['versaoDados'];
  if (versao is! int || versao < 1) throw _danificada('versão');
  if (versao > versaoFormatoCopia) {
    throw const ErroKussumba('Esta cópia foi feita por uma versão mais recente da KUSSUMBA. Actualiza a aplicação e tenta de novo.');
  }
  final origem = bruto['dados'] as Map;
  var total = 0;
  final dados = <String, List<Map<String, Object?>>>{};
  for (final colecao in _tabelaDe.keys) {
    final registos = origem[colecao];
    if (registos is! List) throw _danificada(colecao);
    total += registos.length;
    if (total > _registosMaximos) throw _danificada('demasiados registos');
    dados[colecao] = [for (var i = 0; i < registos.length; i++) _limparRegisto(colecao, registos[i], i)];
  }
  _verificarReferencias(dados);
  final criadaEm = bruto['criadaEm'] is String ? bruto['criadaEm'] as String : null;
  return CopiaLida(dados, _resumir(dados, criadaEm));
}

/// Substitui todos os dados deste telefone pelos da cópia já validada por lerCopia.
/// Os resumos dos meses fechados são recalculados a partir dos dados repostos.
Future<ResumoCopia> reporCopia(CopiaLida copia) => transaccao((t) async {
      // Apaga pela ordem inversa, por causa das referências entre tabelas.
      for (final tabela in _tabelaDe.values.toList().reversed) {
        await limparTabela(t, tabela);
      }
      for (final entrada in _tabelaDe.entries) {
        final logicos = _logicos[entrada.key] ?? const [];
        for (final registo in copia.dados[entrada.key]!) {
          final linha = Map<String, Object?>.from(registo);
          for (final campo in logicos) {
            if (linha.containsKey(campo)) linha[campo] = linha[campo] == true ? 1 : 0;
          }
          // As cópias da versão web não trazem a posição dos produtos do catálogo inicial.
          if (entrada.key == 'produtos' && linha['ordem'] == null) {
            final posicao = produtosIniciais.indexWhere((p) => p.id == linha['id']);
            if (posicao >= 0) linha['ordem'] = posicao;
          }
          await t.insert(entrada.value, linha);
        }
      }
      for (final mes in copia.dados['meses']!.where((m) => m['estado'] == 'fechado')) {
        final id = mes['id']! as String;
        final resumo = calcularRelatorio(await recolherDadosRelatorio(t, id));
        await t.update('meses', {'resumoFecho': jsonEncode(resumo.paraJson())}, where: 'id = ?', whereArgs: [id]);
      }
      return copia.resumo;
    });
