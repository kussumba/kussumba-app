// Catálogo inicial (prompt mestre, §10). Nenhum produto traz preço: os preços vêm sempre
// do que o utilizador indica ou paga, nunca de valores inventados.

class Categoria {
  const Categoria(this.id, this.nome);
  final String id;
  final String nome;
}

const List<Categoria> categorias = [
  Categoria('mercearia', 'Mercearia'),
  Categoria('frescos', 'Frescos'),
  Categoria('limpeza', 'Limpeza'),
  Categoria('higiene', 'Higiene'),
  Categoria('bebidas', 'Bebidas'),
  Categoria('outros', 'Outros'),
];

class ProdutoInicial {
  const ProdutoInicial(this.id, this.nome, this.categoria, this.unidade, this.quantidadeSugerida, this.icone,
      this.genero, [this.basico = false]);
  final String id;
  final String nome;
  final String categoria;
  final String unidade;
  final double quantidadeSugerida;
  final String icone;

  /// Artigo usado nas mensagens: "o preço do óleo", "o preço da fuba".
  final String genero;

  /// Entra em "Começar com produtos sugeridos" (§46).
  final bool basico;
}

const List<ProdutoInicial> produtosIniciais = [
  ProdutoInicial('cat-arroz', 'Arroz', 'mercearia', 'kg', 25, 'saco', 'o', true),
  ProdutoInicial('cat-oleo', 'Óleo alimentar', 'mercearia', 'L', 5, 'garrafa', 'o', true),
  ProdutoInicial('cat-acucar', 'Açúcar', 'mercearia', 'kg', 10, 'saco', 'o', true),
  ProdutoInicial('cat-feijao', 'Feijão', 'mercearia', 'kg', 5, 'saco', 'o', true),
  ProdutoInicial('cat-fuba', 'Fuba de milho', 'mercearia', 'kg', 10, 'saco', 'a', true),
  ProdutoInicial('cat-leite-po', 'Leite em pó', 'mercearia', 'lata', 2, 'lata', 'o', true),
  ProdutoInicial('cat-massa', 'Massa', 'mercearia', 'pacote', 4, 'caixa', 'a', true),
  ProdutoInicial('cat-sal', 'Sal', 'mercearia', 'kg', 1, 'saco', 'o'),
  ProdutoInicial('cat-farinha-trigo', 'Farinha de trigo', 'mercearia', 'kg', 2, 'saco', 'a'),
  ProdutoInicial('cat-ovos', 'Ovos', 'frescos', 'cartao', 1, 'ovos', 'os', true),
  ProdutoInicial('cat-frango', 'Frango', 'frescos', 'kg', 5, 'frango', 'o'),
  ProdutoInicial('cat-carne', 'Carne', 'frescos', 'kg', 2, 'carne', 'a'),
  ProdutoInicial('cat-peixe', 'Peixe', 'frescos', 'kg', 3, 'peixe', 'o'),
  ProdutoInicial('cat-tomate', 'Tomate', 'frescos', 'kg', 2, 'legume', 'o'),
  ProdutoInicial('cat-cebola', 'Cebola', 'frescos', 'kg', 2, 'legume', 'a'),
  ProdutoInicial('cat-batata', 'Batata', 'frescos', 'kg', 3, 'legume', 'a'),
  ProdutoInicial('cat-sabao-po', 'Sabão em pó', 'limpeza', 'kg', 3, 'saco', 'o', true),
  ProdutoInicial('cat-detergente', 'Detergente', 'limpeza', 'L', 1, 'garrafa', 'o'),
  ProdutoInicial('cat-lixivia', 'Lixívia', 'limpeza', 'L', 1, 'garrafa', 'a'),
  ProdutoInicial('cat-papel-higienico', 'Papel higiénico', 'higiene', 'pacote', 1, 'rolo', 'o', true),
  ProdutoInicial('cat-sabonete', 'Sabonete', 'higiene', 'unidade', 4, 'sabonete', 'o'),
  ProdutoInicial('cat-pasta-dentes', 'Pasta de dentes', 'higiene', 'unidade', 2, 'tubo', 'a'),
  ProdutoInicial('cat-agua', 'Água', 'bebidas', 'garrafa', 6, 'garrafa', 'a'),
  ProdutoInicial('cat-sumo', 'Sumo', 'bebidas', 'L', 2, 'garrafa', 'o'),
  ProdutoInicial('cat-refrigerante', 'Refrigerante', 'bebidas', 'lata', 6, 'lata', 'o'),
  ProdutoInicial('cat-gas', 'Gás de cozinha', 'outros', 'unidade', 1, 'botija', 'o'),
];

const Map<String, String> _semAcento = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// Nome sem acentos e em minúsculas, para a pesquisa encontrar "acucar" ao escrever "açúcar".
String normalizarNome(String? nome) {
  final minusculas = (nome ?? '').toLowerCase();
  final semAcento = minusculas.split('').map((c) => _semAcento[c] ?? c).join();
  return semAcento.trim().replaceAll(RegExp(r'\s+'), ' ');
}
