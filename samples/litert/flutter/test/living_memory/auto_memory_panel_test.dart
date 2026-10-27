import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/auto_memory_candidate.dart';
import 'package:litert_edge_demos/living_memory/auto_memory_panel.dart';
import 'package:litert_edge_demos/living_memory/memory_store.dart';

void main() {
  testWidgets('mobile panel exposes opt-in, provenance and review actions', (tester) async {
    final dir=Directory.systemTemp.createTempSync('auto-panel-');
    final store=MemoryStore.open('${dir.path}/t.db',profile:'test',dimension:2);
    addTearDown(() {store.close();dir.deleteSync(recursive:true);});
    store.createAgent('aru','Aru');
    final doc=store.addDocument(agentId:'aru',name:'Ma note',digest:'t',
      chunks:[const MemoryChunk(page:1,ordinal:1,text:'Note durable.')],vectors:[[1,0]]);
    store.addMemory(agentId:'aru',documentId:doc,ordinal:1,
      candidate:const AutoMemoryCandidate(quote:'Note durable.',kind:'observation',subject:'',relation:'',value:'',uncertain:true),
      vector:[1,0],extractor:'Gemma 4 E2B/test');
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:AutoMemoryPanel(
      store:store,agentId:'aru',busy:false,run:(action) async {await action();},
      embed:(text) async => [1,0],process:(id) async {},
    )))));
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,isFalse);
    await tester.tap(find.byType(SwitchListTile));await tester.pump();
    expect(store.autoMemoryEnabled('aru'),isTrue);
    expect(find.text('Note durable.'),findsOneWidget);
    await tester.ensureVisible(find.text('Note durable.'));
    await tester.tap(find.text('Note durable.'));await tester.pumpAndSettle();
    expect(find.textContaining('Ma note'),findsWidgets);
    expect(find.text('Confirmer'),findsOneWidget);
    expect(find.text('Corriger'),findsOneWidget);
    expect(find.text('Supprimer'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
