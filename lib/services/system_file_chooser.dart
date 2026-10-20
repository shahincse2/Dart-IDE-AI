import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Android's own "Choose a file" list (see ImportChannel.kt): every app that
/// offers files can show up in it, for example Samsung's My Files.
///
/// The Google Files picker used by the file_picker plugin shows "No items"
/// and no way to browse on some phones; this list does not have that problem.
class SystemFileChooser {
  static const MethodChannel _channel = MethodChannel('dartlab/import');

  /// Only Android has this; elsewhere use the file_picker plugin.
  bool get isAvailable => Platform.isAndroid;

  /// The file the user picked, or null if they cancelled or it could not be read.
  Future<({String name, Uint8List bytes})?> pick() async {
    try {
      final result =
          await _channel.invokeMapMethod<String, Object?>('pickFile');
      final name = result?['name'];
      final bytes = result?['bytes'];
      if (name is! String || bytes is! Uint8List) return null;
      return (name: name, bytes: bytes);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
