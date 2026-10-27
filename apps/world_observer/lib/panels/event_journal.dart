import 'package:flutter/material.dart';
import 'package:world_core/world_core.dart';

class EventJournal extends StatelessWidget {
  final WorldSnapshot snapshot;
  const EventJournal({super.key, required this.snapshot});
  @override
  Widget build(BuildContext context) {
    final events = snapshot.state.eventLog.reversed.take(500).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Journal du village')),
      body: ListView.builder(
        itemCount: events.length,
        itemBuilder: (context, i) {
          final e = events[i];
          return ListTile(
            title: Text('${e.actorId ?? 'Monde'} · ${e.kind}'),
            subtitle: Text('Tick ${e.tick} · ${e.data['payload']}'),
          );
        },
      ),
    );
  }
}
