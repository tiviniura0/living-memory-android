import 'dart:convert';

import 'package:crypto/crypto.dart';

String memoryAgentKey(String worldId, String agentId) =>
    sha256.convert(utf8.encode('$worldId\u0000$agentId')).toString();
