// Unidades de medida e conversão para a unidade de base.
// Dois preços só se comparam quando têm a mesma unidade de base (g e kg sim; kg e pacote não).

import 'formatos.dart';

class Unidade {
  const Unidade(this.id, this.singular, this.plural, this.base, this.factor, this.passo, this.decimal);

  final String id;
  final String singular;
  final String plural;
  final String base;
  final double factor;
  final double passo;
  final bool decimal;
}

const List<Unidade> unidades = [
  Unidade('kg', 'kg', 'kg', 'kg', 1, 1, true),
  Unidade('g', 'g', 'g', 'kg', 0.001, 100, false),
  Unidade('L', 'L', 'L', 'L', 1, 1, true),
  Unidade('ml', 'ml', 'ml', 'L', 0.001, 100, false),
  Unidade('unidade', 'unidade', 'unidades', 'unidade', 1, 1, false),
  Unidade('pacote', 'pacote', 'pacotes', 'pacote', 1, 1, false),
  Unidade('caixa', 'caixa', 'caixas', 'caixa', 1, 1, false),
  Unidade('cartao', 'cartão', 'cartões', 'cartao', 1, 1, false),
  Unidade('saco', 'saco', 'sacos', 'saco', 1, 1, false),
  Unidade('lata', 'lata', 'latas', 'lata', 1, 1, false),
  Unidade('garrafa', 'garrafa', 'garrafas', 'garrafa', 1, 1, false),
  Unidade('outro', 'outro', 'outros', 'outro', 1, 1, true),
];

final Map<String, Unidade> _porId = {for (final u in unidades) u.id: u};

// Rótulo curto usado em "Kz/kg", "Kz/un.".
const Map<String, String> _rotuloPorUnidade = {'unidade': 'un.', 'cartao': 'cartão'};

Unidade unidade(String id) {
  final u = _porId[id];
  if (u == null) throw ArgumentError('Unidade desconhecida: $id');
  return u;
}

bool unidadeValida(Object? id) => id is String && _porId.containsKey(id);

/// Unidade de base usada para comparar preços.
/// Para "outro", o texto livre escolhido pelo utilizador faz parte da base,
/// para que "molho" e "kit" nunca se comparem entre si.
String unidadeBase(String id, [String? texto]) {
  final u = unidade(id);
  if (u.id == 'outro') return 'outro:${(texto ?? '').trim().toLowerCase()}';
  return u.base;
}

/// Converte uma quantidade para a unidade de base: 500 g → 0,5 kg.
double paraBase(num quantidade, String id) => quantidade * unidade(id).factor;

bool saoComparaveis(String a, String b) => a == b;

/// Nome da unidade de acordo com a quantidade: "1 lata", "2 latas", "25 kg".
String rotuloUnidade(String id, num quantidade, [String? texto]) {
  final u = unidade(id);
  if (u.id == 'outro' && texto != null && texto.isNotEmpty) return texto;
  return quantidade == 1 ? u.singular : u.plural;
}

/// "25 kg", "2,5 kg", "3 pacotes".
String formatarQuantidade(num quantidade, String id, [String? texto]) =>
    '${formatarNumero(quantidade, 3)}$espaco${rotuloUnidade(id, quantidade, texto)}';

/// Rótulo para preço por unidade de base: "kg", "L", "un.", "pacote".
String rotuloPorUnidade(String base) {
  if (base.startsWith('outro:')) return base.length > 6 ? base.substring(6) : 'un.';
  return _rotuloPorUnidade[base] ?? base;
}

/// "1 280 Kz/kg". Valores abaixo de 10 Kz mostram casas decimais para não aparecerem como zero.
String formatarPrecoUnitario(num? valor, String base) {
  if (valor == null || !valor.isFinite) return '';
  final casas = valor.abs() < 10 ? 2 : 0;
  return '${formatarNumero(valor, casas)}${espaco}Kz/${rotuloPorUnidade(base)}';
}

/// Próxima quantidade ao carregar em "+" ou "−". Nunca desce a zero.
double passoQuantidade(num quantidade, String id, int direccao) {
  final passo = unidade(id).passo;
  final nova = arredondar((quantidade + direccao * passo) * 1000) / 1000;
  if (nova <= 0) return quantidade.toDouble();
  return nova;
}

bool aceitaDecimais(String id) => unidade(id).decimal;
