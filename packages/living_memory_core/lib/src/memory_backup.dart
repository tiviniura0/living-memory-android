import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import 'memory_store.dart';
import 'module_contracts.dart';

/// Independent encrypted transfers. The caller supplies an unwrapped database
/// key; this API never accesses or exports Android Keystore material.
///
/// A successful restore creates a separate database. Selecting that database is
/// an explicit host operation after closing the active store.
class MemoryBackup {
  static final _keyPattern = RegExp(r'^[0-9a-fA-F]{64}$');

  static String generateRecoveryKey() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static void exportEncrypted({
    required String sourcePath,
    required String sourceKey,
    required String targetPath,
    required String recoveryKey,
    required String profile,
    required int dimension,
  }) => _transfer(
    sourcePath: sourcePath,
    sourceKey: sourceKey,
    targetPath: targetPath,
    targetKey: recoveryKey,
    profile: profile,
    dimension: dimension,
    restoring: false,
  );

  static void restoreEncrypted({
    required String sourcePath,
    required String recoveryKey,
    required String targetPath,
    required String deviceKey,
    required String profile,
    required int dimension,
  }) => _transfer(
    sourcePath: sourcePath,
    sourceKey: recoveryKey,
    targetPath: targetPath,
    targetKey: deviceKey,
    profile: profile,
    dimension: dimension,
    restoring: true,
  );

  static String _safePath(String path) {
    if (path.isEmpty || path == ':memory:' || path.contains('\u0000')) {
      throw StateError('Chemin de transfert invalide.');
    }
    // Check every component before normalization as /link/../file traverses a
    // link even though its normalized spelling would conceal that component.
    var current = File(path).absolute;
    while (true) {
      if (FileSystemEntity.typeSync(current.path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw StateError('Lien de stockage refusé.');
      }
      final parent = current.parent;
      if (parent.path == current.path) break;
      current = File(parent.path);
    }
    return File(path).absolute.uri.normalizePath().toFilePath();
  }

  static void _sidecars(String path, {required bool mustBeAbsent}) {
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final type = FileSystemEntity.typeSync(
        '$path$suffix',
        followLinks: false,
      );
      if (type == FileSystemEntityType.link ||
          (mustBeAbsent && type != FileSystemEntityType.notFound)) {
        throw StateError('Fichier de transfert occupé.');
      }
    }
  }

  static Database _open(String path, String key) {
    final db = sqlite3.open(path, mode: OpenMode.readWrite);
    try {
      if (db.select('PRAGMA cipher_version').isEmpty) {
        throw StateError('SQLCipher requis.');
      }
      db.execute('PRAGMA key = "x\'$key\'"');
      db.execute('PRAGMA cipher_memory_security=ON');
      db.execute('PRAGMA temp_store=MEMORY');
      db.select('SELECT count(*) FROM sqlite_master');
      return db;
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  static int _validate(Database db, String profile, int dimension) {
    final version =
        db.select('PRAGMA user_version').single.values.single as int;
    if (version < 4 || version > 5) {
      throw StateError('Version de mémoire incompatible.');
    }
    if (db.select('PRAGMA cipher_integrity_check').isNotEmpty ||
        db.select('PRAGMA integrity_check').single.values.single != 'ok' ||
        db.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw StateError('Intégrité de mémoire invalide.');
    }
    final rows = db.select('SELECT id, name, dimension FROM profile');
    if (rows.length != 1 ||
        rows.single['id'] != 1 ||
        rows.single['name'] != profile ||
        rows.single['dimension'] != dimension) {
      throw StateError('Profil de mémoire incompatible.');
    }
    _validateSchema(db, version, profile, dimension);
    return version;
  }

  static String _identifier(String value) => '"${value.replaceAll('"', '""')}"';

  static String _rows(ResultSet rows) =>
      jsonEncode(rows.map((row) => row.values.toList()).toList());

  static String _normalizedSql(String sql) =>
      sql.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

  static void _validateSchema(
    Database db,
    int version,
    String profile,
    int dimension,
  ) {
    // Build the expectation with the same migrations used by the application.
    // Only this disposable in-memory store is migrated; imported bytes are
    // inspected without repair or schema creation.
    final reference = MemoryStore.open(
      ':memory:',
      profile: profile,
      dimension: dimension,
    );
    try {
      final expected = reference.extensionDatabase;
      final allowedObjects = <String, String>{};
      for (final object in expected.select(
        'SELECT type,name,tbl_name FROM sqlite_master',
      )) {
        if (version == 4 && object['tbl_name'] == 'lm_v14_records') continue;
        allowedObjects[object['name'] as String] = object['type'] as String;
      }
      // Missions are the sole optional persistent extension table. No imported
      // trigger or view may run during cancellation or future memory writes.
      allowedObjects['lm_v14_missions'] = 'table';
      allowedObjects['sqlite_autoindex_lm_v14_missions_1'] = 'index';
      for (final object in db.select('SELECT type,name FROM sqlite_master')) {
        if (allowedObjects[object['name']] != object['type']) {
          throw StateError('Objet de schéma mémoire inconnu.');
        }
      }
      final objects = expected.select(
        "SELECT type,name,tbl_name,sql FROM sqlite_master "
        "WHERE type IN ('table','index','trigger') AND name NOT LIKE 'sqlite_%'",
      );
      for (final object in objects) {
        final name = object['name'] as String;
        final table = object['tbl_name'] as String;
        // Schema four predates the additive extension receipt table.
        if (version == 4 && table == 'lm_v14_records') continue;
        final actual = db.select(
          'SELECT type,tbl_name,sql FROM sqlite_master WHERE name=?',
          [name],
        );
        if (actual.length != 1 ||
            actual.single['type'] != object['type'] ||
            actual.single['tbl_name'] != table) {
          throw StateError('Structure de mémoire incompatible.');
        }
        final quoted = _identifier(name);
        if (object['type'] == 'table') {
          for (final pragma in ['table_xinfo', 'foreign_key_list']) {
            if (_rows(db.select('PRAGMA $pragma($quoted)')) !=
                _rows(expected.select('PRAGMA $pragma($quoted)'))) {
              throw StateError('Colonnes de mémoire incompatibles.');
            }
          }
          // FTS external-content configuration is not represented by column
          // metadata. Check its module, backing table, tokenizer and rowid.
          if (name == 'chunk_fts' || name == 'session_fts') {
            if (_normalizedSql(actual.single['sql'] as String) !=
                _normalizedSql(object['sql'] as String)) {
              throw StateError('Index de recherche incompatible.');
            }
          }
          // Include implicit UNIQUE/PK indexes as well as named indexes.
          for (final index in expected.select('PRAGMA index_list($quoted)')) {
            final indexName = index['name'] as String;
            final found = db
                .select('PRAGMA index_list($quoted)')
                .where((row) => row['name'] == indexName)
                .toList();
            if (found.length != 1 ||
                found.single['unique'] != index['unique'] ||
                found.single['origin'] != index['origin'] ||
                found.single['partial'] != index['partial'] ||
                _rows(
                      db.select(
                        'PRAGMA index_xinfo(${_identifier(indexName)})',
                      ),
                    ) !=
                    _rows(
                      expected.select(
                        'PRAGMA index_xinfo(${_identifier(indexName)})',
                      ),
                    )) {
              throw StateError('Contraintes de mémoire incompatibles.');
            }
          }
        } else if (_normalizedSql(actual.single['sql'] as String) !=
            _normalizedSql(object['sql'] as String)) {
          // Trigger bodies are essential: valid FTS pages alone do not ensure
          // future writes and scoped deletions will update those pages.
          throw StateError('Index ou déclencheur de mémoire incompatible.');
        }
      }
      final missions = db.select(
        "SELECT type FROM sqlite_master WHERE name='lm_v14_missions'",
      );
      if (missions.isNotEmpty) {
        if (missions.single['type'] != 'table') {
          throw StateError('Structure de missions incompatible.');
        }
        final columns = {
          for (final column in db.select('PRAGMA table_info(lm_v14_missions)'))
            column['name'] as String: column,
        };
        if (columns.length != 7) {
          throw StateError('Colonnes de missions incompatibles.');
        }
        for (final column in {
          'id': 'TEXT',
          'agent_id': 'TEXT',
          'scope_json': 'TEXT',
          'due_at': 'INTEGER',
          'steps_json': 'TEXT',
          'state': 'TEXT',
          'next_step': 'INTEGER',
        }.entries) {
          final actual = columns[column.key];
          if (actual == null ||
              (actual['type'] as String).toUpperCase() != column.value ||
              (column.key == 'id'
                  ? actual['pk'] != 1
                  : actual['notnull'] != 1)) {
            throw StateError('Colonnes de missions incompatibles.');
          }
        }
        if (!db
            .select('PRAGMA foreign_key_list(lm_v14_missions)')
            .any(
              (row) =>
                  row['table'] == 'agents' &&
                  row['from'] == 'agent_id' &&
                  row['to'] == 'id' &&
                  row['on_delete'] == 'CASCADE',
            )) {
          throw StateError('Portée de missions incompatible.');
        }
      }
    } finally {
      reference.close();
    }
  }

  static void _transfer({
    required String sourcePath,
    required String sourceKey,
    required String targetPath,
    required String targetKey,
    required String profile,
    required int dimension,
    required bool restoring,
  }) {
    Database? source;
    Database? target;
    File? ownedTarget;
    var complete = false;
    try {
      if (!_keyPattern.hasMatch(sourceKey) ||
          !_keyPattern.hasMatch(targetKey) ||
          sourceKey.toLowerCase() == targetKey.toLowerCase() ||
          profile.isEmpty ||
          dimension < 1) {
        throw StateError('Paramètres de transfert invalides.');
      }
      final from = _safePath(sourcePath);
      final to = _safePath(targetPath);
      if (from == to ||
          FileSystemEntity.typeSync(from, followLinks: false) !=
              FileSystemEntityType.file ||
          FileSystemEntity.typeSync(to, followLinks: false) !=
              FileSystemEntityType.notFound) {
        throw StateError('Source ou destination de transfert invalide.');
      }
      _sidecars(from, mustBeAbsent: false);
      _sidecars(to, mustBeAbsent: true);
      source = _open(from, sourceKey);
      _validate(source, profile, dimension);
      // Exclusive creation protects an existing destination from replacement.
      final file = File(to)..createSync(exclusive: true);
      ownedTarget = file;
      source.execute('ATTACH DATABASE ? AS transfer KEY "x\'$targetKey\'"', [
        to,
      ]);
      source.execute('PRAGMA transfer.synchronous=FULL');
      // One main-database read snapshot spans every table copied by the export.
      // The attached output commits before detach; main receives no writes.
      source.execute('BEGIN');
      try {
        final version = _validate(source, profile, dimension);
        source.select("SELECT sqlcipher_export('transfer')");
        source.execute('PRAGMA transfer.user_version=$version');
        source.execute('COMMIT');
      } catch (_) {
        source.execute('ROLLBACK');
        rethrow;
      }
      source.execute('DETACH DATABASE transfer');
      source.close();
      source = null;
      target = _open(to, targetKey);
      final targetVersion = _validate(target, profile, dimension);
      if (restoring) {
        target.execute('BEGIN IMMEDIATE');
        try {
          if (targetVersion >= 5) {
            // Generic permission contract: no simulation dependency in core.
            target.execute(
              'DELETE FROM lm_v14_records WHERE namespace LIKE ?',
              ['${permissionRecordNamespacePrefix}%'],
            );
            if (target.select(
              'SELECT 1 FROM lm_v14_records WHERE namespace LIKE ? LIMIT 1',
              ['${permissionRecordNamespacePrefix}%'],
            ).isNotEmpty) {
              throw StateError('Neutralisation des droits invalide.');
            }
          }
          if (target
              .select(
                "SELECT 1 FROM sqlite_master WHERE type='table' AND name='lm_v14_missions'",
              )
              .isNotEmpty) {
            target.execute("UPDATE lm_v14_missions SET state='cancelled'");
            if (target
                .select(
                  "SELECT 1 FROM lm_v14_missions WHERE state IS NULL OR state<>'cancelled' LIMIT 1",
                )
                .isNotEmpty) {
              throw StateError('Neutralisation des missions invalide.');
            }
          }
          target.execute('COMMIT');
        } catch (_) {
          target.execute('ROLLBACK');
          rethrow;
        }
      }
      _validate(target, profile, dimension);
      target.close();
      target = null;
      complete = true;
    } catch (_) {
      // SQLite errors can embed SQL and raw keys. Preserve no original error,
      // paths or content in diagnostics surfaced to callers.
      throw StateError('Transfert chiffré refusé. Données source conservées.');
    } finally {
      // Cleanup must never replace the sanitized transfer failure with an
      // exception containing SQL, keys, paths or private content.
      for (final connection in [target, source]) {
        try {
          connection?.close();
        } catch (_) {
          // A connection may already have been closed by a failed operation.
        }
      }
      if (!complete && ownedTarget != null) {
        for (final suffix in ['', '-wal', '-shm', '-journal']) {
          final name = '${ownedTarget.path}$suffix';
          try {
            if (FileSystemEntity.typeSync(name, followLinks: false) ==
                FileSystemEntityType.file) {
              File(name).deleteSync();
            }
          } catch (_) {
            // Leave an inaccessible, encrypted partial output for host cleanup;
            // never remove or replace the source to recover from this failure.
          }
        }
      }
    }
  }
}
