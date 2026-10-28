import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'auto_memory_candidate.dart';
import 'encrypted_database.dart';

part 'auto_memory_store.dart';
part 'context_store.dart';
part 'session_retrieval_store.dart';
part 'extension_store.dart';

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

/// UI-independent repository contract. Existing SQLite implementation and
/// schema are retained for Living World AI adapters.
abstract interface class MemoryRepository {
  int get dimension;
  void createAgent(String id, String name);
  List<({String id, String name})> agents();
  List<({String id, String name, String kind, int chunks})> documents(
    String agentId, {
    String projectId = '',
    String worldId = '',
  });
  String addDocument({
    required String agentId,
    required String name,
    required String digest,
    required List<MemoryChunk> chunks,
    required List<List<double>> vectors,
    String kind = 'document',
    String projectId = '',
    String worldId = '',
  });
  List<MemoryHit> search(
    String agentId,
    List<double> vector, {
    int topK = 3,
    double minSimilarity = 0.65,
    String projectId = '',
    String worldId = '',
  });
  void deleteDocument(String agentId, String id);
}

/// Independent private database: never opens or migrates the demo's kb.db.
/// All corpus reads/deletes require an agent. No global search API exists.
class MemoryStore implements MemoryRepository {
  static const schemaVersion = 5;
  MemoryStore._(this._db, this.dimension);
  final Database _db;
  @override
  final int dimension;
  bool _closed = false;

  static MemoryStore open(
    String path, {
    required String profile,
    required int dimension,
    String? encryptionKey,
  }) {
    if (dimension < 1 || profile.isEmpty) {
      throw ArgumentError('Invalid embedding profile');
    }
    if (Platform.isAndroid && encryptionKey == null && path != ':memory:') {
      throw StateError('Clé Android requise.');
    }
    final db = encryptionKey == null
        ? sqlite3.open(path)
        : EncryptedMemoryDatabase.open(path, encryptionKey);
    try {
      if ((db.select('PRAGMA user_version').first.values.first as int) >
          schemaVersion) {
        throw StateError('Version SQLite future : aucune migration autorisée.');
      }
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
      _migrateAutoMemory(db);
      _migrateLifecycle(db);
      _migrateSessionRetrieval(db);
      _migrateExtensions(db);
      db.execute('PRAGMA temp_store=MEMORY');
      for (final table in ['chunk_fts', 'session_fts']) {
        db.execute("INSERT INTO $table($table,rank) VALUES('secure-delete',1)");
      }
      return MemoryStore._(db, dimension);
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  @override
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

  @override
  List<({String id, String name})> agents() => [
    for (final row in _db.select('SELECT id, name FROM agents ORDER BY name'))
      (id: row['id'] as String, name: row['name'] as String),
  ];

  @override
  List<({String id, String name, String kind, int chunks})> documents(
    String agentId, {
    String projectId = '',
    String worldId = '',
  }) => [
    for (final row in _db.select(
      '''SELECT d.id, d.name, d.kind, COUNT(c.ordinal) AS chunks
      FROM documents d LEFT JOIN chunks c ON c.document_id=d.id
      WHERE d.agent_id=? AND d.project_id=? AND d.world_id=? GROUP BY d.id ORDER BY d.created_at DESC''',
      [agentId, projectId, worldId],
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
  @override
  String addDocument({
    required String agentId,
    required String name,
    required String digest,
    required List<MemoryChunk> chunks,
    required List<List<double>> vectors,
    String kind = 'document',
    String projectId = '',
    String worldId = '',
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
    if (projectId.length > 100 || worldId.length > 100) {
      throw ArgumentError('Portée invalide');
    }
    final scopedDigest = projectId.isEmpty && worldId.isEmpty
        ? digest
        : sha256
              .convert(utf8.encode(jsonEncode([projectId, worldId, digest])))
              .toString();
    final existing = _db.select(
      'SELECT id FROM documents WHERE agent_id=? AND digest=?',
      [agentId, scopedDigest],
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
    if (total + chunks.length > 10000) {
      throw StateError('Limite V1 : 10 000 passages par agent.');
    }
    final id = sha256
        .convert(utf8.encode('$agentId\n$scopedDigest'))
        .toString();
    _transaction(() {
      _db.execute(
        'INSERT INTO documents(id,agent_id,name,digest,kind,created_at,project_id,world_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          agentId,
          name,
          scopedDigest,
          kind,
          DateTime.now().toUtc().toIso8601String(),
          projectId,
          worldId,
        ],
      );
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
    });
    return id;
  }

  @override
  List<MemoryHit> search(
    String agentId,
    List<double> vector, {
    int topK = 3,
    double minSimilarity = 0.65,
    String projectId = '',
    String worldId = '',
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
      FROM chunks c JOIN documents d ON d.id=c.document_id WHERE d.agent_id=? AND d.project_id=? AND d.world_id=?''',
    );
    try {
      final cursor = query.selectCursor([agentId, projectId, worldId]);
      while (cursor.moveNext()) {
        final row = cursor.current;
        final stored = (jsonDecode(row['vector'] as String) as List)
            .cast<num>()
            .map((v) => v.toDouble())
            .toList();
        _validateVector(stored);
        var dot = 0.0;
        var norm = 0.0;
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

  @override
  void deleteDocument(String agentId, String id) => _db.execute(
    'DELETE FROM documents WHERE agent_id=? AND id=?',
    [agentId, id],
  );

  /// Deletes every project/world of this agent, including archives, revisions
  /// and decisions. Model files and other agents are independent.
  void deleteAgent(String agentId) {
    _transaction(() {
      _db.execute('DELETE FROM documents WHERE agent_id=?', [agentId]);
      _db.execute('DELETE FROM context_sessions WHERE agent_id=?', [agentId]);
      _db.execute('DELETE FROM auto_settings WHERE agent_id=?', [agentId]);
      _db.execute('DELETE FROM agents WHERE id=?', [agentId]);
    });
  }

  void _validateVector(List<double> vector) {
    final normSquared = vector.fold(0.0, (s, v) => s + v * v);
    if (vector.length != dimension ||
        vector.any((v) => !v.isFinite) ||
        vector.every((v) => v == 0) ||
        (!normSquared.isFinite || normSquared <= 0)) {
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
