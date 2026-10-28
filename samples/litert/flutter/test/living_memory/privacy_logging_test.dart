import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/domain/audio/transcript_corrections.dart';

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
}
