import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Saves console output as a standalone `.txt` file (Section 28).
///
/// Deliberately independent of the project file system that Phase 5
/// builds — these are export snapshots of a console run, not part of
/// any Dart project, so they live in their own subfolder under the
/// app's documents directory rather than waiting on FileManagerService.
class ConsoleExportService {
  static Future<String> saveAsText(String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory('${dir.path}/console_exports');
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File('${exportsDir.path}/output_$timestamp.txt');
    await file.writeAsString(content);
    return file.path;
  }
}
