import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/domain/audio/transcript_corrections.dart';
import 'package:litert_edge_demos/utils/private_logging.dart';

void main() {
  test(
    'transcript correction never logs original or corrected private text',
    () {
      final old = debugPrint;
      final lines = <String>[];
      debugPrint = (String? message, {int? wrapWidth}) {
        lines.add(message ?? '');
      };
      try {
        const sentinel = 'SECRET_LAGON42';
        correctVoiceTranscript('what is littered $sentinel');
        expect(lines.join('\n'), isNot(contains(sentinel)));
      } finally {
        debugPrint = old;
      }
    },
  );
  test(
    'application console sinks suppress private strings and errors',
    () async {
      final old = debugPrint;
      final oldError = FlutterError.onError;
      final oldPlatformError = PlatformDispatcher.instance.onError;
      final lines = <String>[];
      var completed = false;
      try {
        debugPrint = (String? message, {int? wrapWidth}) {
          lines.add(message ?? '');
        };
        await runZoned(
          () => runPrivateApplication(() async {
            debugPrint('SECRET_LAGON42');
            // Simulates a third-party Dart package using print instead of debugPrint.
            // ignore: avoid_print
            print('SECRET_LAGON42');
            FlutterError.reportError(
              FlutterErrorDetails(exception: StateError('SECRET_LAGON42')),
            );
            completed = true;
          }),
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, line) {
              lines.add(line);
            },
          ),
        );
        expect(completed, isTrue);
        expect(lines, isEmpty);
      } finally {
        debugPrint = old;
        FlutterError.onError = oldError;
        PlatformDispatcher.instance.onError = oldPlatformError;
      }
    },
  );
}
