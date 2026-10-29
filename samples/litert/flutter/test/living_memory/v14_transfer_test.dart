import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_memory_core/living_memory_core.dart';
import 'package:litert_edge_demos/config/knowledge_config.dart';
import 'package:litert_edge_demos/living_memory/backup_panel.dart';
import 'package:litert_edge_demos/living_memory/memory_transfer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('living_memory/transfer');
  const deviceKey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  late Directory directory;
  late Directory staging;
  late String activePath;
  late MemoryStore store;
  late MemoryTransfer transfer;
  late List<MethodCall> calls;
  String? pickedPath;
  String? savedPath;
  bool saveAccepted = true;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('memory-transfer-');
    staging = Directory('${directory.path}/staging')..createSync();
    activePath = '${directory.path}/active.db';
    store = MemoryStore.open(activePath,
      profile: kKbEmbeddingProfileId,
      dimension: kKbEmbeddingDimension,
      encryptionKey: deviceKey,
    );
    store.createAgent('a', 'Alice');
    store.addDocument(agentId: 'a', name: 'fixture', digest: 'fixture',
      chunks: [const MemoryChunk(page: 1, ordinal: 1, text: 'PRIVATE_TRANSFER_FIXTURE')],
      vectors: [List<double>.generate(kKbEmbeddingDimension, (i) => i == 0 ? 1 : 0)],
    );
    calls = [];
    pickedPath = null;
    savedPath = null;
    saveAccepted = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'transferDirectory') return staging.path;
      if (call.method == 'pickBackup') return pickedPath;
      if (call.method == 'saveBackup') {
        final path = (call.arguments as Map)['path'] as String;
        expect(File(path).parent.path, staging.path);
        expect((call.arguments as Map).keys, ['path']);
        if (!saveAccepted) return false;
        savedPath = '${directory.path}/selected-backup.lmemory';
        File(path).copySync(savedPath!);
        return true;
      }
      throw PlatformException(code: 'UNKNOWN');
    });
    transfer = MemoryTransfer(databasePath: activePath, deviceKey: deviceKey, channel: channel);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    store.close();
    directory.deleteSync(recursive: true);
  });

  test('SAF export/import really roundtrips SQLCipher into a separate candidate', () async {
    final original = File(activePath).readAsBytesSync();
    final recoveryKey = await transfer.exportEncrypted();
    expect(recoveryKey, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(savedPath, isNotNull);
    expect(staging.listSync(), isEmpty);
    expect(String.fromCharCodes(File(savedPath!).readAsBytesSync()), isNot(contains('PRIVATE_TRANSFER_FIXTURE')));
    pickedPath = '${staging.path}/picked.lmemory';
    File(savedPath!).copySync(pickedPath!);
    final candidatePath = await transfer.restoreEncrypted(recoveryKey!);
    expect(candidatePath, isNotNull);
    expect(candidatePath, isNot(activePath));
    expect(File(candidatePath!).parent.path, directory.path);
    expect(staging.listSync(), isEmpty);
    expect(File(activePath).readAsBytesSync(), original);
    final candidate = MemoryStore.open(candidatePath,
      profile: kKbEmbeddingProfileId, dimension: kKbEmbeddingDimension,
      encryptionKey: deviceKey,
    );
    try {
      expect(candidate.searchText('a', 'PRIVATE_TRANSFER_FIXTURE'), hasLength(1));
    } finally { candidate.close(); }
    expect(store.searchText('a', 'PRIVATE_TRANSFER_FIXTURE'), hasLength(1));
  });

  test('cancelled save removes encrypted staging and returns no recovery key', () async {
    saveAccepted = false;
    expect(await transfer.exportEncrypted(), isNull);
    expect(staging.listSync(), isEmpty);
    expect(savedPath, isNull);
    expect(store.agents().single.id, 'a');
  });

  test('cancelled import leaves the active store and staging untouched', () async {
    expect(await transfer.restoreEncrypted(List.filled(64, 'a').join()), isNull);
    expect(staging.listSync(), isEmpty);
    expect(store.agents().single.id, 'a');
  });

  test('wrong recovery key cleans only imported staging and creates no candidate', () async {
    await transfer.exportEncrypted();
    pickedPath = '${staging.path}/picked.lmemory';
    File(savedPath!).copySync(pickedPath!);
    final before = directory.listSync().map((entry) => entry.path).toSet();
    await expectLater(transfer.restoreEncrypted(List.filled(64, 'a').join()), throwsStateError);
    expect(staging.listSync(), isEmpty);
    expect(directory.listSync().map((entry) => entry.path).toSet(), before);
    expect(store.searchText('a', 'PRIVATE_TRANSFER_FIXTURE'), hasLength(1));
  });

  test('invalid key is refused before the native picker runs', () async {
    await expectLater(transfer.restoreEncrypted('human password'), throwsStateError);
    expect(calls, isEmpty);
  });

  test('out of staging picker path is refused without deleting that file', () async {
    pickedPath = '${directory.path}/foreign-file';
    File(pickedPath!).writeAsStringSync('keep me');
    await expectLater(transfer.restoreEncrypted(List.filled(64, 'a').join()), throwsStateError);
    expect(File(pickedPath!).readAsStringSync(), 'keep me');
    expect(store.agents().single.id, 'a');
  });

  testWidgets('panel separates recovery key and masks import entry without clipboard side effects', (tester) async {
    final clipboard = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method.startsWith('Clipboard.')) clipboard.add(call);
        return null;
      });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(home: BackupPanel(
      databasePath: activePath, deviceKey: deviceKey, transfer: transfer,
    )));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    await tester.tap(find.text('Exporter une sauvegarde chiffrée'));
    await tester.pumpAndSettle();
    final keys = tester.widgetList<SelectableText>(find.byType(SelectableText));
    expect(keys.any((text) => RegExp(r'^[0-9a-f]{64}$').hasMatch(text.data ?? '')), isTrue);
    expect(clipboard, isEmpty);
    expect(find.textContaining('Ne pas enregistrer cette clé avec'), findsOneWidget);
  });

  testWidgets('successful import reports a verified separate copy and keeps active memory', (tester) async {
    final recoveryKey = await transfer.exportEncrypted();
    pickedPath = '${staging.path}/picked.lmemory';
    File(savedPath!).copySync(pickedPath!);
    await tester.pumpWidget(MaterialApp(home: BackupPanel(
      databasePath: activePath, deviceKey: deviceKey, transfer: transfer,
    )));
    await tester.enterText(find.byType(TextField), recoveryKey!);
    await tester.tap(find.text('Vérifier une restauration'));
    await tester.pumpAndSettle();
    expect(find.textContaining('La mémoire active est conservée'), findsOneWidget);
    expect(store.searchText('a', 'PRIVATE_TRANSFER_FIXTURE'), hasLength(1));
    expect(find.text('Activer'), findsNothing);
  });
}
