import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'downloads_saver.dart';
import 'system_file_chooser.dart';

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

/// The name a picked file gets inside a project. Files saved as text by other
/// tools or by older exports (`main.dart.txt`, `notes.txt`) become Dart files.
String cleanImportedName(String name) {
  if (!name.toLowerCase().endsWith('.txt')) return name;
  final base = name.substring(0, name.length - 4);
  return base.toLowerCase().endsWith('.dart') ? base : '$base.dart';
}

class FileShareService {
  FileShareService({DownloadsSaver? downloads, SystemFileChooser? chooser})
      : _downloads = downloads ?? DownloadsSaver(),
        _chooser = chooser ?? SystemFileChooser();

  final DownloadsSaver _downloads;
  final SystemFileChooser _chooser;

  /// Saves a .dart file ON THE DEVICE, never to other apps (sharing is a
  /// separate menu item).
  ///
  /// On Android it goes straight into Downloads/DartLab under its own name:
  /// the system save dialog is not used, because on some phones that dialog
  /// crashes (and the app with it). Android 9 and older, and other systems,
  /// use the system save dialog.
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

  /// Lets the user pick a file from the device: Android's own file list on
  /// Android, the file_picker plugin elsewhere.
  Future<({String content, String name})?> importDartFile() async {
    try {
      final picked =
          _chooser.isAvailable ? await _chooser.pick() : await _pickWithPlugin();
      if (picked == null) return null; // ইউজার ক্যান্সেল করেছে

      // Files are UTF-8. (String.fromCharCodes would turn every non-ASCII
      // character, such as Bengali text in a comment, into garbage.)
      final content = utf8.decode(picked.bytes, allowMalformed: true);
      return (content: content, name: cleanImportedName(picked.name));
    } catch (_) {
      return null;
    }
  }

  Future<({String name, Uint8List bytes})?> _pickWithPlugin() async {
    // file_picker 13.x-এ FilePicker.platform.pickFiles() আর নেই।
    // এখন স্ট্যাটিক FilePicker.pickFile() ব্যবহার করতে হয়।
    final PlatformFile? picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['dart', 'txt'],
    );
    if (picked == null) return null;
    return (name: picked.name, bytes: await picked.readAsBytes());
  }
}
