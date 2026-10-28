import 'dart:io';

import 'package:flutter/services.dart';

import 'encrypted_database.dart';

/// The non-exportable Android Keystore key wraps a random SQLCipher key.
/// Only that wrapped envelope is persisted; a missing/corrupt key fails closed.
class MemoryKey {
  static const _channel = MethodChannel('living_memory/security');

  static Future<String?> forDatabase(String path) async {
    if (!Platform.isAndroid) return null;
    final file = File(path);
    final mayCreate =
        !file.existsSync() ||
        file.lengthSync() == 0 ||
        EncryptedMemoryDatabase.isPlaintext(path);
    final key = await _channel.invokeMethod<String>('databaseKey', {
      'mayCreate': mayCreate,
    });
    if (key == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(key)) {
      throw StateError('Clé de mémoire indisponible. Données conservées.');
    }
    return key;
  }
}
