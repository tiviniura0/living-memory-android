import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:living_memory_core/living_memory_core.dart';
import 'package:sqlite3/sqlite3.dart';

// All keys and content below are synthetic fixtures, never device secrets.
void main() {
  const sourceKey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const recoveryKey =
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
  const deviceKey =
      '9876543210abcdef9876543210abcdef9876543210abcdef9876543210abcdef';
  late Directory directory;
  late String activePath;
  late String backupPath;
  late String restoredPath;
  late MemoryStore active;

  Database keyed(String path, String key) {
    final db = sqlite3.open(path);
    try {
      expect(db.select('PRAGMA cipher_version'), isNotEmpty);
      db.execute('PRAGMA key = "x\'$key\'"');
      db.select('SELECT count(*) FROM sqlite_master');
      return db;
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  void export({String? destination, String key = sourceKey}) {
    MemoryBackup.exportEncrypted(
      sourcePath: activePath,
      sourceKey: key,
      targetPath: destination ?? backupPath,
      recoveryKey: recoveryKey,
      profile: 'test',
      dimension: 2,
    );
  }

  void restore({
    String? source,
    String? destination,
    String key = recoveryKey,
    String profile = 'test',
    int dimension = 2,
  }) {
    MemoryBackup.restoreEncrypted(
      sourcePath: source ?? backupPath,
      recoveryKey: key,
      targetPath: destination ?? restoredPath,
      deviceKey: deviceKey,
      profile: profile,
      dimension: dimension,
    );
  }

  setUp(() {
    directory = Directory.systemTemp.createTempSync('memory-backup-');
    activePath = '${directory.path}/active.db';
    backupPath = '${directory.path}/recovery.db';
    restoredPath = '${directory.path}/restored.db';
    active = MemoryStore.open(
      activePath,
      profile: 'test',
      dimension: 2,
      encryptionKey: sourceKey,
    );
    active.createAgent('a', 'Alice');
    active.addDocument(
      agentId: 'a',
      name: 'private fixture',
      digest: 'backup-fixture',
      chunks: [
        const MemoryChunk(page: 1, ordinal: 1, text: 'SECRET_LAGOON_BACKUP'),
      ],
      vectors: [
        [1, 0],
      ],
    );
  });
  tearDown(() {
    active.close();
    directory.deleteSync(recursive: true);
  });

  test(
    'roundtrip preserves data and FTS under independent recovery/device keys',
    () {
      final originalBytes = File(activePath).readAsBytesSync();
      export();
      restore();
      expect(File(activePath).readAsBytesSync(), originalBytes);
      expect(active.searchText('a', 'SECRET_LAGOON_BACKUP'), hasLength(1));
      for (final path in [backupPath, restoredPath]) {
        final bytes = File(path).readAsBytesSync();
        expect(
          String.fromCharCodes(bytes),
          isNot(contains('SECRET_LAGOON_BACKUP')),
        );
        expect(
          String.fromCharCodes(bytes.take(16)),
          isNot('SQLite format 3\u0000'),
        );
      }
      final restored = MemoryStore.open(
        restoredPath,
        profile: 'test',
        dimension: 2,
        encryptionKey: deviceKey,
      );
      try {
        expect(restored.agents().single.id, 'a');
        expect(restored.searchText('a', 'SECRET_LAGOON_BACKUP'), hasLength(1));
      } finally {
        restored.close();
      }
      expect(() => keyed(backupPath, sourceKey), throwsA(anything));
      expect(() => keyed(restoredPath, recoveryKey), throwsA(anything));
      final recovered = keyed(backupPath, recoveryKey);
      try {
        expect(recovered.select('PRAGMA cipher_integrity_check'), isEmpty);
        expect(recovered.select('PRAGMA foreign_key_check'), isEmpty);
        expect(
          recovered.select('SELECT name FROM agents').single['name'],
          'Alice',
        );
      } finally {
        recovered.close();
      }
    },
  );

  test('valid encryption and profile cannot disguise an incomplete schema', () {
    final forged = sqlite3.open(backupPath);
    try {
      expect(forged.select('PRAGMA cipher_version'), isNotEmpty);
      forged.execute('PRAGMA key = "x\'$recoveryKey\'"');
      forged.execute(
        'CREATE TABLE profile(id INTEGER PRIMARY KEY, name TEXT, dimension INTEGER)',
      );
      forged.execute("INSERT INTO profile VALUES(1, 'test', 2)");
      forged.execute('CREATE TABLE agents(id TEXT PRIMARY KEY, name TEXT)');
      forged.execute('CREATE TABLE documents(id TEXT PRIMARY KEY)');
      forged.execute('CREATE TABLE chunks(document_id TEXT)');
      forged.execute('PRAGMA user_version=5');
    } finally {
      forged.close();
    }
    final archive = File(backupPath).readAsBytesSync();
    expect(restore, throwsStateError);
    expect(File(restoredPath).existsSync(), isFalse);
    expect(File(backupPath).readAsBytesSync(), archive);
    expect(active.searchText('a', 'SECRET_LAGOON_BACKUP'), hasLength(1));
  });

  for (final defect in [
    ('missing context history', 'DROP TABLE context_checkpoint_events'),
    ('missing source FTS', 'DROP TABLE chunk_fts'),
    ('missing session FTS trigger', 'DROP TRIGGER session_fts_insert'),
    ('missing source scope index', 'DROP INDEX documents_agent'),
    ('missing version five receipts', 'DROP TABLE lm_v14_records'),
    (
      'renamed source content column',
      'ALTER TABLE chunks RENAME COLUMN content TO unexpected',
    ),
  ]) {
    test('restoration refuses a canonical schema with ${defect.$1}', () {
      export();
      final malformed = keyed(backupPath, recoveryKey);
      try {
        malformed.execute(defect.$2);
      } finally {
        malformed.close();
      }
      final archive = File(backupPath).readAsBytesSync();
      expect(restore, throwsStateError);
      expect(File(restoredPath).existsSync(), isFalse);
      expect(File(backupPath).readAsBytesSync(), archive);
      expect(active.searchText('a', 'SECRET_LAGOON_BACKUP'), hasLength(1));
    });
  }

  test('recovery keys are independent raw 256-bit values', () {
    final a = MemoryBackup.generateRecoveryKey();
    final b = MemoryBackup.generateRecoveryKey();
    expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(b, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(a, isNot(b));
    expect(a, isNot(sourceKey));
  });

  test('wrong recovery key leaves archive and active database unchanged', () {
    export();
    final original = File(activePath).readAsBytesSync();
    final archive = File(backupPath).readAsBytesSync();
    Object? failure;
    try {
      restore(key: deviceKey);
    } catch (error) {
      failure = error;
    }
    expect(failure, isA<StateError>());
    expect(failure.toString(), isNot(contains(deviceKey)));
    expect(failure.toString(), isNot(contains(recoveryKey)));
    expect(File(restoredPath).existsSync(), isFalse);
    expect(File(activePath).readAsBytesSync(), original);
    expect(File(backupPath).readAsBytesSync(), archive);
  });

  test(
    'wrong source key creates no destination and leaves live store usable',
    () {
      expect(() => export(key: deviceKey), throwsStateError);
      expect(File(backupPath).existsSync(), isFalse);
      expect(active.searchText('a', 'SECRET_LAGOON_BACKUP'), hasLength(1));
    },
  );

  test('truncated encrypted archive is rejected before creating a target', () {
    export();
    final bytes = File(backupPath).readAsBytesSync();
    File(backupPath).writeAsBytesSync(bytes.sublist(0, bytes.length ~/ 2));
    final truncated = File(backupPath).readAsBytesSync();
    expect(restore, throwsStateError);
    expect(File(restoredPath).existsSync(), isFalse);
    expect(File(backupPath).readAsBytesSync(), truncated);
    expect(active.searchText('a', 'SECRET_LAGOON_BACKUP'), hasLength(1));
  });

  test(
    'export and restore never replace an existing or active destination',
    () {
      final original = File(activePath).readAsBytesSync();
      expect(() => export(destination: activePath), throwsStateError);
      export();
      final archive = File(backupPath).readAsBytesSync();
      expect(export, throwsStateError);
      expect(() => restore(destination: activePath), throwsStateError);
      File(restoredPath).writeAsStringSync('existing destination');
      expect(restore, throwsStateError);
      expect(File(restoredPath).readAsStringSync(), 'existing destination');
      expect(File(activePath).readAsBytesSync(), original);
      expect(File(backupPath).readAsBytesSync(), archive);
    },
  );

  test('future schema is refused without touching the archive', () {
    export();
    final db = keyed(backupPath, recoveryKey);
    db.execute('PRAGMA user_version=999');
    db.close();
    final archive = File(backupPath).readAsBytesSync();
    expect(restore, throwsStateError);
    expect(File(restoredPath).existsSync(), isFalse);
    expect(File(backupPath).readAsBytesSync(), archive);
  });

  test(
    'profile or dimension mismatch refuses restoration without a target',
    () {
      export();
      expect(() => restore(profile: 'other-model'), throwsStateError);
      expect(() => restore(dimension: 768), throwsStateError);
      expect(File(restoredPath).existsSync(), isFalse);
    },
  );

  test('missing profile and invalid foreign keys reject the transfer', () {
    export();
    var db = keyed(backupPath, recoveryKey);
    db.execute('DELETE FROM profile');
    db.close();
    expect(restore, throwsStateError);
    expect(File(restoredPath).existsSync(), isFalse);
    File(backupPath).deleteSync();
    export();
    db = keyed(backupPath, recoveryKey);
    db.execute('PRAGMA foreign_keys=OFF');
    db.execute("UPDATE documents SET agent_id='missing'");
    db.close();
    expect(restore, throwsStateError);
    expect(File(restoredPath).existsSync(), isFalse);
  });

  test(
    'restored missions require fresh approval instead of resuming effects',
    () {
      final db = keyed(activePath, sourceKey);
      try {
        db.execute('''CREATE TABLE lm_v14_missions (
        id TEXT PRIMARY KEY,
        agent_id TEXT NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
        scope_json TEXT NOT NULL, due_at INTEGER NOT NULL,
        steps_json TEXT NOT NULL, state TEXT NOT NULL,
        next_step INTEGER NOT NULL DEFAULT 0)''');
        for (final state in [
          'queued',
          'running',
          'awaitingPermission',
          'succeeded',
        ]) {
          db.execute(
            'INSERT INTO lm_v14_missions VALUES (?, ?, ?, ?, ?, ?, ?)',
            [state, 'a', '{"agentId":"a"}', 0, '[]', state, 0],
          );
        }
      } finally {
        db.close();
      }
      export();
      restore();
      final restored = keyed(restoredPath, deviceKey);
      final original = keyed(activePath, sourceKey);
      try {
        expect(
          restored
              .select('SELECT state FROM lm_v14_missions')
              .map((row) => row['state']),
          everyElement('cancelled'),
        );
        expect(
          original
              .select("SELECT state FROM lm_v14_missions WHERE id='queued'")
              .single['state'],
          'queued',
        );
      } finally {
        restored.close();
        original.close();
      }
    },
  );

  test('an imported trigger cannot reactivate cancelled restored missions', () {
    final source = keyed(activePath, sourceKey);
    try {
      source.execute('''CREATE TABLE lm_v14_missions (
        id TEXT PRIMARY KEY,
        agent_id TEXT NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
        scope_json TEXT NOT NULL, due_at INTEGER NOT NULL,
        steps_json TEXT NOT NULL, state TEXT NOT NULL,
        next_step INTEGER NOT NULL DEFAULT 0)''');
      source.execute(
        'INSERT INTO lm_v14_missions VALUES (?, ?, ?, ?, ?, ?, ?)',
        ['mission', 'a', '{"agentId":"a"}', 0, '[]', 'queued', 0],
      );
    } finally {
      source.close();
    }
    export();
    final malicious = keyed(backupPath, recoveryKey);
    try {
      malicious.execute('''CREATE TRIGGER reactivate_mission
        AFTER UPDATE OF state ON lm_v14_missions
        WHEN new.state='cancelled' BEGIN
          UPDATE lm_v14_missions SET state='queued' WHERE id=new.id;
        END''');
    } finally {
      malicious.close();
    }
    final activeBytes = File(activePath).readAsBytesSync();
    final archiveBytes = File(backupPath).readAsBytesSync();
    expect(restore, throwsStateError);
    expect(File(restoredPath).existsSync(), isFalse);
    expect(File(activePath).readAsBytesSync(), activeBytes);
    expect(File(backupPath).readAsBytesSync(), archiveBytes);
    expect(active.searchText('a', 'SECRET_LAGOON_BACKUP'), hasLength(1));
  });

  test('an archive with an unexpected executable view is refused', () {
    export();
    final malicious = keyed(backupPath, recoveryKey);
    try {
      malicious.execute(
        'CREATE VIEW imported_agent_view AS SELECT * FROM agents',
      );
    } finally {
      malicious.close();
    }
    final activeBytes = File(activePath).readAsBytesSync();
    expect(restore, throwsStateError);
    expect(File(restoredPath).existsSync(), isFalse);
    expect(File(activePath).readAsBytesSync(), activeBytes);
    expect(active.searchText('a', 'SECRET_LAGOON_BACKUP'), hasLength(1));
  });

  test('symbolic source, target and directory paths are refused', () {
    export();
    final sourceLink = Link('${directory.path}/source-link.db')
      ..createSync(backupPath);
    expect(() => restore(source: sourceLink.path), throwsStateError);
    final targetLink = Link('${directory.path}/target-link.db')
      ..createSync(activePath);
    expect(() => restore(destination: targetLink.path), throwsStateError);
    final directoryLink = Link('${directory.path}/directory-link')
      ..createSync(directory.path);
    expect(
      () => restore(destination: '${directoryLink.path}/new.db'),
      throwsStateError,
    );
    expect(File(restoredPath).existsSync(), isFalse);
    expect(active.searchText('a', 'SECRET_LAGOON_BACKUP'), hasLength(1));
  });

  test('quoted filenames are handled as paths rather than SQL', () {
    final quoted = '${directory.path}/recovery\'quoted.db';
    export(destination: quoted);
    restore(source: quoted);
    final restored = keyed(restoredPath, deviceKey);
    try {
      expect(
        restored.select('SELECT count(*) AS n FROM agents').single['n'],
        1,
      );
    } finally {
      restored.close();
    }
  });

  test(
    'failed export into a blocked directory preserves source and permits retry',
    () {
      final blocker = Directory(backupPath)..createSync();
      expect(export, throwsStateError);
      expect(active.searchText('a', 'SECRET_LAGOON_BACKUP'), hasLength(1));
      blocker.deleteSync();
      export();
      restore();
      expect(File(restoredPath).existsSync(), isTrue);
    },
  );
}
