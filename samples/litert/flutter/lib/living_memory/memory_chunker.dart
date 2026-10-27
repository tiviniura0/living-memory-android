import 'dart:convert';

import 'memory_store.dart';

/// Conservative UTF-8 budget: below the embedder's 1024-token limit even
/// for byte-fallback scripts, with room for task prefixes and BOS/EOS.
List<MemoryChunk> chunkPages(List<String> pages) {
  final chunks = <MemoryChunk>[];
  for (var page = 0; page < pages.length; page++) {
    final buffer = StringBuffer();
    var bytes = 0;
    void flush() {
      final text = buffer.toString();
      if (text.trim().isNotEmpty) {
        chunks.add(
          MemoryChunk(page: page + 1, ordinal: chunks.length + 1, text: text),
        );
        if (chunks.length > 10000)
          throw const FormatException(
            'Document trop long : maximum 10 000 passages.',
          );
      }
      buffer.clear();
      bytes = 0;
    }

    for (final rune in pages[page].runes) {
      final char = String.fromCharCode(rune);
      final size = utf8.encode(char).length;
      if (bytes + size > 700) flush();
      buffer.write(char);
      bytes += size;
    }
    flush();
  }
  if (chunks.isEmpty)
    throw const FormatException(
      'Aucun texte : PDF scanné non pris en charge (pas d’OCR).',
    );
  return chunks;
}
