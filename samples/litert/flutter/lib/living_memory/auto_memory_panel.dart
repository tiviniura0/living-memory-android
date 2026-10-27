import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'memory_store.dart';

/// Review stays separate from the V1 source list and question flow.
class AutoMemoryPanel extends StatefulWidget {
  const AutoMemoryPanel({
    super.key,
    required this.store,
    required this.agentId,
    required this.busy,
    required this.run,
    required this.embed,
    required this.process,
    this.cancelled,
  });
  final bool Function()? cancelled;
  final MemoryStore store;
  final String agentId;
  final bool busy;
  final Future<void> Function(Future<void> Function()) run;
  final Future<List<double>> Function(String) embed;
  final Future<void> Function(String) process;
  @override
  State<AutoMemoryPanel> createState() => _AutoMemoryPanelState();
}

class _AutoMemoryPanelState extends State<AutoMemoryPanel> {
  int _offset = 0;
  Future<void> _perform(Future<void> Function() action) async {
    await widget.run(action);
    if (mounted) setState(() {});
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _edit(AutoMemoryRecord m) async {
    final controller = TextEditingController(text: m.text);
    String? text;
    try {
      text = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Corriger le souvenir'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            maxLength: 700,
            decoration: const InputDecoration(
              labelText: 'Correction (700 octets UTF-8 maximum)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
    if (text == null || text.isEmpty || !mounted || (widget.cancelled?.call() ?? false)) return;
    final vector = await widget.embed(text);
    if (!mounted || (widget.cancelled?.call() ?? false)) return;
    widget.store.correctMemory(widget.agentId, m.id, text, vector);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final agent = widget.agentId;
    final enabled = store.autoMemoryEnabled(agent);
    final memories = store.memories(agent, limit: 20, offset: _offset);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mémorisation automatique'),
          subtitle: const Text(
            'Extrait des citations des prochains imports et notes. Désactivée par défaut. Aucune réponse IA enregistrée.',
          ),
          value: enabled,
          onChanged: widget.busy
              ? null
              : (value) {
                  store.setAutoMemoryEnabled(agent, enabled: value);
                  setState(() {});
                },
        ),
        const Text(
          'Souvenirs • affirmations sourcées, sans vérification externe',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        if (memories.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Aucun souvenir sur cette page. Active la mémorisation puis importe une source, ou reprends une source existante.',
            ),
          ),
        for (final m in memories)
          Card(
            key: ValueKey(m.id),
            child: ExpansionTile(
              title: Text(m.text),
              subtitle: Text(
                '${m.kind == 'inference' ? 'Déduction citée' : 'Observation citée'} • ${_status(m.status)}${m.uncertain ? ' • incertitude signalée' : ''}',
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectableText(
                        'Source : ${m.sourceName}\nPage ${m.page} • passage ${m.ordinal}\nAgent : ${m.agentId}\nCréé : ${m.createdAt}\nModifié : ${m.updatedAt}\nVersion ${m.version}\nExtraction : ${m.extractor}',
                      ),
                      const SizedBox(height: 8),
                      SelectableText('Citation d’origine : « ${m.quote} »'),
                      if (m.provenance == 'user_correction')
                        const Text(
                          'Texte corrigé par l’utilisateur ; la citation d’origine reste conservée.',
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: widget.busy
                                ? null
                                : () => unawaited(
                                    _perform(() async {
                                      if (await _confirm(
                                        'Confirmer ce souvenir ?',
                                        'Cette action indique ta confirmation personnelle. Elle ne constitue pas une vérification externe et ne résout pas les liens de contradiction.',
                                      )) {
                                        if (!mounted) return;
                                        store.confirmMemory(agent, m.id);
                                      }
                                    }),
                                  ),
                            child: const Text('Confirmer'),
                          ),
                          OutlinedButton(
                            onPressed: widget.busy
                                ? null
                                : () => unawaited(_perform(() => _edit(m))),
                            child: const Text('Corriger'),
                          ),
                          TextButton(
                            onPressed: widget.busy
                                ? null
                                : () => unawaited(
                                    _perform(() async {
                                      if (await _confirm(
                                        'Supprimer ce souvenir ?',
                                        'Le souvenir, ses versions et ses liens seront effacés. La source reste conservée.',
                                      )) {
                                        if (!mounted) return;
                                        store.deleteMemory(agent, m.id);
                                      }
                                    }),
                                  ),
                            child: const Text('Supprimer'),
                          ),
                        ],
                      ),
                      for (final link in store.memoryLinks(agent, m.id)) ...[
                        const Divider(),
                        Text(switch (link.kind) {
                          'possible_contradiction' =>
                            'Contradiction possible • clé proposée par Gemma',
                          'user_grouped' =>
                            'Regroupement confirmé par l’utilisateur',
                          _ => 'Doublon possible • similarité non calibrée',
                        }),
                        SelectableText(
                          store.memoryRecord(agent, link.otherId)?.text ??
                              'Souvenir indisponible',
                        ),
                        if (link.kind != 'user_grouped')
                          TextButton(
                            onPressed: widget.busy
                                ? null
                                : () => unawaited(
                                    _perform(() async {
                                      if (await _confirm(
                                        'Regrouper ces souvenirs ?',
                                        'Les deux textes, leurs sources et leurs versions sont conservés. Ce regroupement ne valide aucun fait et ne résout aucune contradiction.',
                                      )) {
                                        if (!mounted) return;
                                        store.groupMemories(
                                          agent,
                                          m.id,
                                          link.otherId,
                                        );
                                      }
                                    }),
                                  ),
                            child: const Text('Regrouper'),
                          ),
                      ],
                      ExpansionTile(
                        title: const Text('Historique des versions'),
                        children: [
                          for (final snapshot in store.memoryHistory(
                            agent,
                            m.id,
                          ))
                            Builder(
                              builder: (context) {
                                final data = jsonDecode(
                                  snapshot,
                                ) as Map<String, dynamic>;
                                return ListTile(
                                  title: Text(data['content'] as String),
                                  subtitle: Text(
                                    'Version ${data['version']} • ${_status(data['status'] as String)}\n${data['updated_at']}',
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: !widget.busy && _offset > 0
                  ? () => setState(() => _offset -= 20)
                  : null,
              child: const Text('Précédents'),
            ),
            TextButton(
              onPressed: !widget.busy && memories.length == 20
                  ? () => setState(() => _offset += 20)
                  : null,
              child: const Text('Suivants'),
            ),
          ],
        ),
        if (enabled) ...[
          const Text(
            'Reprendre les sources existantes • jusqu’à 8 passages par action',
          ),
          for (final doc in store.documents(agent))
            OutlinedButton.icon(
              onPressed: widget.busy
                  ? null
                  : () => unawaited(_perform(() => widget.process(doc.id))),
              icon: const Icon(Icons.psychology_outlined),
              label: Text('Extraire / reprendre : ${doc.name}'),
            ),
        ],
      ],
    );
  }
}

String _status(String status) => switch (status) {
  'review' => 'À revoir : contradiction possible',
  'user_confirmed' => 'Confirmé par toi',
  _ => 'À examiner',
};
