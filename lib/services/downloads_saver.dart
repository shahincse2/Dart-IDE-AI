import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Saves a file straight into the public Downloads folder on Android
/// (through MediaStore, see DownloadsChannel.kt): no file picker is opened
/// and no storage permission is needed.
class DownloadsSaver {
  static const MethodChannel _channel = MethodChannel('dartlab/downloads');

  /// Only Android has this; elsewhere use the system save dialog.
  bool get isAvailable => Platform.isAndroid;

  /// Returns where the file was saved (for example `Download/DartLab/a.dart`),
  /// or null if saving failed.
  ///
  /// Throws [UnsupportedError] when the phone is too old (before Android 10);
  /// the caller should then use the system save dialog instead.
  Future<String?> save({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'text/plain',
    String subfolder = 'DartLab',
  }) async {
    try {
      return await _channel.invokeMethod<String>('saveToDownloads', {
        'fileName': fileName,
        'bytes': bytes,
        'mimeType': mimeType,
        'subfolder': subfolder,
      });
    } on PlatformException catch (error) {
      if (error.code == 'unsupported') {
        throw UnsupportedError(error.message ?? 'Saving to Downloads is not supported');
      }
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
