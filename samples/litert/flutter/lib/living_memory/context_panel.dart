import 'package:flutter/material.dart';

import 'context_lifecycle_manager.dart';
import 'memory_store.dart';

/// Bounded history, no nested scrolling and no model call from this panel.
class ContextPanel extends StatefulWidget {
  const ContextPanel({
    super.key,
    required this.manager,
    required this.busy,
    this.onDeleted,
  });
  final ContextLifecycleManager manager;
  final bool busy;
  final VoidCallback? onDeleted;
  @override
  State<ContextPanel> createState() => _ContextPanelState();
}

class _ContextPanelState extends State<ContextPanel> {
  String? _selected;
  String? _error;
  void _act(void Function() action) {
    try {
      action();
      _error = null;
    } catch (e) {
      _error = '$e';
    }
    setState(() {});
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette session ?'),
        content: const Text(
          'Messages, décisions et résumés de cette session seront effacés. Les sources enregistrées séparément restent conservées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || widget.busy) return;
    _act(() {
      widget.manager.deleteSession(id);
      _selected = null;
    });
    widget.onDeleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final manager = widget.manager;
    final sessions = manager.sessions();
    final id = sessions.any((s) => s.id == _selected)
        ? _selected
        : sessions.firstOrNull?.id;
    final messages = id == null ? <SessionMessage>[] : manager.messages(id);
    final checkpoints = id == null
        ? <ContextCheckpoint>[]
        : manager.checkpoints(id);
    return ExpansionTile(
      title: const Text('Sessions et contexte'),
      subtitle: const Text('Archives locales • résumés non vérifiés'),
      children: [
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        OutlinedButton(
          onPressed: widget.busy
              ? null
              : () => _act(() => _selected = manager.startSession()),
          child: const Text('Nouvelle session'),
        ),
        if (id != null) ...[
          DropdownButtonFormField<String>(
            key: ValueKey(id),
            initialValue: id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Session archivée'),
            items: [
              for (final s in sessions)
                DropdownMenuItem(value: s.id, child: Text(s.updatedAt)),
            ],
            onChanged: widget.busy
                ? null
                : (value) => setState(() => _selected = value),
          ),
          Text(
            'Budget estimé : ${manager.activeTokenEstimate(id)} / ${manager.tokenBudget} • borne UTF-8, pas un comptage exact',
          ),
          const Text(
            'La compaction conserve les originaux et les souvenirs permanents. Les réponses IA restent non vérifiées.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: widget.busy
                    ? null
                    : () => _act(() {
                        manager.compact(id);
                      }),
                child: const Text('Compacter'),
              ),
              TextButton(
                onPressed: widget.busy
                    ? null
                    : () => _act(() {
                        manager.resetActiveContext(id);
                      }),
                child: const Text('Réinitialiser le contexte actif'),
              ),
              TextButton(
                onPressed: widget.busy ? null : () => _delete(id),
                child: const Text('Supprimer cette session'),
              ),
            ],
          ),
          for (final c in checkpoints.reversed.take(5))
            ListTile(
              title: Text(
                c.kind == 'reset'
                    ? 'Contexte réinitialisé'
                    : 'Résumé extractif • non vérifié',
              ),
              subtitle: SelectableText(
                c.summary.isEmpty
                    ? 'Originaux conservés dans l’archive.'
                    : c.summary,
              ),
            ),
          Text('${messages.length} messages archivés • 20 derniers affichés'),
          for (final m in messages.reversed.take(20))
            ListTile(
              title: SelectableText(m.text),
              subtitle: Text(
                '${m.role == 'user' ? 'Utilisateur' : 'IA • non vérifié'} • ${m.createdAt}',
              ),
              trailing: m.role != 'user'
                  ? null
                  : IconButton(
                      tooltip: m.decision
                          ? 'Retirer des décisions'
                          : 'Marquer comme décision',
                      icon: Icon(
                        m.decision ? Icons.bookmark : Icons.bookmark_border,
                      ),
                      onPressed: widget.busy
                          ? null
                          : () => _act(
                              () => manager.markDecision(
                                id,
                                m.ordinal,
                                decision: !m.decision,
                              ),
                            ),
                    ),
            ),
        ] else
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Aucune session pour cet agent et ce projet.'),
          ),
      ],
    );
  }
}
