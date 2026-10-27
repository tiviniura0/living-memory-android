import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart' show PreferredBackend;
import 'package:path/path.dart' as p;

import '../../data/repositories/chat_model/custom_chat_model_codec.dart';
import '../../domain/models/chat_model.dart';
import 'multi_model_engine.dart';

/// Independent versioned manifest; never migrates or writes the memory database.
/// Immutable private copies are outside ModelStore's single-file pruning area.
class ModelRegistry {
  ModelRegistry(this.directory);
  final Directory directory;
  Map<String, CustomChatModel> _models = {};
  Map<String, CustomChatModel> get models => Map.unmodifiable(_models);
  ModelMode _mode = ModelMode.auto;
  ModelMode get mode => _mode;
  File get _manifest => File('${directory.path}/registry.json');

  Future<void> load() async {
    if (!await _manifest.exists()) return;
    final json = jsonDecode(await _manifest.readAsString());
    if (json is! Map<String, dynamic> ||
        json['v'] != 1 ||
        json['models'] is! Map<String, dynamic> ||
        !ModelMode.values.any((m) => m.name == json['mode'])) {
      throw const FormatException(
        'Registre de modèles invalide ou version future.',
      );
    }
    final parsed = <String, CustomChatModel>{};
    for (final entry in (json['models'] as Map<String, dynamic>).entries) {
      if (!const {'e2b', 'e4b'}.contains(entry.key) || entry.value is! String) {
        throw const FormatException('Entrée de modèle invalide.');
      }
      final model = CustomChatModelCodec.decode(entry.value as String);
      if (model.source is! LocalModelSource ||
          model.file?.sha256 == null ||
          !p.isWithin(
            p.normalize(directory.absolute.path),
            p.normalize((model.source as LocalModelSource).path),
          )) {
        throw const FormatException(
          'Le modèle doit rester dans le registre privé.',
        );
      }
      parsed[entry.key] = model;
    }
    _models = parsed;
    _mode = ModelMode.values.byName(json['mode'] as String);
  }

  Future<void> _save(
    Map<String, CustomChatModel> models,
    ModelMode mode,
  ) async {
    await directory.create(recursive: true);
    final temp = File('${_manifest.path}.part');
    await temp.writeAsString(
      jsonEncode({
        'v': 1,
        'mode': mode.name,
        'models': models.map(
          (id, model) => MapEntry(id, CustomChatModelCodec.encode(model)),
        ),
      }),
      flush: true,
    );
    await temp.rename(_manifest.path);
    _models = Map.of(models);
    _mode = mode;
  }

  Future<void> setMode(ModelMode mode) => _save(_models, mode);

  /// Deliberate user action: source is already checked by ChatModelRepository.
  /// Hash proves copied-byte integrity, never model identity or semantic quality.
  Future<void> register(
    String id,
    String sourcePath,
    CustomChatModel model,
  ) async {
    if (!const {'e2b', 'e4b'}.contains(id)) throw ArgumentError.value(id);
    await directory.create(recursive: true);
    final name = '$id-${DateTime.now().microsecondsSinceEpoch}.litertlm';
    final file = File('${directory.absolute.path}/$name');
    final part = File('${file.path}.part');
    try {
      final source = File(sourcePath);
      if (!await source.exists()) {
        throw FileSystemException('Modèle absent', sourcePath);
      }
      final before = await source.stat();
      if (before.size <= 0) throw const FormatException('Modèle vide.');
      final sink = part.openWrite();
      try {
        await sink.addStream(source.openRead());
      } finally {
        await sink.close();
      }
      if (await part.length() != before.size) {
        throw const FormatException('Copie incomplète.');
      }
      final digest = (await sha256.bind(part.openRead()).first).toString();
      if (model.file?.sha256 case final expected? when expected != digest) {
        throw const FormatException(
          'Empreinte différente du modèle sélectionné.',
        );
      }
      await part.rename(file.path);
      final saved = model.copyWith(
        source: LocalModelSource(file.path),
        maxTokens:
            model.backend != PreferredBackend.npu && model.maxTokens > 2048
            ? 2048
            : model.maxTokens,
        tools: false,
        file: CustomModelFile(
          name: name,
          sizeBytes: before.size,
          sha256: digest,
          checksumMatched: model.file?.checksumMatched ?? false,
        ),
      );
      await _save({..._models, id: saved}, _mode);
    } catch (_) {
      if (await part.exists()) await part.delete();
      // An orphaned finished copy is harmless; never remove a registered file.
      rethrow;
    }
  }

  Future<bool> verify(String id) async {
    final model = _models[id];
    if (model == null || model.source is! LocalModelSource) return false;
    final file = File((model.source as LocalModelSource).path);
    try {
      if (await file.length() != model.file!.sizeBytes) return false;
      return (await sha256.bind(file.openRead()).first).toString() ==
          model.file!.sha256;
    } on FileSystemException {
      return false;
    }
  }
}
