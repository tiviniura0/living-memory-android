import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'security.dart';

class McpProtocolException implements Exception {
  const McpProtocolException();
  @override
  String toString() => 'MCP response refused';
}

/// Restricted stateless 2026-07-28 tools subset. Results remain untrusted data.
/// No initialize, session, GET subscription, sampling or automatic retry.
final class McpClient {
  McpClient({this.endpoint, HttpClient Function()? httpClientFactory,
    bool allowLoopbackForTests = false, Set<String> allowedTools = const {},
    this.maxResponseBytes = 1048576, this.timeout = const Duration(seconds: 15)})
      : _factory = httpClientFactory ?? HttpClient.new,
        _allowedTools = Set.unmodifiable(allowedTools) {
    final uri = endpoint;
    if (maxResponseBytes < 1 || maxResponseBytes > 1048576 || timeout <= Duration.zero || timeout > const Duration(seconds: 60)) throw ArgumentError('Invalid transport limits');
    if (uri != null && (uri.host.isEmpty || uri.userInfo.isNotEmpty || uri.hasFragment ||
        (uri.scheme != 'https' && !(allowLoopbackForTests && uri.scheme == 'http' && ['127.0.0.1', '::1'].contains(uri.host))))) throw const ExtensionDenied();
  }
  final Uri? endpoint;
  final HttpClient Function() _factory;
  final Set<String> _allowedTools;
  final int maxResponseBytes;
  final Duration timeout;
  int _sequence = 0;
  Future<Map<String, Object?>> listTools() => _request('tools/list', {});
  Future<Map<String, Object?>> callTool(String name, Map<String, Object?> arguments) {
    if (!_allowedTools.contains(name)) return Future.error(const ExtensionDenied());
    return _request('tools/call', {'name': name, 'arguments': frozenJson(arguments)});
  }
  static String _header(String value) {
    if (value.trim() != value || value.runes.any((c) => c < 32 || c > 126) || (value.startsWith('=?base64?') && value.endsWith('?='))) return '=?base64?${base64.encode(utf8.encode(value))}?=';
    return value;
  }
  Future<Map<String, Object?>> _request(String method, Map<String, Object?> params) async {
    final uri = endpoint;
    if (uri == null) throw const ExtensionDenied();
    final client = _factory();
    try {
      return await (() async {
        final id = ++_sequence;
        final request = await client.postUrl(uri);
        request.followRedirects = false;
        request.headers.contentType = ContentType.json;
        request.headers.set('Accept', 'application/json, text/event-stream');
        request.headers.set('MCP-Protocol-Version', '2026-07-28');
        request.headers.set('Mcp-Method', method);
        if (params['name'] is String) request.headers.set('Mcp-Name', _header(params['name']! as String));
        request.write(jsonEncode({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': {...params, '_meta': {
          'io.modelcontextprotocol/protocolVersion': '2026-07-28',
          'io.modelcontextprotocol/clientInfo': {'name': 'living-memory', 'version': '1.4'},
          'io.modelcontextprotocol/clientCapabilities': <String, Object?>{},
        }}}));
        final response = await request.close();
        if (response.statusCode != 200 || response.contentLength > maxResponseBytes) throw const McpProtocolException();
        final mime = response.headers.contentType?.mimeType;
        if (mime != 'application/json' && mime != 'text/event-stream') throw const McpProtocolException();
        final bytes = <int>[];
        // Both bytes and total wall time are bounded, including an SSE peer that
        // never closes the response. Client.close cancels the socket on timeout.
        await for (final chunk in response) {
          if (bytes.length + chunk.length > maxResponseBytes) throw const McpProtocolException();
          bytes.addAll(chunk);
        }
        final text = utf8.decode(bytes);
        if (mime == 'application/json') return _result(jsonDecode(text), id);
        Map<String, Object?>? finalResult;
        for (final event in text.replaceAll('\r\n', '\n').split('\n\n')) {
          final data = event.split('\n').where((line) => line.startsWith('data:')).map((line) => line.substring(5).replaceFirst(RegExp(r'^ '), '')).join('\n');
          if (data.isEmpty) continue;
          final message = jsonDecode(data);
          if (message is Map && !message.containsKey('id') && message['method'] == 'notifications/progress') continue;
          if (message is Map && !message.containsKey('id') && message['method'] == 'notifications/message') continue;
          if (finalResult != null) throw const McpProtocolException();
          finalResult = _result(message, id);
        }
        if (finalResult == null) throw const McpProtocolException();
        return finalResult;
      })().timeout(timeout);
    } on ExtensionDenied { rethrow;
    } on McpProtocolException { rethrow;
    } catch (_) { throw const McpProtocolException();
    } finally { client.close(force: true); }
  }
  Map<String, Object?> _result(Object? message, int id) {
    if (message is! Map<String, dynamic> || message['jsonrpc'] != '2.0' || message['id'] != id || message.containsKey('error') || message.containsKey('method') || message['result'] is! Map<String, dynamic>) throw const McpProtocolException();
    final result = message['result'] as Map<String, dynamic>;
    // Embedded input requests cannot grant server capabilities.
    if (result.containsKey('inputRequests') || result.containsKey('inputRequired')) throw const McpProtocolException();
    return frozenJson(result);
  }
}
