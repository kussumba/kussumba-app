// Catálogo de produtos (prompt mestre, §10 a §12).

import '../dados/base_dados.dart';
import '../dados/catalogo_inicial.dart';
import '../dados/ids.dart';
import '../dados/modelos.dart';
import '../nucleo/datas.dart';
import '../nucleo/unidades.dart';
import 'comum.dart';
import 'precos.dart';

/// Catálogo ordenado: primeiro os produtos iniciais pela ordem do catálogo, depois os criados pelo utilizador.
List<Produto> ordenarCatalogo(Iterable<Produto> produtos) {
  final lista = [...produtos];
  lista.sort((a, b) {
    final oa = a.ordem ?? 1 << 30;
    final ob = b.ordem ?? 1 << 30;
    if (oa != ob) return oa.compareTo(ob);
    return a.nomeNormalizado.compareTo(b.nomeNormalizado);
  });
  return lista;
}

Future<List<Produto>> listarProdutos() async {
  final linhas = await transaccao((t) => todasAsLinhas(t, 'produtos'));
  return ordenarCatalogo(linhas.map(Produto.daLinha).where((p) => p.activo));
}

Future<Produto?> obterProduto(String id) async {
  final linha = await transaccao((t) => obterLinha(t, 'produtos', id));
  return linha == null ? null : Produto.daLinha(linha);
}

class DetalheProduto {
  const DetalheProduto(this.produto, this.preco);
  final Produto produto;
  final ResumoPreco? preco;
}

/// Produto e resumo do seu histórico de preços, para o cartão de produto (§11).
Future<DetalheProduto> detalheProduto(String produtoId) => transaccao((t) async {
      final linha = await obterLinha(t, 'produtos', produtoId);
      if (linha == null) throw const ErroKussumba('Este produto não existe.');
      return DetalheProduto(Produto.daLinha(linha), resumoPreco(await historicoDoProduto(t, produtoId)));
    });

/// Cria um produto personalizado. Não aceita dois produtos activos com o mesmo nome.
Future<Produto> criarProduto({
  required String? nome,
  required String categoria,
  required String unidade,
  String? unidadeTexto,
  num? quantidadeSugerida = 1,
}) async {
  final nomeLimpo = validarTexto(nome, 'Escreve o nome do produto.', 40);
  if (!categorias.any((c) => c.id == categoria)) throw const ErroKussumba('Escolhe uma categoria.');
  if (!unidadeValida(unidade)) throw const ErroKussumba('Escolhe uma unidade.');
  final texto = unidade == 'outro' ? validarTexto(unidadeTexto, 'Escreve o nome da unidade.', 20) : null;
  final quantidade = validarQuantidade(quantidadeSugerida);
  final normalizado = normalizarNome(nomeLimpo);

  return transaccao((t) async {
    final existentes = (await todasAsLinhas(t, 'produtos')).map(Produto.daLinha);
    if (existentes.any((p) => p.activo && p.nomeNormalizado == normalizado)) {
      throw const ErroKussumba('Já existe um produto com este nome no catálogo.');
    }
    final instante = carimbo();
    final produto = Produto(
      id: novoId(),
      nome: nomeLimpo,
      nomeNormalizado: normalizado,
      categoria: categoria,
      unidade: unidade,
      unidadeTexto: texto,
      quantidadeSugerida: quantidade,
      icone: 'generico',
      personalizado: true,
      criadoEm: instante,
      actualizadoEm: instante,
    );
    await guardarLinha(t, 'produtos', produto.paraLinha());
    return produto;
  });
}
