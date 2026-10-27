part of 'memory_store.dart';

void _migrateSessionRetrieval(Database db) {
  if ((db.select('PRAGMA user_version').single.values.first as int) >= 4) {
    return;
  }
  db.execute('BEGIN IMMEDIATE');
  try {
    // Keep the schema-3 checkpoint table intact for traceability. The new
    // append-only event table allows another compaction after a reset.
    db.execute(
      '''CREATE TABLE context_checkpoint_events(
      id TEXT PRIMARY KEY,session_id TEXT NOT NULL REFERENCES context_sessions(id) ON DELETE CASCADE,
      through_ordinal INTEGER NOT NULL,summary TEXT NOT NULL,kind TEXT NOT NULL,created_at TEXT NOT NULL)''',
    );
    db.execute(
      'INSERT INTO context_checkpoint_events SELECT * FROM context_checkpoints ORDER BY rowid',
    );
    db.execute(
      'CREATE INDEX checkpoint_session ON context_checkpoint_events(session_id)',
    );
    db.execute(
      '''CREATE VIRTUAL TABLE session_fts USING fts5(
      content,content='context_messages',content_rowid='rowid',tokenize='unicode61 remove_diacritics 2')''',
    );
    db.execute(
      '''CREATE TRIGGER session_fts_insert AFTER INSERT ON context_messages BEGIN
      INSERT INTO session_fts(rowid,content) VALUES(new.rowid,new.content); END''',
    );
    db.execute(
      '''CREATE TRIGGER session_fts_delete AFTER DELETE ON context_messages BEGIN
      INSERT INTO session_fts(session_fts,rowid,content) VALUES('delete',old.rowid,old.content); END''',
    );
    db.execute(
      '''CREATE TRIGGER session_fts_update AFTER UPDATE ON context_messages BEGIN
      INSERT INTO session_fts(session_fts,rowid,content) VALUES('delete',old.rowid,old.content);
      INSERT INTO session_fts(rowid,content) VALUES(new.rowid,new.content); END''',
    );
    db.execute("INSERT INTO session_fts(session_fts) VALUES('rebuild')");
    db.execute('PRAGMA user_version=4');
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

extension SessionRetrieval on MemoryStore {
  /// Only explicit user decisions are RAG evidence. Ordinary questions and
  /// generated assistant messages stay in the archive, outside retrieval.
  List<MemoryHit> searchDecisions(String scopeKey, String agentId, String query) {
    if (utf8.encode(query).length > 2000) {
      throw ArgumentError('Recherche invalide');
    }
    final terms = RegExp(r'[a-zA-ZÀ-ÖØ-öø-ÿ0-9_]{2,64}')
        .allMatches(query)
        .take(12)
        .map((m) => '"${m.group(0)}"')
        .toList();
    if (terms.isEmpty) return [];
    return [
      for (final r in _db.select(
        '''SELECT s.id,m.ordinal,m.content FROM session_fts
        JOIN context_messages m ON m.rowid=session_fts.rowid
        JOIN context_sessions s ON s.id=m.session_id
        WHERE session_fts MATCH ? AND s.scope_key=? AND s.agent_id=?
        AND m.role='user' AND m.decision=1 ORDER BY session_fts.rank,m.rowid LIMIT 6''',
        [terms.join(' OR '), scopeKey, agentId],
      ))
        MemoryHit(
          agentId: agentId,
          documentId: 'session:${r['id']}',
          name: 'Décision utilisateur • session ${r['id'].toString().substring(0, 8)}',
          page: 1,
          ordinal: r['ordinal'] as int,
          text: 'Déclaration de l’utilisateur, sans vérification externe : ${r['content']}',
          similarity: 0,
        ),
    ];
  }
}
