import 'dart:io';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

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
      final type = FileSystemEntity.typeSync('$path$suffix', followLinks: false);
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
    final version = db.select('PRAGMA user_version').single.values.single as int;
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
    // These canonical tables must exist even for an otherwise empty memory.
    for (final table in ['agents', 'documents', 'chunks']) {
      db.select('SELECT count(*) FROM "$table"');
    }
    return version;
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
      source.execute('ATTACH DATABASE ? AS transfer KEY "x\'$targetKey\'"', [to]);
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
      _validate(target, profile, dimension);
      if (restoring &&
          target.select(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='lm_v14_missions'",
          ).isNotEmpty) {
        target.execute('BEGIN IMMEDIATE');
        try {
          target.execute("UPDATE lm_v14_missions SET state='cancelled'");
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
