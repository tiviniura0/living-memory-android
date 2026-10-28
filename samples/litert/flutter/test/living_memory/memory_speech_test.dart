import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/memory_speech.dart';
import 'package:litert_edge_demos/utils/result.dart';

import '../fakes/fake_audio_repository.dart';
import '../fakes/fake_speech.dart';

void main() {
  test(
    'recording uses existing STT and returns text only after explicit finish',
    () async {
      final recognizer = FakeRecognizer('Bonjour Tivini');
      final speech = await loadedSpeech(
        recognizer: recognizer,
        synthesizer: RecordingSynth(),
      );
      final audio = FakeAudioRepository()..autoDrain = true;
      final adapter = MemorySpeech(
        speech: speech,
        audio: audio,
        activateStt: (_) async => const Result.ok(null),
      );
      final started = Completer<void>();
      final work = adapter.record(onRecording: () => started.complete());
      await started.future;
      expect(recognizer.calls, 0);
      adapter.finishCapture();
      expect(await work, 'Bonjour Tivini');
      expect(recognizer.calls, 1);
      expect(audio.sessionLog.last, 'deactivate');
      await audio.close();
    },
  );
  test(
    'cancelling capture discards the recording without transcription',
    () async {
      final recognizer = FakeRecognizer('secret');
      final speech = await loadedSpeech(
        recognizer: recognizer,
        synthesizer: RecordingSynth(),
      );
      final audio = FakeAudioRepository();
      final adapter = MemorySpeech(
        speech: speech,
        audio: audio,
        activateStt: (_) async => const Result.ok(null),
      );
      final started = Completer<void>();
      final work = adapter.record(onRecording: () => started.complete());
      final assertion = expectLater(work, throwsA(isA<Exception>()));
      await started.future;
      await adapter.cancel();
      await assertion;
      expect(recognizer.calls, 0);
      await audio.close();
    },
  );
  test(
    'TTS uses existing synthesizer and playback, then releases focus',
    () async {
      final tts = RecordingSynth();
      final speech = await loadedSpeech(
        recognizer: FakeRecognizer(),
        synthesizer: tts,
      );
      final audio = FakeAudioRepository()..autoDrain = true;
      final adapter = MemorySpeech(
        speech: speech,
        audio: audio,
        activateStt: (_) async => const Result.ok(null),
      );
      await adapter.speak('Bonjour.');
      expect(audio.playbacks, isNotEmpty);
      expect(audio.sessionLog.last, 'deactivate');
      await audio.close();
    },
  );
}
