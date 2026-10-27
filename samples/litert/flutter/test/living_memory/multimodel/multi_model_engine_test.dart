import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/multimodel/multi_model_engine.dart';

class Runtime implements LocalModelRuntime {
  final events = <String>[];
  final failures = <String>{};
  bool releaseFails = false;
  int held = 0;
  int maxHeld = 0;
  Future<void> _tail = Future.value();
  @override
  Future<T> exclusive<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
  @override
  Future<void> unload() async {
    events.add('unload');
    if (releaseFails) throw const ModelReleaseFailure();
    held = 0;
  }
  @override
  Future<void> load(String id) async {
    events.add('load:$id');
    if (failures.contains(id)) throw StateError('cannot load $id');
    held++;
    if (held > maxHeld) maxHeld = held;
  }
}

void main() {
  late Runtime runtime;
  late MultiModelEngine engine;
  setUp(() {
    runtime = Runtime();
    engine = MultiModelEngine(runtime, available: () => {'e2b', 'e4b'});
  });
  test('routes extraction and simple questions to E2B, synthesis to E4B', () {
    expect(engine.choose(const ModelTask.extraction()), 'e2b');
    expect(engine.choose(const ModelTask.question('Où ?')), 'e2b');
    expect(engine.choose(const ModelTask.question('Compare les sources')), 'e4b');
    expect(engine.choose(const ModelTask.question('court', sourceCount: 4)), 'e4b');
    engine.mode = ModelMode.e2b;
    expect(engine.choose(const ModelTask.question('Compare')), 'e2b');
    engine.mode = ModelMode.e4b;
    expect(engine.choose(const ModelTask.extraction()), 'e4b');
  });
  test('single registered model is enough in auto, explicit missing fails', () {
    engine = MultiModelEngine(runtime, available: () => {'e4b'});
    expect(engine.choose(const ModelTask.extraction()), 'e4b');
    engine.mode = ModelMode.e2b;
    expect(() => engine.choose(const ModelTask.extraction()), throwsStateError);
  });
  test('unloads before every activation; never two resident models', () async {
    await engine.run(const ModelTask.extraction(), (_) async => 'ok');
    await engine.run(const ModelTask.question('Compare'), (_) async => 'ok');
    expect(runtime.events, ['unload', 'load:e2b', 'unload', 'unload', 'load:e4b', 'unload']);
    expect(runtime.maxHeld, 1);
    expect(runtime.held, 0);
  });
  test('E4B load failure retries once on E2B and reports fallback', () async {
    runtime.failures.add('e4b');
    final model = await engine.run(const ModelTask.question('Compare'), (id) async => id);
    expect(model, 'e2b');
    expect(engine.lastUsed, 'e2b');
    expect(engine.fallbackReason, contains('cannot load e4b'));
  });
  test('generation failure discards result before retrying E2B', () async {
    final ids = <String>[];
    final result = await engine.run(const ModelTask.question('Compare'), (id) async {
      ids.add(id);
      if (id == 'e4b') throw StateError('generation failed');
      return 'grounded';
    });
    expect(ids, ['e4b', 'e2b']);
    expect(result, 'grounded');
    expect(runtime.held, 0);
  });
  test('native release refusal never loads or falls back', () async {
    runtime.releaseFails = true;
    await expectLater(engine.run(const ModelTask.question('Compare'), (_) async => 1), throwsA(isA<ModelReleaseFailure>()));
    expect(runtime.events, ['unload']);
  });
  test('cancellation after E4B failure prevents fallback', () async {
    var cancelled = false;
    await expectLater(engine.run(const ModelTask.question('Compare'), (_) async {
      cancelled = true;
      throw StateError('stopped');
    }, cancelled: () => cancelled), throwsA(isA<ModelCancelled>()));
    expect(runtime.events.where((e) => e == 'load:e2b'), isEmpty);
    expect(runtime.held, 0);
  });
  test('concurrent operations hold lock through inference', () async {
    final gate = Completer<void>();
    final first = engine.run(const ModelTask.extraction(), (_) async { await gate.future; return 1; });
    final second = engine.run(const ModelTask.question('Compare'), (_) async => 2);
    await Future<void>.delayed(Duration.zero);
    expect(runtime.events, ['unload', 'load:e2b']);
    gate.complete();
    expect(await Future.wait([first, second]), [1, 2]);
    expect(runtime.maxHeld, 1);
  });
  test('both failures surface and queue remains usable', () async {
    runtime.failures.addAll({'e2b', 'e4b'});
    await expectLater(engine.run(const ModelTask.question('Compare'), (_) async => 1), throwsStateError);
    runtime.failures.clear();
    expect(await engine.run(const ModelTask.extraction(), (_) async => 2), 2);
  });
}
