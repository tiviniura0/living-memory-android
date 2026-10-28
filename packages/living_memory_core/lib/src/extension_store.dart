part of 'memory_store.dart';

void _migrateExtensions(Database db) {
  final version = db.select('PRAGMA user_version').single.values.first as int;
  if (version >= 5) return;
  db.execute('BEGIN IMMEDIATE');
  try {
    // Generic extension records: no simulation rules or world dependency here.
    db.execute('''CREATE TABLE lm_v14_records(
      namespace TEXT NOT NULL, scope_key TEXT NOT NULL, record_id TEXT NOT NULL,
      agent_id TEXT NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
      payload TEXT NOT NULL,
      PRIMARY KEY(namespace,scope_key,record_id))''');
    db.execute('PRAGMA user_version=5');
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

int _transactionSequence = 0;

extension TrustedExtensionStore on MemoryStore {
  /// Only trusted host adapters receive this handle. It is never an agent tool,
  /// external API, or an authentication boundary. It shares the encrypted file.
  Database get extensionDatabase {
    if (_closed) throw StateError('Mémoire fermée.');
    return _db;
  }

  /// Savepoints let receipt+source commit together through existing APIs, with
  /// synchronous rollback even when those APIs create an inner transaction.
  T extensionTransaction<T>(T Function() action) {
    final savepoint = 'memory_${_transactionSequence++}';
    _db.execute('SAVEPOINT $savepoint');
    try {
      final result = action();
      _db.execute('RELEASE SAVEPOINT $savepoint');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK TO SAVEPOINT $savepoint');
      _db.execute('RELEASE SAVEPOINT $savepoint');
      rethrow;
    }
  }
}
