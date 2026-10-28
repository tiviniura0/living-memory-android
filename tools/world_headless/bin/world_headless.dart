import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:world_headless/scenario_runner.dart';

Future<void> main(List<String> args) async {
  try {
    final options = <String, String>{};
    if (args.length != 6)
      throw const FormatException(
        'Expected --fixture PATH --ticks INT --out PATH',
      );
    for (var i = 0; i < args.length; i += 2) {
      if (!['--fixture', '--ticks', '--out'].contains(args[i]) ||
          options.containsKey(args[i]))
        throw const FormatException('Unknown or duplicate argument');
      options[args[i]] = args[i + 1];
    }
    final ticks = int.parse(options['--ticks']!);
    if (ticks < 0 || ticks > 1000000)
      throw const FormatException('Invalid tick count');
    final source = File(options['--fixture']!);
    if (await source.length() > 16 * 1024 * 1024)
      throw const FormatException('Fixture too large');
    final initial = WorldCodec.decode(await source.readAsString());
    final s = ScenarioRunner().run(initial, ticks).state;
    WorldCodec.validate(s.toJson());
    final out = {
      'sha256': sha256.convert(utf8.encode(WorldCodec.encode(s))).toString(),
      'tick': s.tick,
      'rulesVersion': 1,
      'invariants': true,
      'state': s.toJson(),
    };
    await File(options['--out']!)
        .writeAsString(canonicalJson(out), flush: true);
    stdout.writeln(
      canonicalJson({
        'sha256': out['sha256'],
        'tick': s.tick,
        'invariants': true,
      }),
    );
  } catch (e) {
    stderr.writeln('Configuration ou scénario invalide : $e');
    exitCode = 2;
  }
}
