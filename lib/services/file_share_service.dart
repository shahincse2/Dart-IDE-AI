import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'downloads_saver.dart';

/// What happened to an export.
class ExportOutcome {
  const ExportOutcome._(this.savedTo, this.failed);

  /// Saved; [where] says where, for the user to read.
  const ExportOutcome.saved(String where) : this._(where, false);

  /// The user closed the save dialog: nothing to report.
  const ExportOutcome.cancelled() : this._(null, false);

  /// It could not be saved.
  const ExportOutcome.failed() : this._(null, true);

  final String? savedTo;
  final bool failed;
}

class FileShareService {
  FileShareService({DownloadsSaver? downloads})
      : _downloads = downloads ?? DownloadsSaver();

  final DownloadsSaver _downloads;

  /// Saves a .dart file ON THE DEVICE, never to other apps (sharing is a
  /// separate menu item).
  ///
  /// On Android it goes straight into Downloads/DartLab: the system save
  /// dialog is not used, because on some phones that dialog crashes (and the
  /// app with it). Android 9 and older, and other systems, use the system
  /// save dialog.
  Future<ExportOutcome> exportDartFile({
    required String content,
    required String fileName,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    try {
      if (_downloads.isAvailable) {
        try {
          final where = await _downloads.save(fileName: fileName, bytes: bytes);
          return where == null
              ? const ExportOutcome.failed()
              : ExportOutcome.saved(where);
        } on UnsupportedError {
          // Android 9 or older: fall through to the save dialog.
        }
      }
      final saved = await FilePicker.saveFile(fileName: fileName, bytes: bytes);
      return saved == null
          ? const ExportOutcome.cancelled()
          : ExportOutcome.saved(saved.toString());
    } catch (_) {
      return const ExportOutcome.failed();
    }
  }

  /// Opens file picker so user can pick a .dart file from device.
  Future<({String content, String name})?> importDartFile() async {
    try {
      // file_picker 13.x-এ FilePicker.platform.pickFiles() আর নেই।
      // এখন স্ট্যাটিক FilePicker.pickFile() ব্যবহার করতে হয়,
      // যা সরাসরি PlatformFile? রিটার্ন করে।
      final PlatformFile? picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['dart'],
      );

      if (picked == null) return null; // ইউজার ক্যান্সেল করেছে

      // Files are UTF-8. (String.fromCharCodes would turn every non-ASCII
      // character, such as Bengali text in a comment, into garbage.)
      final content = utf8.decode(
        await picked.readAsBytes(),
        allowMalformed: true,
      );
      final name = picked.name;

      return (content: content, name: name);
    } catch (_) {
      return null;
    }
  }
}
