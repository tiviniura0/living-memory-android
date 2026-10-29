import 'package:flutter/material.dart';

import 'memory_transfer.dart';

class BackupPanel extends StatefulWidget {
  const BackupPanel({
    super.key,
    required this.databasePath,
    required this.deviceKey,
    this.transfer,
  });
  final String databasePath;
  final String deviceKey;
  final MemoryTransfer? transfer;
  @override
  State<BackupPanel> createState() => _BackupPanelState();
}

class _BackupPanelState extends State<BackupPanel> {
  final _importKey = TextEditingController();
  late final MemoryTransfer _transfer;
  bool _busy = false;
  String? _recoveryKey;
  String _status =
      'Export chiffré ou vérification dans une copie séparée. Sauvegarde maximale : 1 Gio.';

  @override
  void initState() {
    super.initState();
    _transfer =
        widget.transfer ??
        MemoryTransfer(
          databasePath: widget.databasePath,
          deviceKey: widget.deviceKey,
        );
  }

  @override
  void dispose() {
    _importKey.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _recoveryKey = null;
    });
    try {
      final key = await _transfer.exportEncrypted();
      if (!mounted) return;
      setState(() {
        _recoveryKey = key;
        _status = key == null
            ? 'Export annulé. La mémoire active est conservée.'
            : 'Sauvegarde chiffrée enregistrée. Conservez sa clé séparément.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _status = 'Export impossible. La mémoire active est conservée.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final candidate = await _transfer.restoreEncrypted(
        _importKey.text.trim(),
      );
      if (!mounted) return;
      _importKey.clear();
      setState(
        () => _status = candidate == null
            ? 'Import annulé. La mémoire active est conservée.'
            : 'Restauration vérifiée dans un fichier séparé. La mémoire active est conservée. Les missions de la copie sont annulées.',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _status = 'Restauration refusée. Vérifiez le fichier et sa clé. La mémoire active est conservée.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde chiffrée')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_status),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _export,
            child: const Text('Exporter une sauvegarde chiffrée'),
          ),
          if (_recoveryKey != null) ...[
            const SizedBox(height: 16),
            const Text('Clé de récupération de cet export'),
            SelectableText(_recoveryKey!),
            const Text(
              'Ne pas enregistrer cette clé avec le fichier de sauvegarde. Elle sera nécessaire pour le récupérer. Aucune copie automatique dans le presse-papiers.',
            ),
          ],
          const Divider(height: 32),
          const Text('Vérifier un fichier existant'),
          const Text(
            'Une copie chiffrée sera conservée sur cet appareil. Cette action ne change pas l’espace utilisé.',
          ),
          TextField(
            controller: _importKey,
            obscureText: true,
            enabled: !_busy,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Clé de récupération'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _restore,
            child: const Text('Vérifier une restauration'),
          ),
          if (_busy) const Center(child: CircularProgressIndicator()),
        ],
      ),
    ),
  );
}
