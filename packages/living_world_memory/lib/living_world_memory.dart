import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:living_memory_core/living_memory_core.dart';
import 'package:world_contracts/world_contracts.dart';

export 'package:world_contracts/world_contracts.dart';

/// Adapter for the existing L1 MemoryPort. The trusted host fixes membership;
/// prompts, model replies and MCP tools never receive a database handle.
class LivingWorldMemory implements MemoryPort {
  LivingWorldMemory({required this.store, required this.worldId,
    required Set<String> agentIds, required this.embed})
      : agentIds = Set.unmodifiable(agentIds) {
    _id(worldId);
    if (agentIds.isEmpty || agentIds.length > 1000) throw const FormatException('Participants invalides.');
    for (final id in agentIds) {
      _id(id);
      final key = memoryAgentKey(worldId, id);
      if (!store.agents().any((a) => a.id == key)) store.createAgent(key, 'Monde $worldId · $id'.substring(0, math.min(100, 'Monde $worldId · $id'.length)));
    }
  }
  final MemoryStore store;
  final String worldId;
  final Set<String> agentIds;
  final Future<List<double>> Function(String text) embed;
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }
  static void _id(String id) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(id)) throw const FormatException('Identifiant invalide.');
  }
  void _member(String world, String agent) {
    if (world != worldId || !agentIds.contains(agent)) throw const FormatException('Portée du monde refusée.');
  }
  MemoryScope _scope(String agent) => MemoryScope(agentId: memoryAgentKey(worldId, agent), projectId: 'living-world', worldId: worldId);
  List<Map<String, dynamic>> _records(String namespace, {String? scope}) => [
    for (final r in store.extensionDatabase.select(
      'SELECT payload FROM lm_v14_records WHERE namespace=?${scope == null ? '' : ' AND scope_key=?'} ORDER BY record_id LIMIT 10000',
      [namespace, if (scope != null) scope]))
      jsonDecode(r['payload'] as String) as Map<String, dynamic>,
  ];
  void _put(String namespace, MemoryScope scope, String id, Map<String, dynamic> data) {
    store.extensionDatabase.execute('''INSERT INTO lm_v14_records(namespace,scope_key,record_id,agent_id,payload)
      VALUES(?,?,?,?,?) ON CONFLICT(namespace,scope_key,record_id) DO UPDATE SET payload=excluded.payload''',
      [namespace, scope.key, id, scope.agentId, jsonEncode(data)]);
  }
  static void _shape(Map<String, dynamic> data, Set<String> keys) {
    if (data.keys.toSet().difference(keys).isNotEmpty || data.length != keys.length || data['schemaVersion'] != 1) throw const FormatException('Contrat V1 invalide.');
  }
  @override
  Future<MemoryAck> ingest(PerceivedEvent event) => _serial(() async {
    final d = event.toJson();
    _shape(d, {'schemaVersion','worldId','agentId','eventId','tick','sourceRevision','kind','text','parentEventIds','observedBy'});
    if (utf8.encode(jsonEncode(d)).length > 16384) throw const FormatException('Événement trop grand.');
    final agent = d['agentId'];
    if (agent is! String || d['worldId'] is! String) throw const FormatException('Portée invalide.');
    _member(d['worldId'] as String, agent);
    if (d['eventId'] is! String) throw const FormatException('Événement invalide.');
    final eventId = d['eventId'] as String;
    _id(eventId);
    for (final field in ['tick','sourceRevision']) {
      if (d[field] is! int || (d[field] as int) < 0 || (d[field] as int) > 9007199254740991) throw const FormatException('Temps invalide.');
    }
    if (!['observation','declaration','hypothesis','inference'].contains(d['kind']) ||
        d['text'] is! String || (d['text'] as String).trim().isEmpty || utf8.encode(d['text'] as String).length > 4096 ||
        d['observedBy'] is! List || !(d['observedBy'] as List).contains(agent) ||
        (d['observedBy'] as List).length > 1000 || d['parentEventIds'] is! List || (d['parentEventIds'] as List).length > 20) throw const FormatException('Perception invalide.');
    for (final id in [...(d['observedBy'] as List), ...(d['parentEventIds'] as List)]) {
      if (id is! String) throw const FormatException('Référence invalide.');
      _id(id);
    }
    final scope = _scope(agent);
    final digest = sha256.convert(utf8.encode(canonicalJson(d))).toString();
    final receipts = store.extensionDatabase.select('SELECT payload FROM lm_v14_records WHERE namespace=? AND scope_key=? AND record_id=?', ['world.event',scope.key,eventId]);
    final previous = receipts.isEmpty ? null : jsonDecode(receipts.single['payload'] as String) as Map<String,dynamic>;
    if (previous != null) {
      if (previous['digest'] != digest) throw const FormatException('Événement déjà lié à un autre contenu.');
      return MemoryAck({'eventId': eventId, 'agentId': agent, 'status': 'already_present', 'sourceId': previous['sourceId']});
    }
    if (_records('world.event', scope: scope.key).length >= 10000) throw StateError('Limite de souvenirs atteinte. Export requis.');
    final vector = await embed(d['text'] as String);
    late String source;
    store.extensionTransaction(() {
      source = store.addDocument(agentId: scope.agentId, name: 'Monde · ${d['kind']} · tick ${d['tick']}', digest: digest,
        chunks: [MemoryChunk(page: 1, ordinal: 1, text: d['text'] as String)], vectors: [vector],
        kind: 'world_${d['kind']}', projectId: scope.projectId, worldId: worldId);
      _put('world.event', scope, eventId, {...d, 'digest': digest, 'sourceId': source, 'writtenAtUtc': DateTime.now().toUtc().toIso8601String(), 'deleted': false});
    });
    return MemoryAck({'eventId': eventId, 'agentId': agent, 'status': 'accepted', 'sourceId': source});
  });

  /// Call only after the host has committed this checkpoint. Retrying the same
  /// snapshot after a process restart reuses the durable event receipts.
  Future<void> ingestSnapshot(WorldSnapshot snapshot) async {
    if (snapshot.state.worldId != worldId) throw const FormatException('Autre monde.');
    for (final e in snapshot.state.eventLog) {
      for (final agent in e.observedBy.where(agentIds.contains)) {
        await ingest(PerceivedEvent({'schemaVersion': 1, 'worldId': worldId, 'agentId': agent,
          'eventId': e.data['eventId'], 'tick': e.tick, 'sourceRevision': e.toJson()['revision'],
          'kind': 'observation', 'text': '${e.toJson()['kind']} ${canonicalJson(e.toJson()['payload'])}',
          'parentEventIds': <String>[], 'observedBy': e.observedBy}));
      }
    }
  }

  @override
  Future<List<MemoryReference>> recall(RecallQuery query) => _serial(() async {
    final q = query.toJson();
    _shape(q, {'schemaVersion','worldId','agentId','text','topK','contextBudgetBytes'});
    if (q['agentId'] is! String || q['worldId'] is! String) throw const FormatException('Portée invalide.');
    final agent = q['agentId'] as String;
    _member(q['worldId'] as String, agent);
    final top = q['topK'], budget = q['contextBudgetBytes'], text = q['text'];
    if (top is! int || top < 1 || top > 20 || budget is! int || budget < 1 || budget > 65536 || text is! String || text.trim().isEmpty || utf8.encode(text).length > 4096) throw const FormatException('Recherche invalide.');
    final own = _records('world.event', scope: _scope(agent).key);
    final candidates = <({Map<String, dynamic> event, bool shared})>[
      for (final r in own) (event: r, shared: false),
    ];
    // Apply explicit ACLs before fetching or scoring a source owned by another agent.
    for (final share in _records('world.share.$worldId')) {
      if (!(share['recipients'] as List).contains(agent) || share['owner'] == agent) continue;
      for (final r in _records('world.event', scope: _scope(share['owner'] as String).key)) {
        if (r['sourceId'] == share['sourceId']) candidates.add((event: r, shared: true));
      }
    }
    final vector = await embed(text);
    if (vector.length != store.dimension || vector.any((v) => !v.isFinite) || vector.every((v) => v == 0)) throw const FormatException('Vecteur incompatible.');
    final results = <({Map<String, dynamic> event, bool shared, double score})>[];
    for (final candidate in candidates) {
      final r = candidate.event;
      if (r['deleted'] == true) continue;
      final scope = _scope(r['agentId'] as String);
      final rows = store.extensionDatabase.select('''SELECT c.content,c.vector FROM chunks c JOIN documents d ON d.id=c.document_id
        WHERE d.id=? AND d.agent_id=? AND d.project_id=? AND d.world_id=?''', [r['sourceId'], scope.agentId, scope.projectId, worldId]);
      if (rows.isEmpty) continue;
      final stored = (jsonDecode(rows.single['vector'] as String) as List).cast<num>();
      var dot = 0.0, a = 0.0, b = 0.0;
      for (var i=0; i<vector.length; i++) { dot += vector[i] * stored[i]; a += vector[i]*vector[i]; b += stored[i]*stored[i]; }
      final cosine = dot / math.sqrt(a*b);
      final lexical = (r['text'] as String).toLowerCase().contains(text.toLowerCase());
      if (cosine >= 0.65 || lexical) results.add((event:r, shared:candidate.shared, score: cosine + (lexical ? 1 : 0)));
    }
    results.sort((a,b) { final c = b.score.compareTo(a.score); return c == 0 ? (a.event['sourceId'] as String).compareTo(b.event['sourceId'] as String) : c; });
    var used = 0;
    final output = <MemoryReference>[];
    for (final r in results) {
      final size = utf8.encode(r.event['text'] as String).length;
      if (used+size > budget || output.length >= top) continue;
      used += size;
      output.add(MemoryReference({'memoryId':r.event['sourceId'],'sourceEventIds':[r.event['eventId']],
        'tick':r.event['tick'],'kind':r.event['kind'],'status':r.shared ? 'shared_${r.event['kind']}' : r.event['kind'] == 'observation' ? 'engine_observed' : 'unverified_${r.event['kind']}',
        'text':r.event['text'],'score':r.score,'version':1}));
    }
    return List.unmodifiable(output);
  });

  Future<void> publish({required String agentId, required String sourceId, required Set<String> recipients}) => _serial(() async {
    _member(worldId, agentId);
    if (recipients.isEmpty || recipients.length > agentIds.length) throw const FormatException('Destinataires invalides.');
    for (final id in recipients) { _member(worldId, id); }
    final record = _records('world.event', scope: _scope(agentId).key).where((r) => r['sourceId'] == sourceId && r['deleted'] != true).firstOrNull;
    if (record == null) throw const FormatException('Source privée introuvable.');
    _put('world.share.$worldId', _scope(agentId), sourceId, {'sourceId':sourceId,'owner':agentId,'recipients':recipients.toList()..sort()});
  });
  Future<void> revoke({required String agentId, required String sourceId}) => _serial(() async {
    _member(worldId, agentId);
    store.extensionDatabase.execute('DELETE FROM lm_v14_records WHERE namespace=? AND scope_key=? AND record_id=?', ['world.share.$worldId',_scope(agentId).key,sourceId]);
  });
  @override
  Future<void> delete(ScopedMemoryId id) => _serial(() async {
    _member(id.worldId, id.agentId);
    final scope = _scope(id.agentId);
    final event = _records('world.event', scope: scope.key).where((r) => r['sourceId'] == id.memoryId).firstOrNull;
    if (event == null) return;
    store.extensionTransaction(() {
      store.deleteDocument(scope.agentId, id.memoryId);
      _put('world.event', scope, event['eventId'] as String, {...event,'deleted':true});
      store.extensionDatabase.execute('DELETE FROM lm_v14_records WHERE namespace=? AND scope_key=? AND record_id=?', ['world.share.$worldId',scope.key,id.memoryId]);
    });
  });
  @override
  Future<MemoryHealth> health() async {
    try { store.extensionDatabase.select('SELECT 1'); return const MemoryHealth('ready'); }
    catch (_) { return const MemoryHealth('unavailable',reason:'Mémoire inaccessible.'); }
  }
}
