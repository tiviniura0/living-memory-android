import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/memory_speech.dart';
import 'package:litert_edge_demos/living_memory/multimodel/multi_model_engine.dart';
import 'package:litert_edge_demos/domain/models/audio_interruption.dart';
import 'package:litert_edge_demos/data/repositories/audio_repository.dart';
import 'package:litert_edge_demos/utils/result.dart';
import 'package:litert_edge_demos/utils/wav.dart';

import '../fakes/fake_audio_repository.dart';
import '../fakes/fake_speech.dart';

class _FrenchRecognizer extends FakeRecognizer {
  _FrenchRecognizer() : super('Bonjour Tivini');
  String? requestedLanguage;
  @override
  Future<String> transcribe(Uint8List pcm, {String? language}) {
    requestedLanguage = language;
    return super.transcribe(pcm, language: language);
  }
}

class _NotifyingAudio extends FakeAudioRepository {
  final playbackReady = Completer<void>();
  @override
  Result<PlaybackHandle> beginPlayback(int sampleRate) {
    final result = super.beginPlayback(sampleRate);
    if (!playbackReady.isCompleted) playbackReady.complete();
    return result;
  }
}

void main() {
  test(
    'recording uses existing STT and returns text only after explicit finish',
    () async {
      final recognizer = _FrenchRecognizer();
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
      expect(recognizer.requestedLanguage, 'fr');
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
  test(
    'WAV file uses local French STT and rejects non-WAV and overlong input',
    () async {
      final recognizer = _FrenchRecognizer();
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
      expect(
        await adapter.transcribeFile(
          wavFromPcm16(Uint8List(3200), sampleRate: 16000),
        ),
        'Bonjour Tivini',
      );
      expect(recognizer.requestedLanguage, 'fr');
      await expectLater(
        adapter.transcribeFile(Uint8List(3)),
        throwsFormatException,
      );
      await expectLater(
        adapter.transcribeFile(
          wavFromPcm16(Uint8List(960002), sampleRate: 16000),
        ),
        throwsFormatException,
      );
      expect(recognizer.calls, 1);
      await audio.close();
    },
  );
  for (final reason in AudioInterruption.values) {
    test(
      'record settles and discards PCM on ${reason.name} without manual finish',
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
        final assertion = expectLater(
          work.timeout(const Duration(seconds: 1)),
          throwsA(isA<ModelCancelled>()),
        );
        await started.future;
        audio.interrupt(reason);
        try {
          await assertion;
        } finally {
          await adapter.cancel();
          await work.then<void>((_) {}, onError: (Object _) {});
          await audio.close();
        }
        expect(recognizer.calls, 0);
        expect(audio.sessionLog.last, 'deactivate');
      },
    );
  }
  test(
    'malformed WAV data size is rejected before activating a model',
    () async {
      final recognizer = FakeRecognizer();
      final speech = await loadedSpeech(
        recognizer: recognizer,
        synthesizer: RecordingSynth(),
      );
      final audio = FakeAudioRepository();
      var activated = 0;
      final adapter = MemorySpeech(
        speech: speech,
        audio: audio,
        activateStt: (_) async {
          activated++;
          return const Result.ok(null);
        },
      );
      final wav = wavFromPcm16(Uint8List(3200), sampleRate: 16000);
      ByteData.sublistView(wav).setUint32(40, 6400, Endian.little);
      await expectLater(adapter.transcribeFile(wav), throwsFormatException);
      expect(activated, 0);
      expect(recognizer.calls, 0);
      await audio.close();
    },
  );
  test('denied mic never starts transcription', () async {
    final recognizer = FakeRecognizer();
    final speech = await loadedSpeech(
      recognizer: recognizer,
      synthesizer: RecordingSynth(),
    );
    final audio = FakeAudioRepository()
      ..micAccess = const Result.error(MicAccessException('denied'));
    final adapter = MemorySpeech(
      speech: speech,
      audio: audio,
      activateStt: (_) async => const Result.ok(null),
    );
    await expectLater(
      adapter.record(onRecording: () => fail('micro started')),
      throwsA(isA<MicAccessException>()),
    );
    expect(recognizer.calls, 0);
    await audio.close();
  });
  test('cancellation while STT runs discards eventual words', () async {
    final recognizer = FakeRecognizer('secret')..gate = Completer<void>();
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
    final assertion = expectLater(work, throwsA(isA<ModelCancelled>()));
    await started.future;
    adapter.finishCapture();
    for (var i = 0; i < 100 && recognizer.calls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(recognizer.calls, 1);
    await adapter.cancel();
    recognizer.gate!.complete();
    await assertion;
    await audio.close();
  });
  test(
    'TTS interruption discards playback and settles as cancellation',
    () async {
      final speech = await loadedSpeech(
        recognizer: FakeRecognizer(),
        synthesizer: RecordingSynth(),
      );
      final audio = _NotifyingAudio();
      final adapter = MemorySpeech(
        speech: speech,
        audio: audio,
        activateStt: (_) async => const Result.ok(null),
      );
      final work = adapter.speak('Bonjour.');
      final assertion = expectLater(
        work.timeout(const Duration(seconds: 2)),
        throwsA(isA<ModelCancelled>()),
      );
      await audio.playbackReady.future.timeout(const Duration(seconds: 1));
      audio.interrupt(AudioInterruption.outputRemoved);
      try {
        await assertion;
      } finally {
        await adapter.cancel();
        await audio.close();
      }
    },
  );
}
