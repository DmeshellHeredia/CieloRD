/// Normalización de texto para búsqueda: minúsculas, sin acentos ni diéresis,
/// espacios colapsados. Se aplica igual al guardar (`search_text`,
/// `place_search`) y al consultar, porque SQLite de Android no pliega acentos.
abstract final class SearchNormalizer {
  static const Map<String, String> _fold = <String, String>{
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', //
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c',
  };

  static String normalize(String text) {
    final StringBuffer out = StringBuffer();
    for (final int rune in text.toLowerCase().runes) {
      final String ch = String.fromCharCode(rune);
      out.write(_fold[ch] ?? ch);
    }
    return out.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Palabras de la consulta; cada una debe aparecer (AND).
  static List<String> tokens(String query) {
    final String n = normalize(query);
    return n.isEmpty ? const <String>[] : n.split(' ');
  }

  /// Texto indexado de una observación: título, descripción y lugar.
  static String document({required String title, String? description, String? place}) =>
      normalize(<String>[title, description ?? '', place ?? ''].join(' '));
}
