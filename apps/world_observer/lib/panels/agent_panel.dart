import 'package:flutter/material.dart';
import 'package:world_core/world_core.dart';

class AgentPanel extends StatelessWidget {
  final AgentState agent;
  final VoidCallback onFollow;
  const AgentPanel({super.key, required this.agent, required this.onFollow});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(agent.name, style: Theme.of(context).textTheme.titleLarge),
        Text(
          'Faim ${agent.hunger}/100 · Énergie ${agent.energy}/100\nNourriture portée : ${agent.inventoryFood}\nObjectif : ${agent.goal}\nAction : ${agent.currentAction == null ? 'disponible' : 'en cours'} · Échecs : ${agent.failureCount}',
        ),
        TextButton(
          onPressed: onFollow,
          child: const Text('Suivre cet habitant'),
        ),
        const Text(
          'Relations, souvenirs et conversations : disponibles dans un lot ultérieur.',
        ),
      ],
    ),
  );
}
