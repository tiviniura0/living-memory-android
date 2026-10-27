import 'dart:convert';

/// Model output is an unverified proposal. No model-controlled status exists.
class AutoMemoryCandidate {
  const AutoMemoryCandidate({
    required this.quote,
    required this.kind,
    required this.subject,
    required this.relation,
    required this.value,
    required this.uncertain,
  });
  final String quote;
  final String kind;
  final String subject;
  final String relation;
  final String value;
  final bool uncertain;

  void validate(String passage) {
    if (quote.trim().isEmpty || utf8.encode(quote).length > 700 ||
        !passage.contains(quote) ||
        !const ['observation', 'inference'].contains(kind) ||
        [subject, relation, value].any((s) => s.length > 100)) {
      throw const FormatException('Candidat non conforme ou citation absente de la source.');
    }
  }

  static List<AutoMemoryCandidate> parse(String output, String passage) {
    if (utf8.encode(output).length > 6000) {
      throw const FormatException('Sortie du modèle trop longue.');
    }
    final Object? decoded = jsonDecode(output);
    if (decoded is! List || decoded.length > 3) {
      throw const FormatException('Tableau JSON de 0 à 3 souvenirs attendu.');
    }
    final candidates = <AutoMemoryCandidate>[];
    for (final Object? item in decoded) {
      if (item is! Map<String, dynamic> || item.length != 6) {
        // Key validation below rejects unknown fields, including a proposed status.
        throw const FormatException('Objet candidat attendu.');
      }
      if (!item.keys.every(const ['quote','kind','subject','relation','value','uncertain'].contains) ||
          item['quote'] is! String || item['kind'] is! String ||
          item['subject'] is! String || item['relation'] is! String ||
          item['value'] is! String || item['uncertain'] is! bool) {
        throw const FormatException('Champs candidats invalides.');
      }
      final c = AutoMemoryCandidate(
        quote: item['quote'] as String, kind: item['kind'] as String,
        subject: item['subject'] as String, relation: item['relation'] as String,
        value: item['value'] as String, uncertain: item['uncertain'] as bool,
      );
      c.validate(passage);
      candidates.add(c);
    }
    return candidates;
  }
}
