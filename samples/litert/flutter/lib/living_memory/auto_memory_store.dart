part of 'memory_store.dart';

void _migrateAutoMemory(Database db) {
  db.execute('BEGIN IMMEDIATE');
  try {
    db.execute(
      '''CREATE TABLE IF NOT EXISTS auto_settings(
      agent_id TEXT PRIMARY KEY REFERENCES agents(id), enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)))''',
    );
    db.execute('''CREATE TABLE IF NOT EXISTS memories(
      id TEXT PRIMARY KEY, agent_id TEXT NOT NULL REFERENCES agents(id),
      document_id TEXT NOT NULL, ordinal INTEGER NOT NULL,
      content TEXT NOT NULL, quote TEXT NOT NULL, kind TEXT NOT NULL,
      subject TEXT NOT NULL, relation TEXT NOT NULL, slot_value TEXT NOT NULL,
      uncertain INTEGER NOT NULL, status TEXT NOT NULL,
      extractor TEXT NOT NULL, provenance TEXT NOT NULL,
      version INTEGER NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      vector TEXT NOT NULL,
      FOREIGN KEY(document_id,ordinal) REFERENCES chunks(document_id,ordinal) ON DELETE CASCADE,
      UNIQUE(agent_id,document_id,ordinal,quote))''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS memories_agent ON memories(agent_id)',
    );
    db.execute(
      '''CREATE TABLE IF NOT EXISTS memory_revisions(
      memory_id TEXT NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
      version INTEGER NOT NULL, snapshot TEXT NOT NULL, PRIMARY KEY(memory_id,version))''',
    );
    db.execute(
      '''CREATE TABLE IF NOT EXISTS memory_links(
      a TEXT NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
      b TEXT NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
      kind TEXT NOT NULL, created_at TEXT NOT NULL, PRIMARY KEY(a,b,kind), CHECK(a<>b))''',
    );
    db.execute(
      '''CREATE TABLE IF NOT EXISTS memory_batches(
      document_id TEXT NOT NULL, ordinal INTEGER NOT NULL, extractor TEXT NOT NULL,
      completed_at TEXT NOT NULL, PRIMARY KEY(document_id,ordinal),
      FOREIGN KEY(document_id,ordinal) REFERENCES chunks(document_id,ordinal) ON DELETE CASCADE)''',
    );
    db.execute('PRAGMA user_version=2');
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

class AutoMemoryRecord {
  AutoMemoryRecord._(Row r)
    : id = r['id'] as String,
      agentId = r['agent_id'] as String,
      documentId = r['document_id'] as String,
      ordinal = r['ordinal'] as int,
      text = r['content'] as String,
      quote = r['quote'] as String,
      kind = r['kind'] as String,
      uncertain = r['uncertain'] == 1,
      status = r['status'] as String,
      extractor = r['extractor'] as String,
      provenance = r['provenance'] as String,
      version = r['version'] as int,
      createdAt = r['created_at'] as String,
      updatedAt = r['updated_at'] as String,
      sourceName = r['source_name'] as String,
      page = r['page'] as int;
  final String id;
  final String agentId;
  final String documentId;
  final String text;
  final String quote;
  final String kind;
  final String status;
  final String extractor;
  final String provenance;
  final String createdAt;
  final String updatedAt;
  final String sourceName;
  final int ordinal;
  final int page;
  final int version;
  final bool uncertain;
}

extension AutoMemoryStorage on MemoryStore {
  bool autoMemoryEnabled(String agentId) =>
      _db.select('SELECT enabled FROM auto_settings WHERE agent_id=?', [
        agentId,
      ]).firstOrNull?['enabled'] ==
      1;

  void setAutoMemoryEnabled(String agentId, {required bool enabled}) {
    _db.execute(
      'INSERT INTO auto_settings VALUES(?,?) ON CONFLICT(agent_id) DO UPDATE SET enabled=excluded.enabled',
      [agentId, enabled ? 1 : 0],
    );
  }

  List<MemoryChunk> memoryPassages(String agentId, String documentId) => [
    for (final r in _db.select(
      '''SELECT c.* FROM chunks c JOIN documents d ON d.id=c.document_id
      WHERE d.agent_id=? AND d.id=? AND NOT EXISTS(
        SELECT 1 FROM memory_batches b WHERE b.document_id=c.document_id AND b.ordinal=c.ordinal)
      ORDER BY c.ordinal LIMIT 8''',
      [agentId, documentId],
    ))
      MemoryChunk(
        page: r['page'] as int,
        ordinal: r['ordinal'] as int,
        text: r['content'] as String,
      ),
  ];

  void completeMemoryPassage(
    String agentId,
    String documentId,
    int ordinal,
    String extractor,
  ) {
    _source(agentId, documentId, ordinal);
    _db.execute('INSERT OR IGNORE INTO memory_batches VALUES(?,?,?,?)', [
      documentId,
      ordinal,
      extractor,
      DateTime.now().toUtc().toIso8601String(),
    ]);
  }

  Row _source(String agentId, String documentId, int ordinal) {
    final rows = _db.select(
      '''SELECT c.* FROM chunks c JOIN documents d ON d.id=c.document_id
      WHERE d.agent_id=? AND d.id=? AND c.ordinal=?''',
      [agentId, documentId, ordinal],
    );
    if (rows.isEmpty) throw StateError('Source absente pour cet agent.');
    return rows.single;
  }

  List<AutoMemoryRecord> memories(
    String agentId, {
    int limit = 100,
    int offset = 0,
  }) {
    if (limit < 1 || limit > 100 || offset < 0) {
      throw ArgumentError('Pagination invalide');
    }
    return [
      for (final r in _db.select(
        '''SELECT m.*,d.name AS source_name,c.page
      FROM memories m JOIN documents d ON d.id=m.document_id
      JOIN chunks c ON c.document_id=m.document_id AND c.ordinal=m.ordinal
      WHERE m.agent_id=? ORDER BY m.created_at DESC,m.id LIMIT ? OFFSET ?''',
        [agentId, limit, offset],
      ))
        AutoMemoryRecord._(r),
    ];
  }

  AutoMemoryRecord? memoryRecord(String agentId, String id) {
    final rows = _db.select(
      '''SELECT m.*,d.name AS source_name,c.page
      FROM memories m JOIN documents d ON d.id=m.document_id
      JOIN chunks c ON c.document_id=m.document_id AND c.ordinal=m.ordinal
      WHERE m.agent_id=? AND m.id=?''',
      [agentId, id],
    );
    return rows.isEmpty ? null : AutoMemoryRecord._(rows.single);
  }

  /// Only explicit user confirmation makes a memory available to RAG.
  /// Confirmation is still an attributed assertion, never external verification.
  List<MemoryHit> searchMemories(String agentId,List<double> vector,
    {int topK=3,double minSimilarity=0.65}) {
    _validateVector(vector);
    if(topK<1 || topK>20 || !minSimilarity.isFinite || minSimilarity< -1 || minSimilarity>1) {
      throw ArgumentError('Paramètres de recherche invalides');
    }
    final hits=<MemoryHit>[];
    final qnorm=math.sqrt(vector.fold(0.0,(s,v)=>s+v*v));
    final query=_db.prepare('''SELECT m.*,d.name,c.page FROM memories m
      JOIN documents d ON d.id=m.document_id
      JOIN chunks c ON c.document_id=m.document_id AND c.ordinal=m.ordinal
      WHERE m.agent_id=? AND m.status='user_confirmed' ORDER BY m.id''');
    try {
      final cursor=query.selectCursor([agentId]);
      while(cursor.moveNext()) {
        final r=cursor.current;
        final v=(jsonDecode(r['vector'] as String) as List).cast<num>().map((n)=>n.toDouble()).toList();
        _validateVector(v);
        var dot=0.0;
        var norm=0.0;
        for(var i=0;i<dimension;i++) {dot+=vector[i]*v[i];norm+=v[i]*v[i];}
        final score=(dot/(qnorm*math.sqrt(norm))).clamp(-1.0,1.0);
        if(score<minSimilarity) continue;
        final correction=r['provenance']=='user_correction';
        final nature=r['kind']=='inference'?'déduction citée':'observation citée';
        hits.add(MemoryHit(agentId:agentId,documentId:r['document_id'] as String,
          name:'Souvenir ${r['id'].toString().substring(0,8)} • ${r['name']}',
          page:r['page'] as int,ordinal:r['ordinal'] as int,
          text:'${correction?'Correction de l’utilisateur':nature} ; confirmé par l’utilisateur, '
            'sans vérification externe${r['uncertain']==1?' ; incertitude signalée':''} : ${r['content']}',
          similarity:score));
        hits.sort((a,b)=>b.similarity.compareTo(a.similarity));
        if(hits.length>topK) hits.removeLast();
      }
    } finally {query.close();}
    return hits;
  }

  Row _memory(String agentId, String id) {
    final rows = _db.select(
      'SELECT * FROM memories WHERE agent_id=? AND id=?',
      [agentId, id],
    );
    if (rows.isEmpty) throw StateError('Souvenir absent pour cet agent.');
    return rows.single;
  }

  String addMemory({
    required String agentId,
    required String documentId,
    required int ordinal,
    required AutoMemoryCandidate candidate,
    required List<double> vector,
    required String extractor,
  }) {
    _validateVector(vector);
    candidate.validate(
      _source(agentId, documentId, ordinal)['content'] as String,
    );
    if (extractor.isEmpty || extractor.length > 200) {
      throw ArgumentError('Extracteur invalide');
    }
    final existing = _db.select(
      'SELECT id FROM memories WHERE agent_id=? AND document_id=? AND ordinal=? AND quote=?',
      [agentId, documentId, ordinal, candidate.quote],
    );
    if (existing.isNotEmpty) return existing.single['id'] as String;
    final total =
        _db.select('SELECT COUNT(*) AS n FROM memories WHERE agent_id=?', [
              agentId,
            ]).single['n']
            as int;
    if (total >= 1000) throw StateError('Limite : 1000 souvenirs par agent.');
    final id = sha256
        .convert(
          utf8.encode(
            jsonEncode([agentId, documentId, ordinal, candidate.quote]),
          ),
        )
        .toString();
    final now = DateTime.now().toUtc().toIso8601String();
    _transaction(() {
      _db.execute(
        'INSERT INTO memories VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          id,
          agentId,
          documentId,
          ordinal,
          candidate.quote,
          candidate.quote,
          candidate.kind,
          candidate.subject,
          candidate.relation,
          candidate.value,
          candidate.uncertain ? 1 : 0,
          'pending',
          extractor,
          'source_quote',
          1,
          now,
          now,
          jsonEncode(vector),
        ],
      );
      _snapshot(agentId, id);
      _linkSimilar(agentId, id, vector, candidate);
    });
    return id;
  }

  /// Cosine is only a suggestion, never a fact test or an automatic merge.
  void _linkSimilar(
    String agentId,
    String id,
    List<double> vector,
    AutoMemoryCandidate candidate,
  ) {
    final query = _db.prepare(
      'SELECT * FROM memories WHERE agent_id=? AND id<>?',
    );
    try {
      final cursor = query.selectCursor([agentId, id]);
      final suggestions = <({String id, String kind, double score})>[];
      final qnorm = math.sqrt(vector.fold(0.0, (s, v) => s + v * v));
      while (cursor.moveNext()) {
        final r = cursor.current;
        final v = (jsonDecode(r['vector'] as String) as List)
            .cast<num>()
            .map((n) => n.toDouble())
            .toList();
        _validateVector(v);
        var dot = 0.0;
        var norm = 0.0;
        for (var i = 0; i < dimension; i++) {
          dot += v[i] * vector[i];
          norm += v[i] * v[i];
        }
        final score = dot / (qnorm * math.sqrt(norm));
        final conflict =
            candidate.subject.isNotEmpty &&
            candidate.relation.isNotEmpty &&
            candidate.value.isNotEmpty &&
            r['subject'] == candidate.subject &&
            r['relation'] == candidate.relation &&
            r['slot_value'] != candidate.value &&
            (r['slot_value'] as String).isNotEmpty;
        if (conflict || score >= 0.88) {
          suggestions.add((
            id: r['id'] as String,
            kind: conflict ? 'possible_contradiction' : 'possible_duplicate',
            score: conflict ? 2 : score,
          ));
        }
      }
      suggestions.sort((a, b) => b.score.compareTo(a.score));
      // Bound link growth and UI noise; contradictory keys rank first.
      for (final s in suggestions.take(5)) {
        _link(id, s.id, s.kind);
        if (s.kind == 'possible_contradiction') {
          for (final target in [id, s.id]) {
            final old = _memory(agentId, target);
            if (old['status'] != 'review') {
              _db.execute(
                "UPDATE memories SET status='review',version=version+1,updated_at=? WHERE agent_id=? AND id=?",
                [DateTime.now().toUtc().toIso8601String(), agentId, target],
              );
              _snapshot(agentId, target);
            }
          }
        }
      }
    } finally {
      query.close();
    }
  }

  void _link(String a, String b, String kind) => _db.execute(
    'INSERT OR IGNORE INTO memory_links VALUES(?,?,?,?)',
    [a, b, kind, DateTime.now().toUtc().toIso8601String()],
  );

  List<({String otherId, String kind})> memoryLinks(
    String agentId,
    String id,
  ) => [
    for (final r in _db.select(
      '''SELECT CASE WHEN l.a=? THEN l.b ELSE l.a END AS other_id,l.kind
      FROM memory_links l JOIN memories a ON a.id=l.a JOIN memories b ON b.id=l.b
      WHERE (l.a=? OR l.b=?) AND a.agent_id=? AND b.agent_id=?
      ORDER BY l.kind,l.a,l.b''',
      [id, id, id, agentId, agentId],
    ))
      (otherId: r['other_id'] as String, kind: r['kind'] as String),
  ];

  /// Explicit consolidation keeps both records, their quotes and revisions.
  void groupMemories(String agentId, String id, String otherId) {
    _memory(agentId, id);
    _memory(agentId, otherId);
    if (id == otherId) throw ArgumentError('Deux souvenirs distincts attendus');
    final pair = [id, otherId]..sort();
    _link(pair.first, pair.last, 'user_grouped');
  }

  void _snapshot(String agentId, String id) {
    final r = _memory(agentId, id);
    _db.execute('INSERT INTO memory_revisions VALUES(?,?,?)', [
      id,
      r['version'],
      jsonEncode(Map<String, Object?>.from(r)),
    ]);
  }

  List<String> memoryHistory(String agentId, String id) => [
    for (final r in _db.select(
      '''SELECT r.snapshot FROM memory_revisions r JOIN memories m ON m.id=r.memory_id
      WHERE m.agent_id=? AND m.id=? ORDER BY r.version''',
      [agentId, id],
    ))
      r['snapshot'] as String,
  ];

  void correctMemory(
    String agentId,
    String id,
    String text,
    List<double> vector,
  ) {
    _memory(agentId, id);
    _validateVector(vector);
    if (text.trim().isEmpty || utf8.encode(text).length > 700) {
      throw ArgumentError('Correction : 1 à 700 octets UTF-8');
    }
    _transaction(() {
      _db.execute(
        "UPDATE memories SET content=?,vector=?,provenance='user_correction',status='pending',uncertain=1,subject='',relation='',slot_value='',version=version+1,updated_at=? WHERE agent_id=? AND id=?",
        [
          text.trim(),
          jsonEncode(vector),
          DateTime.now().toUtc().toIso8601String(),
          agentId,
          id,
        ],
      );
      // Embeddings and generated slots no longer describe the corrected text.
      _db.execute(
        "DELETE FROM memory_links WHERE (a=? OR b=?) AND kind<>'user_grouped'",
        [id, id],
      );
      _snapshot(agentId, id);
    });
  }

  void confirmMemory(String agentId, String id) {
    _memory(agentId, id);
    _transaction(() {
      _db.execute(
        "UPDATE memories SET status='user_confirmed',version=version+1,updated_at=? WHERE agent_id=? AND id=?",
        [DateTime.now().toUtc().toIso8601String(), agentId, id],
      );
      _snapshot(agentId, id);
    });
  }

  void deleteMemory(String agentId, String id) => _db.execute(
    'DELETE FROM memories WHERE agent_id=? AND id=?',
    [agentId, id],
  );

  void _transaction(void Function() action) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      action();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }
}
