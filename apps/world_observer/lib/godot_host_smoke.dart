import 'package:flutter/material.dart';
import 'package:living_world_godot/living_world_godot.dart';

void main() => runApp(const GodotHostSmokeApp());

/// Separate Task 1 entrypoint. The L1 main.dart and simulation are unchanged.
class GodotHostSmokeApp extends StatelessWidget {
  const GodotHostSmokeApp({super.key, this.onEvent});
  final ValueChanged<Map<Object?, Object?>>? onEvent;
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('Godot — test de l’hôte')),
      body: Column(children: [
        Expanded(child: LivingWorldGodotView(onEvent: onEvent)),
        const Padding(padding: EdgeInsets.all(12), child: Text('Scène de test native. La carte Living World sera raccordée aux étapes suivantes.')),
      ]),
    ),
  );
}
