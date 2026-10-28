import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart' show PreferredBackend;
import 'package:path/path.dart' as p;

import '../../data/repositories/chat_model/custom_chat_model_codec.dart';
import '../../domain/models/chat_model.dart';
import '../../utils/model_file_limits.dart';
import 'multi_model_engine.dart';

abstract interface class ModelManager {
  Map<String, CustomChatModel> get models;
  ModelMode get mode;
  Future<void> load();
  Future<void> setMode(ModelMode mode);
  Future<void> register(
    String id,
    String sourcePath,
    CustomChatModel model, {
    bool Function()? cancelled,
  });
  Future<bool> verify(String id);
  Future<void> remove(String id);
}

/// Independent versioned manifest; never migrates or writes the memory database.
/// Immutable private copies are outside ModelStore's single-file pruning area.
class ModelRegistry implements ModelManager {
  ModelRegistry(this.directory, {this.freeBytes});
  final Future<int?> Function()? freeBytes;
  final Directory directory;
  Map<String, CustomChatModel> _models = {};
  @override
  Map<String, CustomChatModel> get models => Map.unmodifiable(_models);
  ModelMode _mode = ModelMode.auto;
  @override
  ModelMode get mode => _mode;
  File get _manifest => File('${directory.path}/registry.json');

  @override
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
      validateModelSize(model.file!.sizeBytes);
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

  @override
  Future<void> setMode(ModelMode mode) => _save(_models, mode);

  /// Deliberate user action: source is already checked by ChatModelRepository.
  /// Hash proves copied-byte integrity, never model identity or semantic quality.
  @override
  Future<void> register(
    String id,
    String sourcePath,
    CustomChatModel model, {
    bool Function()? cancelled,
  }) async {
    if (!const {'e2b', 'e4b'}.contains(id)) throw ArgumentError.value(id);
    void check() {
      if (cancelled?.call() ?? false) throw const ModelCancelled();
    }

    check();
    await directory.create(recursive: true);
    final previous = _models[id];
    final name = '$id-${DateTime.now().microsecondsSinceEpoch}.litertlm';
    final file = File('${directory.absolute.path}/$name');
    final part = File('${file.path}.part');
    try {
      final source = File(sourcePath);
      if (!await source.exists()) {
        throw FileSystemException('Modèle absent', sourcePath);
      }
      final before = await source.stat();
      validateModelSize(before.size);
      final available = await freeBytes?.call();
      check();
      if (available != null && available < before.size + 64 * 1024 * 1024) {
        throw const FileSystemException(
          'Espace insuffisant pour la copie privée et la réserve de 64 Mio.',
        );
      }
      var copied = 0;
      final sink = part.openWrite();
      try {
        await sink.addStream(
          source.openRead().map((chunk) {
            check();
            copied += chunk.length;
            if (copied > before.size || copied > kMaximumModelBytes) {
              throw const FormatException(
                'Taille du modèle modifiée pendant la copie.',
              );
            }
            return chunk;
          }),
        );
      } finally {
        await sink.close();
      }
      if (await part.length() != before.size) {
        throw const FormatException('Copie incomplète.');
      }
      check();
      final digest = (await sha256.bind(part.openRead()).first).toString();
      check();
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
      // Only after the replacement is durable: never delete user source files.
      if (previous != null && await _privateRegular(id, previous)) {
        final old = File((previous.source as LocalModelSource).path);
        try {
          await old.delete();
        } on FileSystemException {
          /* safe orphan */
        }
      }
    } catch (_) {
      if (await part.exists()) await part.delete();
      final current = _models[id]?.source;
      if (!(current is LocalModelSource && current.path == file.path) &&
          await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  @override
  Future<bool> verify(String id) async {
    final model = _models[id];
    if (model == null || model.source is! LocalModelSource) return false;
    if (!await _privateRegular(id, model)) return false;
    final file = File((model.source as LocalModelSource).path);
    try {
      final size = await file.length();
      if (size <= 0 ||
          size > kMaximumModelBytes ||
          size != model.file!.sizeBytes)
        return false;
      return (await sha256.bind(file.openRead()).first).toString() ==
          model.file!.sha256;
    } on FileSystemException {
      return false;
    }
  }

  Future<bool> _privateRegular(String id, CustomChatModel model) async {
    final source = model.source;
    if (source is! LocalModelSource) return false;
    final path = p.normalize(source.path);
    if (!RegExp('^$id-[0-9]+\\.litertlm\$').hasMatch(p.basename(path)) ||
        !p.isWithin(p.normalize(directory.absolute.path), path)) {
      return false;
    }
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.file) {
      return false;
    }
    try {
      return p.isWithin(
        await directory.resolveSymbolicLinks(),
        await File(path).resolveSymbolicLinks(),
      );
    } on FileSystemException {
      return false;
    }
  }

  /// Called under the shared model lock after native unload, at user request.
  @override
  Future<void> remove(String id) async {
    final model = _models[id];
    if (model == null) return;
    if (!await _privateRegular(id, model)) {
      throw const FormatException(
        'Suppression refusée : copie privée absente ou chemin non régulier.',
      );
    }
    final file = File((model.source as LocalModelSource).path);
    await _save(Map.of(_models)..remove(id), _mode);
    await file.delete();
  }
}
