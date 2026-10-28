import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_edge_ai_agent/flutter_edge_ai_agent.dart' show parseSkillMd, SkillType;
import 'package:living_memory_extensions/living_memory_extensions.dart' as ext;

import 'memory_store.dart';
import 'module_contracts.dart';

/// Built-in scoped reading only. Reuses the existing SKILL.md parser;
/// no instructions or generated text grant a telephone intent.
class ExtensionsPanel extends StatefulWidget {
  const ExtensionsPanel({super.key, required this.store, required this.scope, this.loadSkill, this.loadPlugin});
  final MemoryStore store;
  final MemoryScope scope;
  final Future<String> Function()? loadSkill;
  final Future<Map<String,Object?>> Function()? loadPlugin;
  @override
  State<ExtensionsPanel> createState() => _ExtensionsPanelState();
}
class _ExtensionsPanelState extends State<ExtensionsPanel> {
  final _query = TextEditingController();
  final _security = ext.SecurityManager();
  late final ext.ExtensionScope _scope;
  late final ext.MissionQueue _queue;
  late final ext.ToolRegistry _tools;
  ext.ApprovedPlugin? _plugin;
  ext.ApprovedInstructions? _skill;
  String? _approvedSkill;
  bool _busy = true;
  String _status = 'Chargement des extensions locales…';
  String _output = '';
  List<String> _missionStates = [];
  bool get _approved => _skill?.matchesApproval(_approvedSkill ?? '') ?? false;

  @override
  void initState() {
    super.initState();
    _scope = ext.ExtensionScope(userId:widget.scope.userId,agentId:widget.scope.agentId,
      projectId:widget.scope.projectId.isEmpty ? 'personal' : widget.scope.projectId,
      worldId:widget.scope.worldId.isEmpty ? 'no-world' : widget.scope.worldId);
    _queue = ext.MissionQueue(widget.store.extensionDatabase);
    _tools = ext.ToolRegistry(security:_security);
    unawaited(_load());
  }
  Future<void> _load() => _run(() async {
    final text = await (widget.loadSkill ?? () => rootBundle.loadString('assets/living_memory/skills/memory-scope/SKILL.md'))();
    if (utf8.encode(text).length > 4096) { throw const FormatException('Skill trop grand.'); }
    final parsed = parseSkillMd(text);
    if (parsed.type != SkillType.textOnly) { throw const ext.ExtensionDenied(); }
    _skill = ext.ApprovedInstructions(id:parsed.name,instructions:parsed.instructions,
      catalogFingerprint:sha256.convert(utf8.encode(text)).toString());
    final manifest = await (widget.loadPlugin ?? () async => Map<String,Object?>.from(
      jsonDecode(await rootBundle.loadString('assets/living_memory/plugins/memory.json')) as Map<String,dynamic>))();
    final plugin = ext.ApprovedPlugin.fromManifest(manifest);
    if (plugin.id != 'local-memory' || !plugin.tools.contains('memory.read')) { throw const ext.ExtensionDenied(); }
    _plugin = plugin;
    _tools.register(plugin:plugin,tool:'memory.read',invoke:(request) async {
      if (request.scope.key != _scope.key || request.arguments.length != 1 || request.arguments['query'] is! String) { throw const ext.ExtensionDenied(); }
      final query = request.arguments['query']! as String;
      if (query.trim().isEmpty || utf8.encode(query).length > 4096) { throw const ext.ExtensionDenied(); }
      final hits = widget.store.searchText(widget.scope.agentId,query,projectId:widget.scope.projectId,worldId:widget.scope.worldId);
      return {'passages':[for (final hit in hits) {'sourceId':hit.documentId,'text':hit.text}]};
    });
    _status = 'Skill à approuver. MCP désactivé : aucun serveur configuré.';
    _refreshMissions();
  });
  Future<void> _run(Future<void> Function() action) async {
    if (mounted) { setState(() => _busy = true); }
    try { await action(); }
    catch (_) { _status = 'Extension refusée ou interrompue. Aucun droit supplémentaire accordé.'; }
    finally { if (mounted) { setState(() => _busy = false); } }
  }
  ext.ExtensionRequest _request(String query) {
    if (!_approved) { throw const ext.ExtensionDenied(); }
    return ext.ExtensionRequest(scope:_scope,tool:'memory.read',arguments:{'query':query},pluginHash:_plugin!.fingerprint);
  }
  Future<void> _authorizeRead(String query) async {
    final request = _request(query);
    final grant = _security.approve(request,expiresAt:DateTime.now().add(const Duration(minutes:1)));
    final result = await _tools.invoke(request,grant);
    final passages = result['passages']! as List<Object?>;
    _output = passages.map((row) => (row! as Map<String,Object?>)['text']! as String).join('\n');
    _status = '${passages.length} passage(s) de la portée autorisée. Accord consommé.';
  }
  void _refreshMissions() {
    _missionStates = [for (final row in widget.store.extensionDatabase.select(
      'SELECT id,state FROM lm_v14_missions WHERE scope_json=? ORDER BY due_at DESC LIMIT 8',[_scope.key]))
      '${row['id']} · ${row['state']}'];
  }
  @override
  void dispose() { _query.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => PopScope(canPop:!_busy,child:Scaffold(
    appBar:AppBar(title:const Text('Extensions et missions locales')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('Le Skill donne des instructions. Chaque lecture exige ton accord ; aucun outil téléphone ni serveur distant activé.'),
      if (_skill != null) SelectableText(_skill!.instructions),
      OutlinedButton(onPressed:!_busy && _skill != null ? () => setState(() {
        _approvedSkill = _skill!.fingerprint; _status='Instantané du Skill approuvé.';
      }) : null,child:const Text('Approuver ce Skill')),
      TextField(key:const Key('extension-query'),controller:_query,maxLength:1024,decoration:const InputDecoration(labelText:'Recherche dans cette mémoire')),
      FilledButton(onPressed:!_busy && _approved ? () => _run(() => _authorizeRead(_query.text)) : null,child:const Text('Autoriser cette lecture')),
      OutlinedButton(onPressed:!_busy && _approved ? () => _run(() async {
        _request(_query.text);
        _queue.enqueue(id:'read_${DateTime.now().microsecondsSinceEpoch}',scope:_scope,dueAt:DateTime.now(),steps:[{'query':_query.text}]);
        _refreshMissions(); _status='Lecture planifiée au premier plan ; accord requis à son exécution.';
      }) : null,child:const Text('Planifier cette lecture')),
      OutlinedButton(onPressed:!_busy && _approved ? () => _run(() async {
        await _queue.runDue(scope:_scope,execute:(mission,step) => _authorizeRead(step['query']! as String));
        _refreshMissions();
      }) : null,child:const Text('Autoriser les lectures planifiées')),
      for (final mission in _missionStates) Text(mission),
      if (_busy) const LinearProgressIndicator(),
      Semantics(liveRegion:true,child:Text(_status)),
      if (_output.isNotEmpty) SelectableText(_output),
    ]),
  ));
}
