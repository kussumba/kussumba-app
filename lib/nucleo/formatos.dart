// Formatação e leitura de valores para a interface.
// Os valores em Kz são sempre inteiros. As quantidades podem ter casas decimais.

import 'dart:math' as math;

/// Espaço inseparável: separa milhares e antecede "Kz".
const String espaco = ' ';

/// Sinal de menos tipográfico.
const String menos = '−';

final RegExp _milhares = RegExp(r'\B(?=(\d{3})+(?!\d))');

/// Arredonda como a versão web (meio para cima): 2,5 → 3 e −2,5 → −2.
int arredondar(num valor) => (valor + 0.5).floor();

String _agruparMilhares(String digitos) => digitos.replaceAll(_milhares, espaco);

bool _valido(num? valor) => valor != null && valor.isFinite;

/// 1280 → "1 280"; 2.5 → "2,5". Retira os zeros finais das casas decimais.
String formatarNumero(num? valor, [int casasMax = 0]) {
  if (!_valido(valor)) return '';
  final v = valor!;
  final factor = math.pow(10, casasMax);
  final absoluto = arredondar(v.abs() * factor) / factor;
  final partes = absoluto.toStringAsFixed(casasMax).split('.');
  final inteira = partes[0];
  final decimal = partes.length > 1 ? partes[1].replaceFirst(RegExp(r'0+$'), '') : '';
  final negativo = v < 0 && absoluto != 0;
  return '${negativo ? menos : ''}${_agruparMilhares(inteira)}${decimal.isNotEmpty ? ',$decimal' : ''}';
}

/// 250000 → "250 000 Kz".
String formatarKz(num? valor) {
  if (!_valido(valor)) return '';
  return '${formatarNumero(arredondar(valor!))}${espaco}Kz';
}

/// 500 → "+500 Kz"; -500 → "−500 Kz"; 0 → "0 Kz".
String formatarKzComSinal(num? valor) {
  if (!_valido(valor)) return '';
  final arredondado = arredondar(valor!);
  return '${arredondado > 0 ? '+' : ''}${formatarKz(arredondado)}';
}

/// Percentagem com uma casa decimal no máximo: 6.666 → "6,7%".
/// Com sinal: "+6,7%", "−8,3%", e "0%" quando não há variação.
String formatarPercentagem(num? valor, {bool sinal = false, int casas = 1}) {
  if (!_valido(valor)) return '';
  final v = valor!;
  final texto = formatarNumero(v.abs(), casas);
  final arredondado = double.parse(v.abs().toStringAsFixed(casas));
  if (arredondado == 0) return '0%';
  if (sinal) return '${v > 0 ? '+' : menos}$texto%';
  return '${v < 0 ? menos : ''}$texto%';
}

/// Lê um valor em Kz escrito pelo utilizador ("250 000", "250000") e devolve um inteiro ou null.
int? lerKz(String? texto) {
  final digitos = (texto ?? '').replaceAll(RegExp(r'\D'), '');
  if (digitos.isEmpty || digitos.length > 15) return null;
  return int.tryParse(digitos);
}

/// Lê uma quantidade ("2,5", "2.5", "10") e devolve um número ou null.
double? lerDecimal(String? texto) {
  final limpo = (texto ?? '').replaceAll(RegExp(r'[\s ]'), '').replaceFirst(',', '.');
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(limpo)) return null;
  return double.tryParse(limpo);
}

/// Formata os dígitos enquanto o utilizador escreve: "250000" → "250 000".
String formatarDigitacaoKz(String? texto, [int maxDigitos = 12]) {
  var digitos = (texto ?? '').replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (digitos.length > maxDigitos) digitos = digitos.substring(0, maxDigitos);
  return _agruparMilhares(digitos);
}
