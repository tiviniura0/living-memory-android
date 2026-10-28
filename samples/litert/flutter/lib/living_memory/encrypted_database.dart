import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// SQLCipher is selected by the pinned sqlite3 build hook. A missing cipher
/// is an error, never a silently unencrypted database. Keys are never logged.
class _MigrationFailure implements Exception {
  const _MigrationFailure(this.stage, this.code);
  final int stage;
  final int code;
}

class EncryptedMemoryDatabase {
  static bool isPlaintext(String path) {
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() < 16) return false;
    final handle = file.openSync();
    try {
      return String.fromCharCodes(handle.readSync(16)) ==
          'SQLite format 3\u0000';
    } finally {
      handle.closeSync();
    }
  }

  static Database open(String path, String key) {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(key)) {
      throw ArgumentError('Clé de base invalide.');
    }
    for (final name in [
      path,
      '$path.migration-lock',
      '$path.encrypted-pending',
    ]) {
      if (FileSystemEntity.typeSync(name, followLinks: false) ==
          FileSystemEntityType.link) {
        throw StateError('Lien de stockage refusé.');
      }
    }
    final lock = File('$path.migration-lock').openSync(mode: FileMode.append);
    try {
      lock.lockSync(FileLock.blockingExclusive);
      if (isPlaintext(path)) _migrate(path, key);
      return _keyed(path, key);
    } catch (error) {
      // SQLite exceptions may include SQL and the raw key in a PRAGMA. Never
      // propagate them into Flutter error diagnostics, logs, or the UI.
      throw StateError(
        'Mémoire chiffrée inaccessible. Données conservées ; ne pas réinitialiser ni désinstaller.'
        '${error is _MigrationFailure ? ' Migration ${error.stage}/${error.code}.' : ''}',
      );
    } finally {
      lock.closeSync();
    }
  }

  static void _requireCipher(Database db) {
    if (db.select('PRAGMA cipher_version').isEmpty) {
      throw StateError('SQLCipher requis.');
    }
  }

  static Database _keyed(String path, String key) {
    final db = sqlite3.open(path);
    try {
      _requireCipher(db);
      db.execute('PRAGMA key = "x\'$key\'"');
      db.execute('PRAGMA cipher_memory_security = ON');
      db.execute('PRAGMA temp_store = MEMORY');
      db.select('SELECT count(*) FROM sqlite_master');
      return db;
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  static String _quote(String identifier) =>
      '"${identifier.replaceAll('"', '""')}"';

  static void _check(Database db) {
    if (db.select('PRAGMA integrity_check').single.values.single != 'ok' ||
        db.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw StateError('Vérification SQLite échouée.');
    }
  }

  static void _migrate(String path, String key) {
    final pending = File('$path.encrypted-pending');
    final source = sqlite3.open(path);
    Database? verified;
    var sourceClosed = false;
    var stage = 0;
    try {
      _requireCipher(source);
      final version =
          source.select('PRAGMA user_version').single.values.single as int;
      if (version > 4) throw StateError('Schéma futur refusé.');
      stage = 1;
      _check(source);
      // Checkpoint and remove sidecars before replacement. A busy WAL must
      // abort migration; no rename over an active journal is allowed.
      final checkpoint = source.select('PRAGMA wal_checkpoint(TRUNCATE)');
      if (checkpoint.isNotEmpty && checkpoint.single.values.first != 0) {
        throw StateError('Base occupée.');
      }
      final mode = source
          .select('PRAGMA journal_mode=DELETE')
          .single
          .values
          .single;
      if (mode != 'delete') throw StateError('Base occupée.');
      stage = 2;
      source.execute('PRAGMA temp_store=MEMORY');
      // An interrupted encrypted export is disposable only after the source
      // has been validated. The source itself is never deleted on failure.
      if (pending.existsSync()) pending.deleteSync();
      source.execute('ATTACH DATABASE ? AS protected KEY "x\'$key\'"', [
        pending.path,
      ]);
      source.execute('PRAGMA protected.synchronous=FULL');
      stage = 3;
      source.select("SELECT sqlcipher_export('protected')");
      source.execute('PRAGMA protected.user_version=$version');
      source.execute('DETACH DATABASE protected');
      stage = 4;
      verified = _keyed(pending.path, key);
      _check(verified);
      if (verified.select('PRAGMA cipher_integrity_check').isNotEmpty) {
        throw StateError('Intégrité chiffrée invalide.');
      }
      stage = 5;
      // Check every user/shadow table, including both generations of
      // checkpoints and FTS. EXCEPT compares full rows in both directions.
      source.execute('ATTACH DATABASE ? AS protected KEY "x\'$key\'"', [
        pending.path,
      ]);
      for (final row in source.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      )) {
        final table = _quote(row['name'] as String);
        for (final schemas in [('main', 'protected'), ('protected', 'main')]) {
          if (source
              .select(
                'SELECT * FROM ${schemas.$1}.$table EXCEPT SELECT * FROM ${schemas.$2}.$table LIMIT 1',
              )
              .isNotEmpty) {
            throw StateError('Migration incomplète.');
          }
        }
        final oldCount = source
            .select('SELECT count(*) FROM main.$table')
            .single
            .values
            .single;
        final newCount = source
            .select('SELECT count(*) FROM protected.$table')
            .single
            .values
            .single;
        if (oldCount != newCount) throw StateError('Migration incomplète.');
      }
      source.execute('DETACH DATABASE protected');
      verified.close();
      verified = null;
      source.close();
      sourceClosed = true;
      // Same private directory/filesystem: atomic replacement; no plaintext
      // backup retained. Flash wear levelling prevents a physical erase claim.
      stage = 6;
      pending.renameSync(path);
    } catch (error) {
      throw _MigrationFailure(
        stage,
        error is SqliteException ? error.resultCode : 0,
      );
    } finally {
      verified?.close();
      if (!sourceClosed) source.close();
    }
  }
}
