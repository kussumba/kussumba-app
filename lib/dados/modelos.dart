// Registos guardados na base de dados local (prompt mestre, §31).
// Cada classe converte-se de e para uma linha da tabela correspondente.

import 'dart:convert';

double? _real(Object? v) => (v as num?)?.toDouble();
int? _inteiro(Object? v) => (v as num?)?.toInt();
bool _logico(Object? v) => v == 1 || v == true;
int _bit(bool v) => v ? 1 : 0;

class Utilizador {
  Utilizador({required this.id, this.nome, required this.moeda, this.ultimaCopiaEm, this.criadoEm, this.actualizadoEm});

  factory Utilizador.daLinha(Map<String, Object?> l) => Utilizador(
        id: l['id']! as String,
        nome: l['nome'] as String?,
        moeda: l['moeda']! as String,
        ultimaCopiaEm: l['ultimaCopiaEm'] as String?,
        criadoEm: l['criadoEm'] as String?,
        actualizadoEm: l['actualizadoEm'] as String?,
      );

  final String id;
  String? nome;
  String moeda;
  String? ultimaCopiaEm;
  String? criadoEm;
  String? actualizadoEm;

  Map<String, Object?> paraLinha() => {
        'id': id, 'nome': nome, 'moeda': moeda, 'ultimaCopiaEm': ultimaCopiaEm,
        'criadoEm': criadoEm, 'actualizadoEm': actualizadoEm,
      };
}

class Mes {
  Mes({
    required this.id,
    required this.ano,
    required this.mes,
    required this.plafond,
    required this.estado,
    this.listaCopiadaDe,
    this.criadoEm,
    this.fechadoEm,
    this.resumoFecho,
    this.actualizadoEm,
  });

  factory Mes.daLinha(Map<String, Object?> l) => Mes(
        id: l['id']! as String,
        ano: _inteiro(l['ano'])!,
        mes: _inteiro(l['mes'])!,
        plafond: _inteiro(l['plafond'])!,
        estado: l['estado']! as String,
        listaCopiadaDe: l['listaCopiadaDe'] as String?,
        criadoEm: l['criadoEm'] as String?,
        fechadoEm: l['fechadoEm'] as String?,
        resumoFecho: l['resumoFecho'] == null ? null : jsonDecode(l['resumoFecho']! as String) as Map<String, Object?>,
        actualizadoEm: l['actualizadoEm'] as String?,
      );

  final String id;
  final int ano;
  final int mes;
  int plafond;

  /// "aberto" ou "fechado". O estado "em andamento" calcula-se a partir das compras.
  String estado;
  String? listaCopiadaDe;
  String? criadoEm;
  String? fechadoEm;

  /// Relatório congelado no fecho do mês.
  Map<String, Object?>? resumoFecho;
  String? actualizadoEm;

  Map<String, Object?> paraLinha() => {
        'id': id, 'ano': ano, 'mes': mes, 'plafond': plafond, 'estado': estado,
        'listaCopiadaDe': listaCopiadaDe, 'criadoEm': criadoEm, 'fechadoEm': fechadoEm,
        'resumoFecho': resumoFecho == null ? null : jsonEncode(resumoFecho), 'actualizadoEm': actualizadoEm,
      };
}

class Produto {
  Produto({
    required this.id,
    required this.nome,
    required this.nomeNormalizado,
    required this.categoria,
    required this.unidade,
    this.unidadeTexto,
    required this.quantidadeSugerida,
    this.icone,
    this.genero,
    this.basico = false,
    this.activo = true,
    this.personalizado = false,
    this.ordem,
    this.criadoEm,
    this.actualizadoEm,
  });

  factory Produto.daLinha(Map<String, Object?> l) => Produto(
        id: l['id']! as String,
        nome: l['nome']! as String,
        nomeNormalizado: l['nomeNormalizado']! as String,
        categoria: l['categoria']! as String,
        unidade: l['unidade']! as String,
        unidadeTexto: l['unidadeTexto'] as String?,
        quantidadeSugerida: _real(l['quantidadeSugerida'])!,
        icone: l['icone'] as String?,
        genero: l['genero'] as String?,
        basico: _logico(l['basico']),
        activo: _logico(l['activo']),
        personalizado: _logico(l['personalizado']),
        ordem: _inteiro(l['ordem']),
        criadoEm: l['criadoEm'] as String?,
        actualizadoEm: l['actualizadoEm'] as String?,
      );

  final String id;
  String nome;
  String nomeNormalizado;
  String categoria;
  String unidade;
  String? unidadeTexto;
  double quantidadeSugerida;
  String? icone;
  String? genero;
  bool basico;
  bool activo;
  bool personalizado;

  /// Posição no catálogo inicial; os produtos do utilizador não têm.
  int? ordem;
  String? criadoEm;
  String? actualizadoEm;

  Map<String, Object?> paraLinha() => {
        'id': id, 'nome': nome, 'nomeNormalizado': nomeNormalizado, 'categoria': categoria,
        'unidade': unidade, 'unidadeTexto': unidadeTexto, 'quantidadeSugerida': quantidadeSugerida,
        'icone': icone, 'genero': genero, 'basico': _bit(basico), 'activo': _bit(activo),
        'personalizado': _bit(personalizado), 'ordem': ordem, 'criadoEm': criadoEm, 'actualizadoEm': actualizadoEm,
      };
}

class ItemLista {
  ItemLista({
    required this.id,
    required this.mesId,
    required this.produtoId,
    required this.unidade,
    this.unidadeTexto,
    required this.quantidadePrevista,
    this.precoUnitarioPrevisto,
    this.comprado = false,
    this.compraId,
    required this.ordem,
    this.criadoEm,
    this.actualizadoEm,
  });

  factory ItemLista.daLinha(Map<String, Object?> l) => ItemLista(
        id: l['id']! as String,
        mesId: l['mesId']! as String,
        produtoId: l['produtoId']! as String,
        unidade: l['unidade']! as String,
        unidadeTexto: l['unidadeTexto'] as String?,
        quantidadePrevista: _real(l['quantidadePrevista'])!,
        precoUnitarioPrevisto: _real(l['precoUnitarioPrevisto']),
        comprado: _logico(l['comprado']),
        compraId: l['compraId'] as String?,
        ordem: _inteiro(l['ordem'])!,
        criadoEm: l['criadoEm'] as String?,
        actualizadoEm: l['actualizadoEm'] as String?,
      );

  final String id;
  final String mesId;
  final String produtoId;
  String unidade;
  String? unidadeTexto;
  double quantidadePrevista;
  double? precoUnitarioPrevisto;
  bool comprado;
  String? compraId;
  int ordem;
  String? criadoEm;
  String? actualizadoEm;

  Map<String, Object?> paraLinha() => {
        'id': id, 'mesId': mesId, 'produtoId': produtoId, 'unidade': unidade, 'unidadeTexto': unidadeTexto,
        'quantidadePrevista': quantidadePrevista, 'precoUnitarioPrevisto': precoUnitarioPrevisto,
        'comprado': _bit(comprado), 'compraId': compraId, 'ordem': ordem,
        'criadoEm': criadoEm, 'actualizadoEm': actualizadoEm,
      };
}

class Compra {
  Compra({
    required this.id,
    required this.mesId,
    required this.estabelecimento,
    required this.data,
    required this.estado,
    this.origem = 'manual',
    this.totalPrevisto,
    this.totalReal,
    this.diferenca,
    this.artigos,
    this.criadoEm,
    this.concluidaEm,
    this.actualizadoEm,
  });

  factory Compra.daLinha(Map<String, Object?> l) => Compra(
        id: l['id']! as String,
        mesId: l['mesId']! as String,
        estabelecimento: l['estabelecimento']! as String,
        data: l['data']! as String,
        estado: l['estado']! as String,
        origem: (l['origem'] as String?) ?? 'manual',
        totalPrevisto: _inteiro(l['totalPrevisto']),
        totalReal: _inteiro(l['totalReal']),
        diferenca: _inteiro(l['diferenca']),
        artigos: _inteiro(l['artigos']),
        criadoEm: l['criadoEm'] as String?,
        concluidaEm: l['concluidaEm'] as String?,
        actualizadoEm: l['actualizadoEm'] as String?,
      );

  final String id;
  final String mesId;
  String estabelecimento;
  String data;

  /// "em_andamento" ou "concluida".
  String estado;

  /// "manual" hoje; a leitura de talões (§39) criará compras com outra origem,
  /// que ficam em andamento até o utilizador as rever e confirmar.
  String origem;
  int? totalPrevisto;
  int? totalReal;
  int? diferenca;
  int? artigos;
  String? criadoEm;
  String? concluidaEm;
  String? actualizadoEm;

  Map<String, Object?> paraLinha() => {
        'id': id, 'mesId': mesId, 'estabelecimento': estabelecimento, 'data': data, 'estado': estado,
        'origem': origem, 'totalPrevisto': totalPrevisto, 'totalReal': totalReal, 'diferenca': diferenca,
        'artigos': artigos, 'criadoEm': criadoEm, 'concluidaEm': concluidaEm, 'actualizadoEm': actualizadoEm,
      };
}

class ItemCompra {
  ItemCompra({
    required this.id,
    required this.compraId,
    required this.mesId,
    required this.produtoId,
    this.itemListaId,
    this.quantidadePlaneada,
    required this.quantidade,
    required this.unidade,
    this.unidadeTexto,
    this.precoUnitarioPrevisto,
    this.precoPrevisto,
    required this.precoReal,
    this.precoUnitarioReal,
    this.registadoEm,
    this.corrigidoEm,
    this.actualizadoEm,
  });

  factory ItemCompra.daLinha(Map<String, Object?> l) => ItemCompra(
        id: l['id']! as String,
        compraId: l['compraId']! as String,
        mesId: l['mesId']! as String,
        produtoId: l['produtoId']! as String,
        itemListaId: l['itemListaId'] as String?,
        quantidadePlaneada: _real(l['quantidadePlaneada']),
        quantidade: _real(l['quantidade'])!,
        unidade: l['unidade']! as String,
        unidadeTexto: l['unidadeTexto'] as String?,
        precoUnitarioPrevisto: _real(l['precoUnitarioPrevisto']),
        precoPrevisto: _inteiro(l['precoPrevisto']),
        precoReal: _inteiro(l['precoReal'])!,
        precoUnitarioReal: _real(l['precoUnitarioReal']),
        registadoEm: l['registadoEm'] as String?,
        corrigidoEm: l['corrigidoEm'] as String?,
        actualizadoEm: l['actualizadoEm'] as String?,
      );

  final String id;
  final String compraId;
  final String mesId;
  final String produtoId;
  final String? itemListaId;
  double? quantidadePlaneada;
  double quantidade;
  String unidade;
  String? unidadeTexto;
  double? precoUnitarioPrevisto;
  int? precoPrevisto;
  int precoReal;
  double? precoUnitarioReal;
  String? registadoEm;
  String? corrigidoEm;
  String? actualizadoEm;

  Map<String, Object?> paraLinha() => {
        'id': id, 'compraId': compraId, 'mesId': mesId, 'produtoId': produtoId, 'itemListaId': itemListaId,
        'quantidadePlaneada': quantidadePlaneada, 'quantidade': quantidade, 'unidade': unidade,
        'unidadeTexto': unidadeTexto, 'precoUnitarioPrevisto': precoUnitarioPrevisto, 'precoPrevisto': precoPrevisto,
        'precoReal': precoReal, 'precoUnitarioReal': precoUnitarioReal, 'registadoEm': registadoEm,
        'corrigidoEm': corrigidoEm, 'actualizadoEm': actualizadoEm,
      };
}

class RegistoPreco {
  RegistoPreco({
    required this.id,
    required this.produtoId,
    required this.itemCompraId,
    required this.compraId,
    required this.mesId,
    required this.data,
    this.estabelecimento,
    required this.precoTotal,
    required this.quantidade,
    required this.unidade,
    this.unidadeTexto,
    required this.quantidadeBase,
    required this.unidadeBase,
    required this.precoUnitarioBase,
    this.registadoEm,
    this.corrigidoEm,
  });

  factory RegistoPreco.daLinha(Map<String, Object?> l) => RegistoPreco(
        id: l['id']! as String,
        produtoId: l['produtoId']! as String,
        itemCompraId: l['itemCompraId']! as String,
        compraId: l['compraId']! as String,
        mesId: l['mesId']! as String,
        data: l['data']! as String,
        estabelecimento: l['estabelecimento'] as String?,
        precoTotal: _inteiro(l['precoTotal'])!,
        quantidade: _real(l['quantidade'])!,
        unidade: l['unidade']! as String,
        unidadeTexto: l['unidadeTexto'] as String?,
        quantidadeBase: _real(l['quantidadeBase'])!,
        unidadeBase: l['unidadeBase']! as String,
        precoUnitarioBase: _real(l['precoUnitarioBase'])!,
        registadoEm: l['registadoEm'] as String?,
        corrigidoEm: l['corrigidoEm'] as String?,
      );

  final String id;
  final String produtoId;
  final String itemCompraId;
  final String compraId;
  final String mesId;
  final String data;
  final String? estabelecimento;
  final int precoTotal;
  final double quantidade;
  final String unidade;
  final String? unidadeTexto;
  final double quantidadeBase;
  final String unidadeBase;
  final double precoUnitarioBase;
  final String? registadoEm;
  final String? corrigidoEm;

  Map<String, Object?> paraLinha() => {
        'id': id, 'produtoId': produtoId, 'itemCompraId': itemCompraId, 'compraId': compraId, 'mesId': mesId,
        'data': data, 'estabelecimento': estabelecimento, 'precoTotal': precoTotal, 'quantidade': quantidade,
        'unidade': unidade, 'unidadeTexto': unidadeTexto, 'quantidadeBase': quantidadeBase,
        'unidadeBase': unidadeBase, 'precoUnitarioBase': precoUnitarioBase, 'registadoEm': registadoEm,
        'corrigidoEm': corrigidoEm,
      };
}
