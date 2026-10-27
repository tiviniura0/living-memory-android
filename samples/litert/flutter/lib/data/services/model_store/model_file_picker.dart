// Copyright 2026 The Google AI Edge Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

import '../../../domain/ports/model_file_picker.dart';

/// [ModelFilePicker] over file_selector 1.1.0.
final class FileSelectorModelFilePicker implements ModelFilePicker {
  const FileSelectorModelFilePicker();

  @override
  ImportSupport get support {
    if (Platform.isAndroid) return const ImportFromFiles();
    if (Platform.isIOS) return const ImportFromFiles();
    return const ImportFromFolder();
  }

  @override
  Future<String?> pickModelFile() async {
    if (Platform.isAndroid) {
      return const MethodChannel('living_memory/documents')
          .invokeMethod<String>('pickModel');
    }
    final group = Platform.isIOS
        ? const XTypeGroup(
            label: 'LiteRT-LM model',
            uniformTypeIdentifiers: ['public.data'],
          )
        : const XTypeGroup(label: 'LiteRT-LM model', extensions: ['litertlm']);
    final file = await openFile(
      acceptedTypeGroups: [group],
      confirmButtonText: 'Import',
    );
    return file?.path;
  }

  /// iOS: file_selector_ios opens the document picker `in: .import`, which
  /// copies each pick into `tmp/<bundle id>-Inbox/`: under
  /// `NSTemporaryDirectory()` (`Directory.systemTemp`), not under
  /// path_provider's `getTemporaryDirectory()` (the Caches folder).
  @override
  Future<String?> temporaryCopiesDirectory() async {
    if (Platform.isAndroid) {
      return const MethodChannel('living_memory/documents')
          .invokeMethod<String>('modelCache');
    }
    return Platform.isIOS ? Directory.systemTemp.path : null;
  }
}
