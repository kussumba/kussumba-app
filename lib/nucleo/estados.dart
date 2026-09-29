// Estados da aplicação (prompt mestre, §47), calculados sempre da mesma maneira.

/// Mês: "aberto" (sem compras), "em_andamento" (com compras) ou "fechado".
String estadoDoMes(String estadoGuardado, int numeroCompras) {
  if (estadoGuardado == 'fechado') return 'fechado';
  return numeroCompras > 0 ? 'em_andamento' : 'aberto';
}

/// Lista: "vazia", "criada" (nada comprado), "parcial" ou "comprada".
String estadoDaLista({required int artigos, required int comprados}) {
  if (artigos == 0) return 'vazia';
  if (comprados == 0) return 'criada';
  return comprados < artigos ? 'parcial' : 'comprada';
}

const Map<String, Map<String, String>> rotulos = {
  'mes': {'aberto': 'Mês aberto', 'em_andamento': 'Mês em andamento', 'fechado': 'Mês fechado'},
  'lista': {'vazia': 'Vazia', 'criada': 'Por comprar', 'parcial': 'Parcialmente comprada', 'comprada': 'Toda comprada'},
  'compra': {'em_andamento': 'Compra em andamento', 'concluida': 'Compra concluída'},
};
