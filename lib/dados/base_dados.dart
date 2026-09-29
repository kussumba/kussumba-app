// Persistência local em SQLite. Só esta camada conhece a base de dados;
// os serviços de negócio usam apenas transaccao() e as funções de leitura e escrita abaixo.
//
// Tabelas (prompt mestre, §31):
//   utilizador        registo único "eu": moeda e data da última cópia de segurança
//   meses             um registo por mês ("2026-09"): plafond, estado, datas, resumo congelado no fecho
//   produtos          catálogo local, incluindo os produtos criados pelo utilizador
//   itens_lista       lista de compras de cada mês (o PREVISTO)
//   compras           cada ida às compras (o REALIZADO)
//   itens_compra      artigos registados em cada compra, com o preço efectivamente pago
//   historico_precos  um registo por artigo comprado; nunca é substituído em silêncio

import 'package:path/path.dart' as caminhos;
import 'package:sqflite/sqflite.dart';

import '../nucleo/datas.dart';
import 'catalogo_inicial.dart';

/// Tabelas pela ordem em que se exportam e repõem.
const List<String> tabelas = [
  'utilizador', 'meses', 'produtos', 'itens_lista', 'compras', 'itens_compra', 'historico_precos',
];

// Cada migração corre uma única vez, pela ordem. Para mudar a estrutura, acrescenta-se
// uma migração nova no fim; as antigas nunca se alteram.
// O sqflite já corre a criação e as actualizações dentro de uma transacção.
final List<Future<void> Function(DatabaseExecutor)> _migracoes = [_versao1];

Future<void> _versao1(DatabaseExecutor t) async {
  await t.execute('''
    CREATE TABLE utilizador (
      id TEXT PRIMARY KEY, nome TEXT, moeda TEXT NOT NULL, ultimaCopiaEm TEXT,
      criadoEm TEXT, actualizadoEm TEXT)''');
  await t.execute('''
    CREATE TABLE meses (
      id TEXT PRIMARY KEY, ano INTEGER NOT NULL, mes INTEGER NOT NULL, plafond INTEGER NOT NULL,
      estado TEXT NOT NULL CHECK (estado IN ('aberto', 'fechado')), listaCopiadaDe TEXT,
      criadoEm TEXT, fechadoEm TEXT, resumoFecho TEXT, actualizadoEm TEXT)''');
  await t.execute('CREATE INDEX meses_estado ON meses (estado)');
  await t.execute('''
    CREATE TABLE produtos (
      id TEXT PRIMARY KEY, nome TEXT NOT NULL, nomeNormalizado TEXT NOT NULL, categoria TEXT NOT NULL,
      unidade TEXT NOT NULL, unidadeTexto TEXT, quantidadeSugerida REAL NOT NULL, icone TEXT, genero TEXT,
      basico INTEGER NOT NULL DEFAULT 0, activo INTEGER NOT NULL DEFAULT 1, personalizado INTEGER NOT NULL DEFAULT 0,
      ordem INTEGER, criadoEm TEXT, actualizadoEm TEXT)''');
  await t.execute('''
    CREATE TABLE itens_lista (
      id TEXT PRIMARY KEY, mesId TEXT NOT NULL REFERENCES meses (id), produtoId TEXT NOT NULL REFERENCES produtos (id),
      unidade TEXT NOT NULL, unidadeTexto TEXT, quantidadePrevista REAL NOT NULL, precoUnitarioPrevisto REAL,
      comprado INTEGER NOT NULL DEFAULT 0, compraId TEXT, ordem INTEGER NOT NULL, criadoEm TEXT, actualizadoEm TEXT)''');
  await t.execute('CREATE INDEX itens_lista_mes ON itens_lista (mesId)');
  await t.execute('CREATE INDEX itens_lista_produto ON itens_lista (produtoId)');
  await t.execute('''
    CREATE TABLE compras (
      id TEXT PRIMARY KEY, mesId TEXT NOT NULL REFERENCES meses (id), estabelecimento TEXT NOT NULL, data TEXT NOT NULL,
      estado TEXT NOT NULL CHECK (estado IN ('em_andamento', 'concluida')), origem TEXT,
      totalPrevisto INTEGER, totalReal INTEGER, diferenca INTEGER, artigos INTEGER,
      criadoEm TEXT, concluidaEm TEXT, actualizadoEm TEXT)''');
  await t.execute('CREATE INDEX compras_mes ON compras (mesId)');
  await t.execute('''
    CREATE TABLE itens_compra (
      id TEXT PRIMARY KEY, compraId TEXT NOT NULL REFERENCES compras (id), mesId TEXT NOT NULL,
      produtoId TEXT NOT NULL REFERENCES produtos (id), itemListaId TEXT, quantidadePlaneada REAL,
      quantidade REAL NOT NULL, unidade TEXT NOT NULL, unidadeTexto TEXT, precoUnitarioPrevisto REAL,
      precoPrevisto INTEGER, precoReal INTEGER NOT NULL, precoUnitarioReal REAL,
      registadoEm TEXT, corrigidoEm TEXT, actualizadoEm TEXT)''');
  await t.execute('CREATE INDEX itens_compra_compra ON itens_compra (compraId)');
  await t.execute('CREATE INDEX itens_compra_mes ON itens_compra (mesId)');
  await t.execute('''
    CREATE TABLE historico_precos (
      id TEXT PRIMARY KEY, produtoId TEXT NOT NULL REFERENCES produtos (id), itemCompraId TEXT NOT NULL UNIQUE,
      compraId TEXT NOT NULL, mesId TEXT NOT NULL, data TEXT NOT NULL, estabelecimento TEXT,
      precoTotal INTEGER NOT NULL, quantidade REAL NOT NULL, unidade TEXT NOT NULL, unidadeTexto TEXT,
      quantidadeBase REAL NOT NULL, unidadeBase TEXT NOT NULL, precoUnitarioBase REAL NOT NULL,
      registadoEm TEXT, corrigidoEm TEXT)''');
  await t.execute('CREATE INDEX historico_produto ON historico_precos (produtoId)');

  final instante = carimbo();
  for (var i = 0; i < produtosIniciais.length; i++) {
    final p = produtosIniciais[i];
    await t.insert('produtos', {
      'id': p.id, 'nome': p.nome, 'nomeNormalizado': normalizarNome(p.nome), 'categoria': p.categoria,
      'unidade': p.unidade, 'unidadeTexto': null, 'quantidadeSugerida': p.quantidadeSugerida, 'icone': p.icone,
      'genero': p.genero, 'basico': p.basico ? 1 : 0, 'activo': 1, 'personalizado': 0, 'ordem': i,
      'criadoEm': instante, 'actualizadoEm': instante,
    });
  }
}

int get versaoBd => _migracoes.length;

/// Erro de armazenamento: a base de dados não abriu ou o telefone está sem espaço.
class ErroArmazenamento implements Exception {
  const ErroArmazenamento(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

String? _caminhoActivo;
Database? _ligacao;
DatabaseFactory? _fabrica;

/// Os testes usam uma base de dados em memória, para nunca tocarem nos dados reais.
Future<void> usarBaseDeDados(String caminho, {DatabaseFactory? fabrica}) async {
  await fecharBaseDeDados();
  _caminhoActivo = caminho;
  _fabrica = fabrica;
}

Future<void> fecharBaseDeDados() async {
  final ligacao = _ligacao;
  _ligacao = null;
  if (ligacao != null && ligacao.isOpen) await ligacao.close();
}

Future<Database> _abrir() async {
  final aberta = _ligacao;
  if (aberta != null && aberta.isOpen) return aberta;
  final fabrica = _fabrica ?? databaseFactory;
  final caminho = _caminhoActivo ?? caminhos.join(await fabrica.getDatabasesPath(), 'kussumba.db');
  final ligacao = await fabrica.openDatabase(
    caminho,
    options: OpenDatabaseOptions(
      version: versaoBd,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, versao) async {
        for (var v = 0; v < versao; v++) {
          await _migracoes[v](db);
        }
      },
      onUpgrade: (db, antiga, nova) async {
        for (var v = antiga; v < nova; v++) {
          await _migracoes[v](db);
        }
      },
    ),
  );
  _ligacao = ligacao;
  return ligacao;
}

/// Executa um trabalho numa única transacção. Ou tudo fica gravado, ou nada fica:
/// se o trabalho lançar um erro, a transacção é anulada e os dados ficam como estavam.
Future<T> transaccao<T>(Future<T> Function(Transaction t) trabalho) async {
  final Database bd;
  try {
    bd = await _abrir();
  } on DatabaseException catch (erro) {
    throw ErroArmazenamento(erro.isOpenFailedError()
        ? 'Não foi possível abrir os dados da KUSSUMBA neste telefone.'
        : 'Não foi possível guardar os dados da KUSSUMBA neste telefone.');
  }
  return bd.transaction(trabalho);
}

// ---------- Leituras e escritas usadas pelos serviços ----------

Future<Map<String, Object?>?> obterLinha(DatabaseExecutor t, String tabela, String id) async {
  final linhas = await t.query(tabela, where: 'id = ?', whereArgs: [id], limit: 1);
  return linhas.isEmpty ? null : linhas.first;
}

Future<List<Map<String, Object?>>> linhasOnde(DatabaseExecutor t, String tabela, String campo, Object? valor) =>
    t.query(tabela, where: '$campo = ?', whereArgs: [valor]);

Future<List<Map<String, Object?>>> todasAsLinhas(DatabaseExecutor t, String tabela) => t.query(tabela);

/// Grava um registo: actualiza o que tiver o mesmo identificador ou, se não existir, insere-o.
/// (O "substituir" do SQLite apagaria primeiro a linha e falharia nas chaves estrangeiras.)
Future<void> guardarLinha(DatabaseExecutor t, String tabela, Map<String, Object?> linha) async {
  final alteradas = await t.update(tabela, linha, where: 'id = ?', whereArgs: [linha['id']]);
  if (alteradas == 0) await t.insert(tabela, linha);
}

Future<void> apagarLinha(DatabaseExecutor t, String tabela, String id) =>
    t.delete(tabela, where: 'id = ?', whereArgs: [id]);

Future<void> limparTabela(DatabaseExecutor t, String tabela) => t.delete(tabela);
