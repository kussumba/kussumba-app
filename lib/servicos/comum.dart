// Erros e validações partilhados pelos serviços.

import '../dados/modelos.dart';
import '../nucleo/formatos.dart';

/// Erro com uma mensagem pronta a mostrar ao utilizador.
class ErroKussumba implements Exception {
  const ErroKussumba(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

const int maximoKz = 100000000000;

/// Valor em Kz: inteiro, maior do que zero.
int validarKz(int? valor, String mensagem) {
  if (valor == null || valor <= 0 || valor > maximoKz) throw ErroKussumba(mensagem);
  return valor;
}

double validarQuantidade(num? valor) {
  if (valor == null || !valor.isFinite || valor <= 0 || valor > 1000000) {
    throw const ErroKussumba('Indica uma quantidade maior do que zero.');
  }
  return arredondar(valor * 1000) / 1000;
}

String validarTexto(String? valor, String mensagemVazio, [int maximo = 60]) {
  final texto = (valor ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (texto.isEmpty) throw ErroKussumba(mensagemVazio);
  if (texto.length > maximo) throw ErroKussumba('Usa no máximo $maximo caracteres.');
  return texto;
}

Mes exigirMesAberto(Mes? mes) {
  if (mes == null) throw const ErroKussumba('Este mês não existe.');
  if (mes.estado == 'fechado') throw const ErroKussumba('Este mês já está fechado e não pode ser alterado.');
  return mes;
}
