import 'dart:io';

import 'package:flutter_edge_ai/flutter_edge_ai.dart' show PreferredBackend;
import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/domain/models/chat_model.dart';
import 'package:litert_edge_demos/living_memory/multimodel/model_registry.dart';
import 'package:litert_edge_demos/living_memory/multimodel/multi_model_engine.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('model-registry-'));
  tearDown(() => dir.deleteSync(recursive: true));
  CustomChatModel model(String path) => CustomChatModel(
    displayName: 'Gemma 4 E2B',
    source: LocalModelSource(path),
    backend: PreferredBackend.gpu,
    maxTokens: 8192,
    file: const CustomModelFile(
      name: 'gemma.litertlm',
      sizeBytes: 4,
      checksumMatched: false,
    ),
  );
  // The registry only copies bytes and metadata, it never claims to validate AI weights.
  test(
    'private copies survive source removal, mode and hashes persist',
    () async {
      final source = File('${dir.path}/source.litertlm')
        ..writeAsStringSync('data');
      final r = ModelRegistry(Directory('${dir.path}/registry'));
      await r.load();
      expect(r.models, isEmpty);
      // register accepts a model and a source path, not an invented bundle.
      await r.register('e2b', source.path, model(source.path));
      source.deleteSync();
      await r.setMode(ModelMode.e2b);
      final reopened = ModelRegistry(r.directory);
      await reopened.load();
      expect(reopened.mode, ModelMode.e2b);
      expect(reopened.models['e2b']!.maxTokens, 2048);
      expect(await reopened.verify('e2b'), isTrue);
      final savedModel = reopened.models['e2b']!;
      final path = (savedModel.source as LocalModelSource).path;
      File(path).writeAsStringSync('evil');
      expect(await reopened.verify('e2b'), isFalse);
    },
  );
  test(
    'corrupt or future manifest is rejected without overwriting it',
    () async {
      final r = ModelRegistry(dir);
      final f = File('${dir.path}/registry.json')
        ..writeAsStringSync('{"v":99}');
      await expectLater(r.load(), throwsFormatException);
      expect(f.readAsStringSync(), '{"v":99}');
    },
  );
  test('failed registration leaves prior model and mode intact', () async {
    final r = ModelRegistry(Directory('${dir.path}/registry'));
    final source = File('${dir.path}/source.litertlm')
      ..writeAsStringSync('data');
    await r.load();
    await r.register('e2b', source.path, model(source.path));
    final before = File('${r.directory.path}/registry.json').readAsStringSync();
    await expectLater(
      r.register('e4b', '${dir.path}/missing', model(source.path)),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      File('${r.directory.path}/registry.json').readAsStringSync(),
      before,
    );
    expect(r.models.keys, ['e2b']);
  });
  test(
    'fixed NPU context is preserved instead of applying GPU context cap',
    () async {
      final source = File('${dir.path}/npu.litertlm')
        ..writeAsStringSync('data');
      final registry = ModelRegistry(Directory('${dir.path}/registry'));
      await registry.register(
        'e4b',
        source.path,
        model(source.path)
            .copyWith(backend: PreferredBackend.npu, maxTokens: 4096),
      );
      expect(registry.models['e4b']!.maxTokens, 4096);
    },
  );
  test(
    'remove deletes only the chosen private copy and persists removal',
    () async {
      final source = File('${dir.path}/source.litertlm')
        ..writeAsStringSync('data');
      final registry = ModelRegistry(Directory('${dir.path}/registry'));
      await registry.register('e2b', source.path, model(source.path));
      await registry.register('e4b', source.path, model(source.path));
      final path = (registry.models['e2b']!.source as LocalModelSource).path;
      await registry.remove('e2b');
      expect(await File(path).exists(), isFalse);
      expect(await source.exists(), isTrue);
      expect(await registry.verify('e4b'), isTrue);
      final reopened = ModelRegistry(registry.directory);
      await reopened.load();
      expect(reopened.models.keys, ['e4b']);
    },
  );
  test('verify rejects a private path replaced by a symbolic link', () async {
    final source = File('${dir.path}/source.litertlm')
      ..writeAsStringSync('data');
    final registry = ModelRegistry(Directory('${dir.path}/registry'));
    await registry.register('e2b', source.path, model(source.path));
    final path = (registry.models['e2b']!.source as LocalModelSource).path;
    await File(path).delete();
    await Link(path).create(source.path);
    expect(await registry.verify('e2b'), isFalse);
    await expectLater(registry.remove('e2b'), throwsFormatException);
    expect(await source.exists(), isTrue);
  });
  test(
    'low space and cancelled registration preserve prior manifest and source',
    () async {
      final source = File('${dir.path}/source.litertlm')
        ..writeAsStringSync('data');
      final registry = ModelRegistry(
        Directory('${dir.path}/registry'),
        freeBytes: () async => 1,
      );
      await expectLater(
        registry.register('e2b', source.path, model(source.path)),
        throwsA(isA<FileSystemException>()),
      );
      expect(registry.models, isEmpty);
      expect(await source.exists(), isTrue);
      final other = ModelRegistry(Directory('${dir.path}/other'));
      await expectLater(
        other.register(
          'e2b',
          source.path,
          model(source.path),
          cancelled: () => true,
        ),
        throwsA(isA<ModelCancelled>()),
      );
      expect(other.models, isEmpty);
    },
  );
  test(
    'replacement commits new copy before removing superseded private copy',
    () async {
      final source = File('${dir.path}/source.litertlm')
        ..writeAsStringSync('data');
      final registry = ModelRegistry(Directory('${dir.path}/registry'));
      await registry.register('e2b', source.path, model(source.path));
      final before = (registry.models['e2b']!.source as LocalModelSource).path;
      await registry.register('e2b', source.path, model(source.path));
      expect(await File(before).exists(), isFalse);
      expect(await registry.verify('e2b'), isTrue);
      expect(await source.exists(), isTrue);
    },
  );
  test(
    'oversized sparse local model is rejected before reserve or copying',
    () async {
      var preflightPassed = false;
      final registry = ModelRegistry(
        Directory('${dir.path}/registry'),
        freeBytes: () async {
          preflightPassed = true;
          throw StateError('SIZE_PREFLIGHT_MISSING');
        },
      );
      final source = File('${dir.path}/large.litertlm');
      final handle = source.openSync(mode: FileMode.write);
      handle.truncateSync(8 * 1024 * 1024 * 1024 + 1);
      handle.closeSync();
      await expectLater(
        registry.register('e2b', source.path, model(source.path)),
        throwsFormatException,
      );
      expect(preflightPassed, isFalse);
      expect(registry.models, isEmpty);
      expect(
        registry.directory.existsSync()
            ? registry.directory.listSync().whereType<File>().where(
                (f) => f.path.endsWith('.part'),
              )
            : <File>[],
        isEmpty,
      );
    },
  );
}
