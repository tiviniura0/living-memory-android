import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

class MemoryChunk {
  const MemoryChunk({
    required this.page,
    required this.ordinal,
    required this.text,
  });
  final int page;
  final int ordinal;
  final String text;
}

class MemoryHit {
  const MemoryHit({
    required this.agentId,
    required this.documentId,
    required this.name,
    required this.page,
    required this.ordinal,
    required this.text,
    required this.similarity,
  });
  final String agentId;
  final String documentId;
  final String name;
  final int page;
  final int ordinal;
  final String text;
  final double similarity;
}

/// Independent private database: never opens or migrates the demo's kb.db.
/// All corpus reads/deletes require an agent. No global search API exists.
class MemoryStore {
  MemoryStore._(this._db, this.dimension);
  final Database _db;
  final int dimension;
  bool _closed = false;

  static MemoryStore open(
    String path, {
    required String profile,
    required int dimension,
  }) {
    if (dimension < 1 || profile.isEmpty)
      throw ArgumentError('Invalid embedding profile');
    final db = sqlite3.open(path);
    try {
      db.execute('PRAGMA foreign_keys = ON');
      db.execute('PRAGMA secure_delete = ON');
      db.execute(
        'CREATE TABLE IF NOT EXISTS profile (id INTEGER PRIMARY KEY CHECK(id=1), name TEXT NOT NULL, dimension INTEGER NOT NULL)',
      );
      final current = db.select(
        'SELECT name, dimension FROM profile WHERE id=1',
      );
      if (current.isNotEmpty &&
          (current.first['name'] != profile ||
              current.first['dimension'] != dimension)) {
        throw StateError(
          'Profil incompatible : aucune donnée effacée. Réindexation explicite nécessaire.',
        );
      }
      db.execute('INSERT OR IGNORE INTO profile VALUES (1, ?, ?)', [
        profile,
        dimension,
      ]);
      db.execute(
        'CREATE TABLE IF NOT EXISTS agents (id TEXT PRIMARY KEY, name TEXT NOT NULL)',
      );
      db.execute('''CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY, agent_id TEXT NOT NULL REFERENCES agents(id),
        name TEXT NOT NULL, digest TEXT NOT NULL, kind TEXT NOT NULL,
        created_at TEXT NOT NULL, UNIQUE(agent_id, digest))''');
      db.execute('''CREATE TABLE IF NOT EXISTS chunks (
        document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        page INTEGER NOT NULL, ordinal INTEGER NOT NULL, content TEXT NOT NULL,
        vector TEXT NOT NULL, PRIMARY KEY(document_id, ordinal))''');
      db.execute(
        'CREATE INDEX IF NOT EXISTS documents_agent ON documents(agent_id)',
      );
      return MemoryStore._(db, dimension);
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  void createAgent(String id, String name) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(id) ||
        name.trim().isEmpty ||
        name.length > 100) {
      throw ArgumentError(
        'Identifiant : lettres, chiffres, tiret ou soulignement (1–64).',
      );
    }
    _db.execute('INSERT INTO agents(id, name) VALUES (?, ?)', [
      id,
      name.trim(),
    ]);
  }

  List<({String id, String name})> agents() => [
    for (final row in _db.select('SELECT id, name FROM agents ORDER BY name'))
      (id: row['id'] as String, name: row['name'] as String),
  ];

  List<({String id, String name, String kind, int chunks})> documents(
    String agentId,
  ) => [
    for (final row in _db.select(
      '''SELECT d.id, d.name, d.kind, COUNT(c.ordinal) AS chunks
      FROM documents d LEFT JOIN chunks c ON c.document_id=d.id
      WHERE d.agent_id=? GROUP BY d.id ORDER BY d.created_at DESC''',
      [agentId],
    ))
      (
        id: row['id'] as String,
        name: row['name'] as String,
        kind: row['kind'] as String,
        chunks: row['chunks'] as int,
      ),
  ];

  /// Vectors are prepared before the transaction. An interrupted import
  /// cannot leave a partially indexed document. No asynchronous work here.
  String addDocument({
    required String agentId,
    required String name,
    required String digest,
    required List<MemoryChunk> chunks,
    required List<List<double>> vectors,
    String kind = 'document',
  }) {
    if (name.trim().isEmpty ||
        digest.isEmpty ||
        chunks.isEmpty ||
        chunks.length != vectors.length ||
        chunks.length > 10000) {
      throw ArgumentError('Invalid document or embeddings');
    }
    for (final vector in vectors) {
      _validateVector(vector);
    }
    if (chunks.any(
      (c) => c.page < 1 || c.ordinal < 1 || c.text.trim().isEmpty,
    )) {
      throw ArgumentError('Invalid passage');
    }
    final existing = _db.select(
      'SELECT id FROM documents WHERE agent_id=? AND digest=?',
      [agentId, digest],
    );
    if (existing.isNotEmpty) return existing.first['id'] as String;
    final total =
        _db
                .select(
                  '''SELECT COUNT(*) AS n FROM chunks c JOIN documents d ON d.id=c.document_id
      WHERE d.agent_id=?''',
                  [agentId],
                )
                .first['n']
            as int;
    if (total + chunks.length > 10000)
      throw StateError('Limite V1 : 10 000 passages par agent.');
    final id = sha256.convert(utf8.encode('$agentId\n$digest')).toString();
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute('INSERT INTO documents VALUES (?, ?, ?, ?, ?, ?)', [
        id,
        agentId,
        name,
        digest,
        kind,
        DateTime.now().toUtc().toIso8601String(),
      ]);
      final insert = _db.prepare('INSERT INTO chunks VALUES (?, ?, ?, ?, ?)');
      try {
        for (var i = 0; i < chunks.length; i++) {
          final c = chunks[i];
          insert.execute([
            id,
            c.page,
            c.ordinal,
            c.text,
            jsonEncode(vectors[i]),
          ]);
        }
      } finally {
        insert.close();
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
    return id;
  }

  List<MemoryHit> search(
    String agentId,
    List<double> vector, {
    int topK = 3,
    double minSimilarity = 0.65,
  }) {
    _validateVector(vector);
    if (topK < 1 ||
        topK > 20 ||
        !minSimilarity.isFinite ||
        minSimilarity < -1 ||
        minSimilarity > 1) {
      throw ArgumentError('Invalid search parameters');
    }
    final queryNorm = math.sqrt(vector.fold(0.0, (s, v) => s + v * v));
    final hits = <MemoryHit>[];
    // The WHERE clause is applied before ranking, not after a global top-k.
    final query = _db.prepare(
      '''SELECT d.id, d.name, c.page, c.ordinal, c.content, c.vector
      FROM chunks c JOIN documents d ON d.id=c.document_id WHERE d.agent_id=?''',
    );
    try {
      final cursor = query.selectCursor([agentId]);
      while (cursor.moveNext()) {
        final row = cursor.current;
        final stored = (jsonDecode(row['vector'] as String) as List)
            .cast<num>()
            .map((v) => v.toDouble())
            .toList();
        _validateVector(stored);
        var dot = 0.0, norm = 0.0;
        for (var i = 0; i < dimension; i++) {
          dot += vector[i] * stored[i];
          norm += stored[i] * stored[i];
        }
        final similarity = (dot / (queryNorm * math.sqrt(norm))).clamp(
          -1.0,
          1.0,
        );
        if (similarity < minSimilarity) continue;
        hits.add(
          MemoryHit(
            agentId: agentId,
            documentId: row['id'] as String,
            name: row['name'] as String,
            page: row['page'] as int,
            ordinal: row['ordinal'] as int,
            text: row['content'] as String,
            similarity: similarity,
          ),
        );
        hits.sort((a, b) => b.similarity.compareTo(a.similarity));
        if (hits.length > topK) hits.removeLast();
      }
    } finally {
      query.close();
    }
    return hits;
  }

  void deleteDocument(String agentId, String id) => _db.execute(
    'DELETE FROM documents WHERE agent_id=? AND id=?',
    [agentId, id],
  );

  void _validateVector(List<double> vector) {
    if (vector.length != dimension ||
        vector.any((v) => !v.isFinite) ||
        vector.every((v) => v == 0) ||
        !vector.fold(0.0, (s, v) => s + v * v).isFinite) {
      throw ArgumentError('Vecteur incompatible, nul ou non fini');
    }
  }

  void close() {
    if (!_closed) {
      _closed = true;
      _db.close();
    }
  }
}
