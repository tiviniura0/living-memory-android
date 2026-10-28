import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:world_contracts/world_contracts.dart';
export 'package:world_contracts/world_contracts.dart';

class FileOps {
  Future<void> writeFlushed(String path, String body) async {
    await File(path).writeAsString(body, flush: true);
  }

  Future<void> rename(String from, String to) async {
    await File(from).rename(to);
  }

  Future<String> read(String path) => File(path).readAsString();
  Future<List<String>> list(String path) async =>
      (await Directory(path).list().toList()).map((e) => e.path).toList();
}

class LoadResult {
  final WorldSnapshot? snapshot;
  final bool recovered;
  final List<String> warnings;
  const LoadResult(
    this.snapshot, {
    this.recovered = false,
    this.warnings = const [],
  });
}

class CheckpointStore {
  final Directory directory;
  final FileOps files;
  Future<void> _tail = Future.value();
  CheckpointStore(this.directory, {FileOps? files})
    : files = files ?? FileOps();
  String _path(String name) => '${directory.path}/$name';
  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<List<Map<String, dynamic>>> _manifest() async {
    final f = File(_path('manifest.json'));
    if (!await f.exists()) return [];
    final raw = await files.read(f.path);
    if (raw.length > 4096) throw const FormatException('Invalid manifest');
    final m = jsonDecode(raw);
    if (m is! Map ||
        m['schemaVersion'] != 1 ||
        m['generations'] is! List ||
        m['generations'].length > 2)
      throw const FormatException('Invalid manifest');
    final result = <Map<String, dynamic>>[];
    for (final g in m['generations']) {
      if (g is! Map ||
          g['id'] is! int ||
          g['id'] < 1 ||
          g['id'] > 9007199254740991 ||
          g['sha256'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(g['sha256']))
        throw const FormatException('Invalid generation');
      result.add(Map<String, dynamic>.from(g));
    }
    return result;
  }

  Future<WorldSnapshot> _readGeneration(Map<String, dynamic> g) async {
    final f = File(_path('checkpoint-${g['id']}.json'));
    if (await f.length() > 16 * 1024 * 1024)
      throw const FormatException('Snapshot too large');
    final body = await files.read(f.path);
    if (sha256.convert(utf8.encode(body)).toString() != g['sha256'])
      throw const FormatException('Checksum mismatch');
    return WorldSnapshot(WorldCodec.decode(body));
  }

  Future<void> save(WorldSnapshot s) => _serial(() => _save(s));
  Future<void> _save(WorldSnapshot s) async {
    WorldCodec.validate(s.state.toJson());
    await directory.create(recursive: true);
    final generations = await _manifest(), valid = <Map<String, dynamic>>[];
    for (final g in generations) {
      try {
        await _readGeneration(g);
        valid.add(g);
      } catch (_) {}
    }
    var n = 0;
    for (final path in await files.list(directory.path)) {
      final match = RegExp(r'checkpoint-(\d+)\.json$').firstMatch(path);
      if (match != null) {
        final id = int.parse(match[1]!);
        if (id > n) n = id;
      }
    }
    n++;
    final body = WorldCodec.encode(s.state), name = 'checkpoint-$n.json';
    await files.writeFlushed(_path('$name.tmp'), body);
    await files.rename(_path('$name.tmp'), _path(name));
    final g = {'id': n, 'sha256': sha256.convert(utf8.encode(body)).toString()};
    await _readGeneration(g);
    final keep = [g, ...valid.take(1)];
    await files.writeFlushed(
      _path('manifest.json.tmp'),
      canonicalJson({'schemaVersion': 1, 'generations': keep}),
    );
    await files.rename(_path('manifest.json.tmp'), _path('manifest.json'));
    // Publication already succeeded. Cleanup failure must not misreport the save as lost.
    for (final path in await files.list(directory.path)) {
      final m = RegExp(r'checkpoint-(\d+)\.json$').firstMatch(path);
      if (m != null && !keep.any((g) => g['id'] == int.parse(m[1]!))) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
    }
  }

  Future<LoadResult> load() => _serial(_load);
  Future<LoadResult> _load() async {
    List<Map<String, dynamic>> gens;
    try {
      gens = await _manifest();
    } catch (_) {
      return const LoadResult(
        null,
        warnings: [
          'Manifeste illisible : reprise refusée, fichiers conservés.',
        ],
      );
    }
    final warnings = <String>[];
    for (final g in gens) {
      try {
        final s = await _readGeneration(g);
        return LoadResult(
          s,
          recovered: warnings.isNotEmpty,
          warnings: List.unmodifiable(warnings),
        );
      } catch (_) {
        warnings.add('Génération ${g['id']} invalide ; tentative précédente.');
      }
    }
    return LoadResult(null, warnings: List.unmodifiable(warnings));
  }

  Future<String> exportJson() => _serial(() async {
    final r = await _load();
    if (r.snapshot == null) throw StateError('No valid checkpoint');
    return WorldCodec.encode(r.snapshot!.state);
  });
  Future<LoadResult> importJson(String json, {int? populationMaxOverride}) =>
      _serial(() async {
        var s = WorldCodec.decode(json);
        final data = s.toJson();
        final count = s.agents.length;
        if (populationMaxOverride != null) {
          if (populationMaxOverride < 1 ||
              populationMaxOverride > 1000 ||
              populationMaxOverride < count)
            throw const FormatException('Population override');
          data['config']['populationMax'] = populationMaxOverride;
          s = WorldState(data);
        }
        if (count > s.config.populationMax)
          throw const FormatException(
            'Population exceeds cap; explicit override required',
          );
        await _save(WorldSnapshot(s));
        return LoadResult(WorldSnapshot(s));
      });
}
