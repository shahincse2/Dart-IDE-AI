import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

class FileShareService {
  /// Exports (shares) a .dart file via the OS share sheet.
  Future<bool> exportDartFile({
    required String content,
    required String fileName,
  }) async {
    try {
      final tempDir = Directory.systemTemp;
      final file = File(p.join(tempDir.path, fileName));
      await file.writeAsString(content);

      // share_plus 13.x-এ স্ট্যাটিক Share.shareXFiles() ডেপ্রিকেটেড।
      // নতুন API হলো SharePlus.instance.share(ShareParams(...))।
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/plain')],
          subject: fileName,
        ),
      );

      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (_) {
      return false;
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

      // PlatformFile.readAsBytes() ব্যবহার করে ফাইল কনটেন্ট পড়া হয়।
      // এটি সব প্ল্যাটফর্মে (মোবাইল, ডেস্কটপ, ওয়েব) কাজ করে।
      final content = String.fromCharCodes(await picked.readAsBytes());
      final name = picked.name;

      return (content: content, name: name);
    } catch (_) {
      return null;
    }
  }
}