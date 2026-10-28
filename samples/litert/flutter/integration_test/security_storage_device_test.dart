import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:litert_edge_demos/living_memory/memory_key.dart';
import 'package:litert_edge_demos/living_memory/memory_store.dart';
import 'package:path_provider/path_provider.dart';

/// REAL Android Keystore + the packaged ARM64 SQLCipher. Not part of flutter
/// test; run only on an authorized device and record the exact APK/commit.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('device Keystore envelope reopens encrypted synthetic memory', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    final support = await getApplicationSupportDirectory();
    final base = await Directory('${support.path}/security-fixture')
        .create(recursive: true);
    final dir = await base.createTemp();
    final path = '${dir.path}/fixture.db';
    try {
      final key = await MemoryKey.forDatabase(path);
      expect(key != null, isTrue); // never print a key through a matcher
      final store = MemoryStore.open(
        path,
        profile: 'security-fixture',
        dimension: 2,
        encryptionKey: key,
      );
      store.createAgent('fixture', 'Synthetic fixture');
      store.addDocument(
        agentId: 'fixture',
        name: 'fixture',
        digest: 'fixture',
        chunks: [
          const MemoryChunk(
            page: 1,
            ordinal: 1,
            text: 'DEVICE_FIXTURE_LAGON42',
          ),
        ],
        vectors: [
          [1, 0],
        ],
      );
      store.close();
      final restoredKey = await MemoryKey.forDatabase(path);
      expect(restoredKey == key, isTrue);
      final reopened = MemoryStore.open(
        path,
        profile: 'security-fixture',
        dimension: 2,
        encryptionKey: restoredKey,
      );
      expect(
        reopened.searchText('fixture', 'DEVICE_FIXTURE_LAGON42').length,
        1,
      );
      reopened.close();
      expect(
        String.fromCharCodes(File(path).readAsBytesSync())
            .contains('DEVICE_FIXTURE_LAGON42'),
        isFalse,
      );
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
