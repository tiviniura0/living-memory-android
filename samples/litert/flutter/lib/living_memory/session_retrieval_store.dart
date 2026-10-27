part of 'memory_store.dart';

void _migrateSessionRetrieval(Database db) {
  if ((db.select('PRAGMA user_version').single.values.first as int) >= 4) return;
  db.execute('BEGIN IMMEDIATE');
  try {
    // Keep the schema-3 checkpoint table intact for traceability. The new
    // append-only event table allows another compaction after a reset.
    db.execute('''CREATE TABLE context_checkpoint_events(
      id TEXT PRIMARY KEY,session_id TEXT NOT NULL REFERENCES context_sessions(id) ON DELETE CASCADE,
      through_ordinal INTEGER NOT NULL,summary TEXT NOT NULL,kind TEXT NOT NULL,created_at TEXT NOT NULL)''');
    db.execute('INSERT INTO context_checkpoint_events SELECT * FROM context_checkpoints ORDER BY rowid');
    db.execute('CREATE INDEX checkpoint_session ON context_checkpoint_events(session_id)');
    db.execute('''CREATE VIRTUAL TABLE session_fts USING fts5(
      content,content='context_messages',content_rowid='rowid',tokenize='unicode61 remove_diacritics 2')''');
    db.execute('''CREATE TRIGGER session_fts_insert AFTER INSERT ON context_messages BEGIN
      INSERT INTO session_fts(rowid,content) VALUES(new.rowid,new.content); END''');
    db.execute('''CREATE TRIGGER session_fts_delete AFTER DELETE ON context_messages BEGIN
      INSERT INTO session_fts(session_fts,rowid,content) VALUES('delete',old.rowid,old.content); END''');
    db.execute('''CREATE TRIGGER session_fts_update AFTER UPDATE ON context_messages BEGIN
      INSERT INTO session_fts(session_fts,rowid,content) VALUES('delete',old.rowid,old.content);
      INSERT INTO session_fts(rowid,content) VALUES(new.rowid,new.content); END''');
    db.execute("INSERT INTO session_fts(session_fts) VALUES('rebuild')");
    db.execute('PRAGMA user_version=4');
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}
