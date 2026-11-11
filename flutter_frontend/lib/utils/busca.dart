// Busca do Bloco 7 (decks e cards). A filtragem é feita no próprio app,
// em cima da lista que já foi carregada — não precisa de rota nova no backend.

const _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
const _semAcento = 'aaaaaeeeeiiiiooooouuuucn';

// "Matemática" -> "matematica", pra "matematica" e "MATEMÁTICA" acharem igual.
String normalizar(String texto) {
  final minusculo = texto.toLowerCase();
  final saida = StringBuffer();
  for (final letra in minusculo.split('')) {
    final i = _comAcento.indexOf(letra);
    saida.write(i >= 0 ? _semAcento[i] : letra);
  }
  return saida.toString();
}

// true se algum dos textos contém o termo buscado (busca vazia = tudo).
bool combinaBusca(String termo, List<String> textos) {
  final t = normalizar(termo.trim());
  if (t.isEmpty) return true;
  return textos.any((texto) => normalizar(texto).contains(t));
}
