part of 'memory_store.dart';

void _migrateLifecycle(Database db) {
  final version = db.select('PRAGMA user_version').single.values.first as int;
  if (version >= 3) return;
  db.execute('BEGIN IMMEDIATE');
  try {
    db.execute(
      "ALTER TABLE documents ADD COLUMN project_id TEXT NOT NULL DEFAULT ''",
    );
    db.execute(
      "ALTER TABLE documents ADD COLUMN world_id TEXT NOT NULL DEFAULT ''",
    );
    db.execute(
      '''CREATE VIRTUAL TABLE chunk_fts USING fts5(
      content,content='chunks',content_rowid='rowid',tokenize='unicode61 remove_diacritics 2')''',
    );
    db.execute(
      '''CREATE TRIGGER chunks_fts_insert AFTER INSERT ON chunks BEGIN
      INSERT INTO chunk_fts(rowid,content) VALUES(new.rowid,new.content); END''',
    );
    db.execute(
      '''CREATE TRIGGER chunks_fts_delete AFTER DELETE ON chunks BEGIN
      INSERT INTO chunk_fts(chunk_fts,rowid,content) VALUES('delete',old.rowid,old.content); END''',
    );
    db.execute(
      '''CREATE TRIGGER chunks_fts_update AFTER UPDATE ON chunks BEGIN
      INSERT INTO chunk_fts(chunk_fts,rowid,content) VALUES('delete',old.rowid,old.content);
      INSERT INTO chunk_fts(rowid,content) VALUES(new.rowid,new.content); END''',
    );
    db.execute("INSERT INTO chunk_fts(chunk_fts) VALUES('rebuild')");
    db.execute(
      '''CREATE TABLE context_sessions(
      id TEXT PRIMARY KEY,agent_id TEXT NOT NULL REFERENCES agents(id),
      scope_key TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)''',
    );
    db.execute(
      'CREATE INDEX context_scope ON context_sessions(scope_key,updated_at)',
    );
    db.execute('''CREATE TABLE context_messages(
      session_id TEXT NOT NULL REFERENCES context_sessions(id) ON DELETE CASCADE,
      ordinal INTEGER NOT NULL,role TEXT NOT NULL CHECK(role IN ('user','assistant')),
      content TEXT NOT NULL,decision INTEGER NOT NULL CHECK(decision IN (0,1)),
      created_at TEXT NOT NULL,PRIMARY KEY(session_id,ordinal))''');
    db.execute('''CREATE TABLE context_checkpoints(
      id TEXT PRIMARY KEY,session_id TEXT NOT NULL REFERENCES context_sessions(id) ON DELETE CASCADE,
      through_ordinal INTEGER NOT NULL,summary TEXT NOT NULL,kind TEXT NOT NULL,
      created_at TEXT NOT NULL,UNIQUE(session_id,through_ordinal,kind))''');
    db.execute('PRAGMA user_version=3');
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

class SessionMessage {
  SessionMessage._(Row r)
    : ordinal = r['ordinal'] as int,
      role = r['role'] as String,
      text = r['content'] as String,
      decision = r['decision'] == 1,
      createdAt = r['created_at'] as String;
  final int ordinal;
  final String role;
  final String text;
  final bool decision;
  final String createdAt;
}

class ContextCheckpoint {
  ContextCheckpoint._(Row r)
    : id = r['id'] as String,
      throughOrdinal = r['through_ordinal'] as int,
      summary = r['summary'] as String,
      kind = r['kind'] as String,
      createdAt = r['created_at'] as String;
  final String id;
  final int throughOrdinal;
  final String summary;
  final String kind;
  final String createdAt;
}

extension ContextStorage on MemoryStore {
  void _session(String scopeKey, String id) {
    if (_db.select(
      'SELECT id FROM context_sessions WHERE scope_key=? AND id=?',
      [scopeKey, id],
    ).isEmpty) {
      throw StateError('Session absente de cette portée.');
    }
  }

  String createSession(String scopeKey, String agentId) {
    if (scopeKey.length > 1000 || scopeKey.isEmpty) {
      throw ArgumentError('Portée invalide');
    }
    final count =
        _db.select(
              'SELECT COUNT(*) AS n FROM context_sessions WHERE scope_key=?',
              [scopeKey],
            ).single['n']
            as int;
    if (count >= 1000) throw StateError('Limite : 1000 sessions par portée.');
    final now = DateTime.now().toUtc().toIso8601String();
    final random = math.Random.secure();
    final id = sha256
        .convert(List.generate(32, (_) => random.nextInt(256)))
        .toString();
    _db.execute('INSERT INTO context_sessions VALUES(?,?,?,?,?)', [
      id,
      agentId,
      scopeKey,
      now,
      now,
    ]);
    return id;
  }

  List<({String id, String updatedAt})> contextSessions(String scopeKey) => [
    for (final r in _db.select(
      'SELECT id,updated_at FROM context_sessions WHERE scope_key=? ORDER BY updated_at DESC,id LIMIT 50',
      [scopeKey],
    ))
      (id: r['id'] as String, updatedAt: r['updated_at'] as String),
  ];
  List<SessionMessage> sessionMessages(String scopeKey, String id) {
    _session(scopeKey, id);
    return [
      for (final r in _db.select(
        'SELECT * FROM context_messages WHERE session_id=? ORDER BY ordinal',
        [id],
      ))
        SessionMessage._(r),
    ];
  }

  void appendSessionMessage(
    String scopeKey,
    String id,
    String role,
    String text, {
    bool decision = false,
  }) {
    _session(scopeKey, id);
    if (!const ['user', 'assistant'].contains(role) ||
        text.trim().isEmpty ||
        utf8.encode(text).length > 20000 ||
        (decision && role != 'user')) {
      throw ArgumentError(
        'Message invalide ; les outils ne sont pas des messages générés.',
      );
    }
    _transaction(() {
      final counts = _db.select(
        'SELECT COUNT(*) AS n,COALESCE(SUM(length(CAST(content AS BLOB))),0) AS bytes FROM context_messages WHERE session_id=?',
        [id],
      ).single;
      if ((counts['n'] as int) >= 10000 ||
          (counts['bytes'] as int) + utf8.encode(text).length > 2000000) {
        throw StateError('Archive pleine : crée une nouvelle session.');
      }
      final ordinal =
          (_db.select(
                'SELECT COALESCE(MAX(ordinal),0) AS n FROM context_messages WHERE session_id=?',
                [id],
              ).single['n']
              as int) +
          1;
      final now = DateTime.now().toUtc().toIso8601String();
      _db.execute('INSERT INTO context_messages VALUES(?,?,?,?,?,?)', [
        id,
        ordinal,
        role,
        text,
        decision ? 1 : 0,
        now,
      ]);
      _db.execute('UPDATE context_sessions SET updated_at=? WHERE id=?', [
        now,
        id,
      ]);
    });
  }

  List<ContextCheckpoint> sessionCheckpoints(String scopeKey, String id) {
    _session(scopeKey, id);
    return [
      for (final r in _db.select(
        'SELECT * FROM context_checkpoint_events WHERE session_id=? ORDER BY rowid',
        [id],
      ))
        ContextCheckpoint._(r),
    ];
  }

  ContextCheckpoint writeCheckpoint(
    String scopeKey,
    String id,
    int throughOrdinal,
    String summary,
    String kind,
  ) {
    _session(scopeKey, id);
    if (!const ['compact', 'reset'].contains(kind) ||
        utf8.encode(summary).length > 20000) {
      throw ArgumentError('Checkpoint invalide');
    }
    final previous = sessionCheckpoints(scopeKey, id).lastOrNull;
    if (previous != null &&
        previous.throughOrdinal == throughOrdinal &&
        previous.summary == summary &&
        previous.kind == kind) {
      return previous;
    }
    final key = sha256
        .convert(
          utf8.encode(
            jsonEncode([id, throughOrdinal, kind, summary, previous?.id]),
          ),
        )
        .toString();
    _db.execute('INSERT INTO context_checkpoint_events VALUES(?,?,?,?,?,?)', [
      key,
      id,
      throughOrdinal,
      summary,
      kind,
      DateTime.now().toUtc().toIso8601String(),
    ]);
    return ContextCheckpoint._(
      _db.select('SELECT * FROM context_checkpoint_events WHERE id=?', [
        key,
      ]).single,
    );
  }

  /// Includes messages, decisions and both checkpoint tables through FKs.
  /// Source documents explicitly saved from this session remain independent.
  void deleteSession(String scopeKey, String id) {
    _session(scopeKey, id);
    _db.execute('DELETE FROM context_sessions WHERE scope_key=? AND id=?', [
      scopeKey,
      id,
    ]);
  }

  void markSessionDecision(
    String scopeKey,
    String id,
    int ordinal, {
    required bool decision,
  }) {
    _session(scopeKey, id);
    _db.execute(
      "UPDATE context_messages SET decision=? WHERE session_id=? AND ordinal=? AND role='user'",
      [decision ? 1 : 0, id, ordinal],
    );
  }

  List<MemoryHit> searchText(
    String agentId,
    String query, {
    int topK = 6,
    String projectId = '',
    String worldId = '',
  }) {
    if (topK < 1 || topK > 20 || utf8.encode(query).length > 2000) {
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
        '''SELECT d.id,d.name,c.page,c.ordinal,c.content
      FROM chunk_fts JOIN chunks c ON c.rowid=chunk_fts.rowid JOIN documents d ON d.id=c.document_id
      WHERE chunk_fts MATCH ? AND d.agent_id=? AND d.project_id=? AND d.world_id=?
      ORDER BY chunk_fts.rank,c.rowid LIMIT ?''',
        [terms.join(' OR '), agentId, projectId, worldId, topK],
      ))
        MemoryHit(
          agentId: agentId,
          documentId: r['id'] as String,
          name: r['name'] as String,
          page: r['page'] as int,
          ordinal: r['ordinal'] as int,
          text: r['content'] as String,
          similarity: 0,
        ),
    ];
  }
}
