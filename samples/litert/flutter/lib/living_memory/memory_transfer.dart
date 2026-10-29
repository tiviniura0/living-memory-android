import 'dart:io';

import 'package:flutter/services.dart';
import 'package:living_memory_core/living_memory_core.dart';

import '../config/knowledge_config.dart';

/// Host-only SAF bridge. Keys remain in Dart; only encrypted private file paths
/// cross the platform channel. A restore never selects or replaces active data.
class MemoryTransfer {
  MemoryTransfer({required this.databasePath, required this.deviceKey,
    MethodChannel channel = const MethodChannel('living_memory/transfer')})
      : _channel = channel;
  final String databasePath;
  final String deviceKey;
  final MethodChannel _channel;

  Future<Directory> _stagingDirectory() async {
    final path = await _channel.invokeMethod<String>('transferDirectory');
    if (path == null || path.isEmpty) throw StateError('Transfert indisponible.');
    final directory = Directory(path).absolute;
    if (directory.path != directory.resolveSymbolicLinksSync()) {
      throw StateError('Stockage de transfert refusé.');
    }
    return directory;
  }

  bool _owned(String path, Directory directory) {
    final file = File(path).absolute;
    return file.parent.path == directory.path &&
        FileSystemEntity.typeSync(file.path, followLinks: false) == FileSystemEntityType.file &&
        file.resolveSymbolicLinksSync() == file.path;
  }

  void _clean(String? path, Directory? directory) {
    if (path == null || directory == null) return;
    try {
      if (_owned(path, directory)) File(path).deleteSync();
    } catch (_) {
      // Inaccessible encrypted remnants may remain; never alter active data.
    }
  }

  Future<String?> exportEncrypted() async {
    Directory? directory;
    String? staged;
    try {
      directory = await _stagingDirectory();
      staged = '${directory.path}/export-${MemoryBackup.generateRecoveryKey()}.lmemory';
      final recovery = MemoryBackup.generateRecoveryKey();
      MemoryBackup.exportEncrypted(sourcePath: databasePath, sourceKey: deviceKey,
        targetPath: staged, recoveryKey: recovery,
        profile: kKbEmbeddingProfileId, dimension: kKbEmbeddingDimension);
      final saved = await _channel.invokeMethod<bool>('saveBackup', {'path': staged});
      return saved == true ? recovery : null;
    } catch (_) {
      throw StateError('Export chiffré impossible. La mémoire active est conservée.');
    } finally {
      _clean(staged, directory);
    }
  }

  Future<String?> restoreEncrypted(String recoveryKey) async {
    Directory? directory;
    String? imported;
    try {
      if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(recoveryKey)) {
        throw StateError('Clé de récupération invalide.');
      }
      directory = await _stagingDirectory();
      imported = await _channel.invokeMethod<String>('pickBackup');
      if (imported == null) return null;
      if (!_owned(imported, directory)) throw StateError('Import de sauvegarde refusé.');
      final candidate = '${File(databasePath).absolute.parent.path}/living-memory-restored-${MemoryBackup.generateRecoveryKey()}.db';
      MemoryBackup.restoreEncrypted(sourcePath: imported, recoveryKey: recoveryKey,
        targetPath: candidate, deviceKey: deviceKey,
        profile: kKbEmbeddingProfileId, dimension: kKbEmbeddingDimension);
      return candidate;
    } catch (_) {
      throw StateError('Restauration refusée. La mémoire active est conservée.');
    } finally {
      _clean(imported, directory);
    }
  }
}
