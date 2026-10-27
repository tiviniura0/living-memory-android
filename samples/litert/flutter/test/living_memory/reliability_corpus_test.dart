import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/memory_store.dart';
import 'package:litert_edge_demos/living_memory/reliability_engine.dart';

void main() {
  final corpus = jsonDecode(
    File('test/living_memory/fixtures/reliability_cases.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final entry in corpus['cases'] as List<dynamic>) {
    final data = entry as Map<String, dynamic>;
    test('reference corpus: ${data['name']}', () {
      final dir = Directory.systemTemp.createTempSync('corpus-');
      final store = MemoryStore.open(
        '${dir.path}/m.db',
        profile: 'test',
        dimension: 2,
      );
      final evidence = <MemoryHit>[
        for (final source in data['sources'] as List<dynamic>)
          MemoryHit(
            agentId: 'synthetic',
            documentId: 'd',
            name: 'corpus',
            page: 1,
            ordinal: 1,
            text: source as String,
            similarity: 1,
          ),
      ];
      expect(
        ReliabilityEngine(store)
            .validateAnswer(data['answer'] as String, evidence)
            .accepted,
        data['accepted'],
      );
      store.close();
      dir.deleteSync(recursive: true);
    });
  }
}
