import '../../../core/text/search_normalizer.dart';
import '../domain/observation_filter.dart';

/// Traduce [ObservationFilter] a SQL parametrizado. Lo comparten el Diario y
/// las estadísticas para que cuenten exactamente lo mismo.
final class ObservationFilterSql {
  const ObservationFilterSql(this.clauses, this.args);
  final List<String> clauses;
  final List<Object?> args;

  factory ObservationFilterSql.from(ObservationFilter f) {
    final List<String> clauses = [];
    final List<Object?> args = [];
    if (f.status != null) {
      clauses.add('status = ?');
      args.add(f.status!.name);
    }
    if (f.category != null) {
      clauses.add('category_code = ?');
      args.add(f.category!.name);
    }
    if (f.from != null) {
      clauses.add('observed_at_utc_ms >= ?');
      args.add(f.from!.millisecondsSinceEpoch);
    }
    if (f.until != null) {
      clauses.add('observed_at_utc_ms < ?');
      args.add(f.until!.millisecondsSinceEpoch);
    }
    final String place = SearchNormalizer.normalize(f.place);
    if (place.isNotEmpty) {
      clauses.add(r"place_search LIKE ? ESCAPE '\'");
      args.add('%${_escapeLike(place)}%');
    }
    for (final String token in SearchNormalizer.tokens(f.query)) {
      clauses.add(r"search_text LIKE ? ESCAPE '\'");
      args.add('%${_escapeLike(token)}%');
    }
    return ObservationFilterSql(clauses, args);
  }

  String get sql => whereSql(clauses);

  /// Este filtro más una condición adicional sin parámetros.
  String sqlAnd(String clause) => whereSql([...clauses, clause]);

  static String whereSql(List<String> clauses) =>
      clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';

  static String _escapeLike(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}
