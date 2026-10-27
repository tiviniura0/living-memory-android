import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:litert_edge_demos/living_memory/memory_chunker.dart';

void main() {
  test('multibyte chunks preserve all characters within UTF-8 budget', () {
    final text = List.filled(900, '🌺é漢').join();
    final chunks = chunkPages([text]);
    expect(chunks.map((c) => c.text).join(), text);
    expect(chunks.every((c) => utf8.encode(c.text).length <= 700), isTrue);
    expect(chunks.every((c) => !c.text.contains('\uFFFD')), isTrue);
  });
  test('PDF page numbers survive blank pages and chunking', () {
    final chunks = chunkPages(['Page une', '', 'Page trois']);
    expect(chunks.map((c) => c.page), [1, 3]);
    expect(chunks.map((c) => c.ordinal), [1, 2]);
  });
  test('empty documents are rejected', () {
    expect(() => chunkPages([' ', '\n']), throwsFormatException);
  });
  test('oversized corpus is rejected before embedding', () {
    expect(
      () => chunkPages([List.filled(10001, 'a' * 700).join()]),
      throwsFormatException,
    );
  });
}
