import 'package:flutter/material.dart';

import 'model_registry.dart';
import 'multi_model_engine.dart';

class ModelPanel extends StatelessWidget {
  const ModelPanel({
    super.key,
    required this.registry,
    required this.engine,
    required this.busy,
    required this.register,
    required this.selectMode,
    required this.openModels,
  });
  final ModelRegistry registry;
  final MultiModelEngine engine;
  final bool busy;
  final void Function(String id) register;
  final void Function(ModelMode mode) selectMode;
  final VoidCallback openModels;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Moteur local • V1.2',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          DropdownButtonFormField<ModelMode>(
            key: ValueKey(registry.mode),
            initialValue: registry.mode,
            decoration: const InputDecoration(labelText: 'Choix du modèle'),
            items: const [
              DropdownMenuItem(
                value: ModelMode.auto,
                child: Text('Auto • règles de complexité'),
              ),
              DropdownMenuItem(
                value: ModelMode.e2b,
                child: Text('E2B • léger'),
              ),
              DropdownMenuItem(
                value: ModelMode.e4b,
                child: Text('E4B • expérimental'),
              ),
            ],
            onChanged: busy
                ? null
                : (value) {
                    if (value != null) selectMode(value);
                  },
          ),
          for (final id in ['e2b', 'e4b'])
            Text(
              '$id : ${registry.models[id]?.displayName ?? 'non enregistré'}',
            ),
          Text('État : ${engine.status}'),
          if (engine.lastUsed != null)
            Text('Dernier modèle réussi : ${engine.lastUsed}'),
          if (engine.fallbackReason != null)
            Text('Repli E2B : ${engine.fallbackReason}'),
          if (registry.models.isEmpty)
            const Text('Sans modèle enregistré : parcours V1.1 conservé.'),
          const Text(
            'Un seul générateur chargé. E4B reste à valider sur ce téléphone.',
          ),
          TextButton(
            onPressed: busy ? null : openModels,
            child: const Text('1. Importer / choisir dans Modèles'),
          ),
          const Text(
            '2. Enregistrer le modèle choisi ci-dessous. Une copie privée complète est créée : prévoir la place disque. Le libellé ne prouve pas l’identité des poids.',
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final id in ['e2b', 'e4b'])
                OutlinedButton(
                  onPressed: busy ? null : () => register(id),
                  child: Text('Enregistrer comme ${id.toUpperCase()}'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
