// Guardar e repor a cópia de segurança a partir da interface (versão web: js/ui/copia.js).
// No telefone, a cópia guarda-se onde o utilizador escolher: pasta de transferências, Google Drive, etc.

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

import '../nucleo/datas.dart';
import '../nucleo/formatos.dart';
import '../servicos/comum.dart';
import '../servicos/copia.dart';
import 'avisos.dart';

/// Pede ao telefone um sítio para guardar a cópia. Devolve true se ficou guardada.
Future<bool> guardarCopia() async {
  final texto = await exportarCopia();
  final guardada = await FilePicker.saveFile(
    fileName: 'kussumba-copia-${dataIso()}.json',
    bytes: Uint8List.fromList(utf8.encode(texto)),
    mimeType: 'application/json',
  );
  if (guardada == null) return false;
  await registarCopiaFeita();
  return true;
}

String _quantos(int n, String singular, String plural) => '${formatarNumero(n)} ${n == 1 ? singular : plural}';

/// Lê o ficheiro escolhido, mostra o que contém e, se o utilizador confirmar, repõe-no.
/// Com substituir, avisa que os dados actuais deste telefone vão ser substituídos.
/// Devolve true se a cópia foi reposta.
Future<bool> reporDeFicheiro(BuildContext context, {required bool substituir}) async {
  final ficheiro = await FilePicker.pickFile();
  if (ficheiro == null) return false;
  final tamanho = ficheiro.lengthSync() ?? await ficheiro.length();
  if (tamanho != null && tamanho > tamanhoMaximo) {
    throw const ErroKussumba('O ficheiro é demasiado grande para ser uma cópia da KUSSUMBA.');
  }
  final String texto;
  try {
    texto = utf8.decode(await ficheiro.readAsBytes());
  } on FormatException {
    throw const ErroKussumba('Este ficheiro não é uma cópia da KUSSUMBA.');
  }
  final copia = lerCopia(texto);
  final resumo = copia.resumo;
  final criadaEm = resumo.criadaEm;
  final quando =
      criadaEm != null && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(criadaEm) ? ' de ${formatarDataLonga(criadaEm.substring(0, 10))}' : '';
  final conteudo = 'Tem ${_quantos(resumo.meses, 'mês', 'meses')}, ${_quantos(resumo.compras, 'compra', 'compras')} '
      'e ${_quantos(resumo.artigosComprados, 'artigo comprado', 'artigos comprados')}.';
  if (!context.mounted) return false;
  final ok = await confirmar(
    context,
    titulo: 'Repor a cópia$quando?',
    texto: substituir ? '$conteudo Todos os dados que estão agora neste telefone são substituídos pelos da cópia.' : conteudo,
    confirmar: 'Repor cópia',
    cancelar: 'Cancelar',
    perigo: substituir,
  );
  if (!ok) return false;
  await reporCopia(copia);
  return true;
}
