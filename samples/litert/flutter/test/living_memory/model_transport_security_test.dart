import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/data/services/model_store/http_file_downloader.dart';
import 'package:litert_edge_demos/data/services/model_store/store_operation.dart';

import '../support/recording_reporter.dart';

void main() {
  for (final url in [
    'http://example.com/model',
    'https://user:secret@example.com/model',
    'https://example.com/model#private',
  ]) {
    test('rejects unsafe URL before creating a client: $url', () async {
      var created = false;
      final downloader = HttpFileDownloader(
        httpClient: () {
          created = true;
          throw StateError('network must not be created');
        },
      );
      await expectLater(
        downloader.probeSize('model', Uri.parse(url), CancelToken()),
        throwsFormatException,
      );
      expect(created, isFalse);
    });
  }
  for (final size in [0, -1, 17179869185]) {
    test('rejects invalid size before network or disk writes: $size', () async {
      final downloader = HttpFileDownloader(
        httpClient: () => throw StateError('network must not be created'),
      );
      await expectLater(
        downloader.download(
          RemoteFile(
            name: 'model',
            url: Uri.parse('https://example.com/model'),
            sizeBytes: size,
          ),
          File('/must-not-be-created'),
          CancelToken(),
          RecordingReporter(),
        ),
        throwsFormatException,
      );
    });
  }
}
