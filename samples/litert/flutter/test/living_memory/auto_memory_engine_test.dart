import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/auto_memory_candidate.dart';
import 'package:litert_edge_demos/living_memory/auto_memory_engine.dart';
import 'package:litert_edge_demos/living_memory/memory_store.dart';

void main() {
  late Directory dir;
  late MemoryStore store;
  late String document;
  var calls = 0;
  var cancel = false;
  const c = AutoMemoryCandidate(quote:'Une note.',kind:'observation',subject:'',relation:'',value:'',uncertain:true);
  setUp(() {
    calls=0; cancel=false;
    dir=Directory.systemTemp.createTempSync('auto-engine-');
    store=MemoryStore.open('${dir.path}/test.db',profile:'test',dimension:2);
    store.createAgent('aru','Aru');
    document=store.addDocument(agentId:'aru',name:'TXT',digest:'test',
      chunks:[for(var i=1;i<=10;i++) MemoryChunk(page:1,ordinal:i,text:'Une note.')],
      vectors:List.generate(10,(_)=>[1.0,0.0]));
  });
  tearDown(() { store.close(); dir.deleteSync(recursive:true); });
  AutoMemoryEngine engine({bool fail=false}) => AutoMemoryEngine(store:store,
    extract:(text) async { calls++; if(fail) throw const FormatException('invalid JSON'); return [c]; },
    embed:(text) async => [1,0], cancelled:()=>cancel);
  test('disabled engine makes no model call and stores no answer',() async {
    await engine().process('aru',document);
    expect(calls,0); expect(store.memories('aru'),isEmpty);
  });
  test('integration caps work, checkpoints and resumes without re-extraction',() async {
    store.setAutoMemoryEnabled('aru',enabled:true);
    final e=engine();
    final first=await e.process('aru',document);
    expect(first.processed,8); expect(calls,8); expect(store.memories('aru'),hasLength(8));
    final next=await e.process('aru',document);
    expect(next.processed,2); expect(calls,10);
    await e.process('aru',document); expect(calls,10);
    expect(store.search('aru',[1,0]),hasLength(3));
  });
  test('model failure preserves V1 and does not mark incomplete extraction done',() async {
    store.setAutoMemoryEnabled('aru',enabled:true);
    await expectLater(engine(fail:true).process('aru',document),throwsFormatException);
    expect(store.documents('aru'),hasLength(1)); expect(store.memories('aru'),isEmpty);
    expect(store.memoryPassages('aru',document),hasLength(8));
    await engine().process('aru',document); expect(store.memories('aru'),hasLength(8));
  });
  test('cancel before work produces no calls or write',() async {
    store.setAutoMemoryEnabled('aru',enabled:true); cancel=true;
    await engine().process('aru',document); expect(calls,0);
    expect(store.memories('aru'),isEmpty);
  });
  test('cancel during native inference prevents write and checkpoint',() async {
    store.setAutoMemoryEnabled('aru',enabled:true);
    final e=AutoMemoryEngine(store:store,extract:(text) async {cancel=true;return [c];},
      embed:(text) async => [1,0],cancelled:()=>cancel);
    await e.process('aru',document);
    expect(store.memories('aru'),isEmpty); expect(store.memoryPassages('aru',document),hasLength(8));
  });
}
