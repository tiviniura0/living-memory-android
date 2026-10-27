import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/context_lifecycle_manager.dart';
import 'package:litert_edge_demos/living_memory/memory_store.dart';
import 'package:litert_edge_demos/living_memory/module_contracts.dart';
import 'package:litert_edge_demos/living_memory/reliability_engine.dart';

void main() {
  test('only explicitly marked user decisions in this scope join RAG', () {
    final dir = Directory.systemTemp.createTempSync('session-rag-');
    final store = MemoryStore.open('${dir.path}/m.db',profile: 'test',dimension: 2);
    store.createAgent('aru','Aru');
    final manager = ContextLifecycleManager(store,const MemoryScope(agentId: 'aru'));
    final id = manager.startSession();
    manager.append(id,'user','Question zirconium ?');
    manager.append(id,'assistant','zirconium inventé');
    final engine = ReliabilityEngine(store);
    expect(engine.retrieve('aru','zirconium',[1,0]),isEmpty);
    manager.append(id,'user','Décision : conserver le zirconium.',decision: true);
    final hit = engine.retrieve('aru','zirconium',[1,0]).single;
    expect(hit.name,contains('Décision utilisateur'));
    expect(hit.text,contains('sans vérification'));
    expect(engine.retrieve('aru','zirconium',[1,0],projectId: 'other'),isEmpty);
    manager.markDecision(id,3,decision: false);
    expect(engine.retrieve('aru','zirconium',[1,0]),isEmpty);
    store.close();dir.deleteSync(recursive: true);
  });
}
