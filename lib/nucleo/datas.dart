// Datas e meses. As datas guardam-se como texto "AAAA-MM-DD" na hora local,
// para que uma compra feita às 23h30 em Luanda não mude de dia.

const List<String> _meses = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];
const List<String> _mesesCurtos = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

DateTime Function() _fonteDoTempo = DateTime.now;

/// Data e hora actuais. Os testes podem substituir o relógio com definirRelogio.
DateTime agora() => _fonteDoTempo();

void definirRelogio(DateTime Function()? funcao) {
  _fonteDoTempo = funcao ?? DateTime.now;
}

String carimbo() => agora().toUtc().toIso8601String();

String _doisDigitos(int n) => n.toString().padLeft(2, '0');

String dataIso([DateTime? data]) {
  final d = data ?? agora();
  return '${d.year.toString().padLeft(4, '0')}-${_doisDigitos(d.month)}-${_doisDigitos(d.day)}';
}

bool dataValida(Object? texto) {
  if (texto is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(texto)) return false;
  final partes = texto.split('-').map(int.parse).toList();
  final d = DateTime(partes[0], partes[1], partes[2]);
  return d.year == partes[0] && d.month == partes[1] && d.day == partes[2];
}

class AnoMes {
  const AnoMes(this.ano, this.mes);
  final int ano;
  final int mes;

  @override
  bool operator ==(Object other) => other is AnoMes && other.ano == ano && other.mes == mes;

  @override
  int get hashCode => Object.hash(ano, mes);

  @override
  String toString() => idMes(ano, mes);
}

String idMes(int ano, int mes) => '$ano-${_doisDigitos(mes)}';

AnoMes partesIdMes(String id) {
  final p = id.split('-').map(int.parse).toList();
  return AnoMes(p[0], p[1]);
}

String nomeMes(int mes) => _meses[mes - 1];

String rotuloMes(int ano, int mes) => '${nomeMes(mes)} $ano';

int diasNoMes(int ano, int mes) => DateTime(ano, mes + 1, 0).day;

int _indice(AnoMes m) => m.ano * 12 + (m.mes - 1);

/// Negativo se a vier antes de b, zero se for o mesmo mês.
int compararMeses(AnoMes a, AnoMes b) => _indice(a) - _indice(b);

AnoMes mesSeguinte(AnoMes m) => m.mes == 12 ? AnoMes(m.ano + 1, 1) : AnoMes(m.ano, m.mes + 1);

AnoMes mesAnterior(AnoMes m) => m.mes == 1 ? AnoMes(m.ano - 1, 12) : AnoMes(m.ano, m.mes - 1);

AnoMes mesDaData([DateTime? data]) {
  final d = data ?? agora();
  return AnoMes(d.year, d.month);
}

/// Dias decorridos do mês, contando o dia de hoje. Mês futuro: 0. Mês já terminado: todos.
int diasDecorridos(int ano, int mes, [DateTime? hoje]) {
  final h = hoje ?? agora();
  final comparacao = compararMeses(mesDaData(h), AnoMes(ano, mes));
  if (comparacao < 0) return 0;
  if (comparacao > 0) return diasNoMes(ano, mes);
  return h.day;
}

int diasRestantes(int ano, int mes, [DateTime? hoje]) => diasNoMes(ano, mes) - diasDecorridos(ano, mes, hoje);

/// "2026-09-02" → "02 Set".
String formatarDataCurta(String iso) {
  final p = iso.split('-');
  return '${p[2]} ${_mesesCurtos[int.parse(p[1]) - 1]}';
}

/// "2026-09-02" → "2 de Setembro de 2026".
String formatarDataLonga(String iso) {
  final p = iso.split('-').map(int.parse).toList();
  return '${p[2]} de ${_meses[p[1] - 1]} de ${p[0]}';
}
