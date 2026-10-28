import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_edge_ai_speech/flutter_edge_ai_speech.dart';

import '../data/repositories/audio_repository.dart';
import '../data/repositories/speech_repository.dart';
import '../domain/models/model_id.dart';
import '../utils/result.dart';
import '../utils/wav.dart';
import 'multimodel/multi_model_engine.dart';

abstract interface class SpeechToTextProvider {
  Future<String> transcribe(Uint8List pcm);
}

abstract interface class TextToSpeechProvider {
  Future<void> speak(String text);
  Future<void> cancel();
}

T _value<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Error(:final error) => throw error,
};

/// Borrows app-scoped Google STT/TTS and audio. Never writes a recording to disk.
/// Only explicit user actions call record/speak; the UI cancels on background.
class MemorySpeech implements SpeechToTextProvider, TextToSpeechProvider {
  MemorySpeech({
    required this.speech,
    required this.audio,
    required this.activateStt,
  });
  final SpeechRepository speech;
  final AudioRepository audio;
  final Future<Result<void>> Function(ModelId) activateStt;
  CaptureHandle? _capture;
  PlaybackHandle? _playback;
  VoiceTurn? _turn;
  Completer<void>? _finish;
  bool _cancelled = false;
  bool _busy = false;

  void _check() {
    if (_cancelled) throw const ModelCancelled();
  }

  void finishCapture() {
    final finish = _finish;
    if (finish != null && !finish.isCompleted) finish.complete();
  }

  Future<String> record({required void Function() onRecording}) async {
    if (_busy) throw StateError('Audio occupé.');
    _busy = true;
    _cancelled = false;
    final finish = _finish = Completer<void>();
    try {
      _value(await audio.requestMicAccess());
      _check();
      _value(await activateStt(ModelId.whisperBase));
      _check();
      final capture = _value(
        await audio.startCapture(
          maxLength: const Duration(seconds: 30),
          onLimit: finishCapture,
        ),
      );
      _capture = capture;
      _check();
      onRecording();
      await finish.future;
      _check();
      final utterance = _value(await capture.stop());
      _check();
      if (utterance.pcm.isEmpty) {
        throw const FormatException('Enregistrement vide.');
      }
      return await transcribe(utterance.pcm);
    } finally {
      await _capture?.cancel();
      _capture = null;
      _finish = null;
      await audio.deactivate();
      _busy = false;
    }
  }

  @override
  Future<String> transcribe(Uint8List pcm) async {
    _check();
    final text = _value(
      await speech.transcribeWithLanguage(
        pcm,
        expected: ModelId.whisperBase,
        language: 'fr',
      ),
    );
    _check();
    if (text.trim().isEmpty) {
      throw const FormatException('Aucune parole reconnue.');
    }
    return text;
  }

  /// Existing WAV decoder; bounded import, no resampling or compressed codecs.
  Future<String> transcribeFile(Uint8List wav) async {
    if (_busy) throw StateError('Audio occupé.');
    _busy = true;
    _cancelled = false;
    try {
      if (wav.length < 12 ||
          wav.length > 2 * 1024 * 1024 ||
          ByteData.sublistView(wav).getUint32(4, Endian.little) + 8 !=
              wav.length) {
        throw const FormatException('WAV incomplet ou supérieur à 2 Mio.');
      }
      final pcm = pcm16FromWav(wav);
      if (pcm.isEmpty || pcm.length.isOdd || pcm.length > 960000) {
        throw const FormatException(
          'WAV attendu : PCM16 mono 16 kHz, 30 secondes maximum.',
        );
      }
      _value(await activateStt(ModelId.whisperBase));
      _check();
      return await transcribe(pcm);
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> speak(String text) async {
    if (_busy) throw StateError('Audio occupé.');
    if (text.trim().isEmpty) throw const FormatException('Aucun texte à lire.');
    _busy = true;
    _cancelled = false;
    var complete = false;
    try {
      _value(await audio.activate());
      _check();
      final turn = _value(
        speech.startTurn(
          typedText: 'lecture',
          responder: VoiceResponder(
            respond: (_) => Stream.value(text),
            stop: () async {},
          ),
          speak: true,
        ),
      );
      _turn = turn;
      // Listen immediately: VoiceTurn.interrupt relies on its event listener.
      await for (final event in turn.events) {
        _check();
        switch (event) {
          case VoiceReplyAudioEvent(
            :final pcm,
            :final sampleRate,
            :final isFinal,
          ):
            if (pcm.isNotEmpty) {
              final playback =
                  _playback ?? _value(audio.beginPlayback(sampleRate));
              _playback = playback;
              playback.enqueue(pcm);
            }
            if (isFinal) _playback?.end();
          case VoiceTurnCompleteEvent():
            complete = true;
          case VoiceTurnInterruptedEvent():
            throw const ModelCancelled();
          case VoiceErrorEvent(:final error):
            throw asException(error);
          default:
            break;
        }
      }
      _check();
      if (!complete || _playback == null) {
        throw const FormatException('Lecture audio incomplète.');
      }
      _playback!.end();
      await _playback!.drained;
      _check();
    } finally {
      await _playback?.stop();
      _playback = null;
      _turn = null;
      await audio.deactivate();
      _busy = false;
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    finishCapture();
    await _capture?.cancel();
    await _playback?.stop();
    await _turn?.interrupt();
  }
}
