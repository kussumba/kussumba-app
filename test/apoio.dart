// Apoio aos testes: base de dados em memória e relógio controlado.

import 'package:kussumba/dados/base_dados.dart';
import 'package:kussumba/nucleo/datas.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _iniciado = false;

/// Começa cada teste com uma base de dados nova, em memória, que nunca toca nos dados reais.
Future<void> baseDeDadosNova() async {
  if (!_iniciado) {
    sqfliteFfiInit();
    _iniciado = true;
  }
  await usarBaseDeDados(inMemoryDatabasePath, fabrica: databaseFactoryFfi);
}

void relogio(int ano, int mes, int dia) => definirRelogio(() => DateTime(ano, mes, dia, 10));

/// Espera que a operação falhe com uma mensagem que contenha o texto indicado.
Future<void> deveFalhar(Future<Object?> Function() operacao, String texto) async {
  try {
    await operacao();
  } catch (erro) {
    if (!erro.toString().contains(texto)) {
      throw StateError('falhou com "$erro", esperava conter "$texto"');
    }
    return;
  }
  throw StateError('esperava uma falha com "$texto", mas a operação foi aceite');
}

/// Espaço inseparável depois de um algarismo e sinal de menos, como a interface mostra.
String ui(String texto) => texto
    .replaceAllMapped(RegExp(r'(\d) '), (m) => '${m[1]} ')
    .replaceAllMapped(RegExp(r'(^|[^\w])-(?=\d)'), (m) => '${m[1]}−');
