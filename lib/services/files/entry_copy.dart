import 'dart:io';

import 'package:path/path.dart' as p;

/// Copies a file, or a folder with everything inside it, to [targetPath].
Future<void> copyTo(
  String source,
  String targetPath, {
  required bool isFolder,
}) async {
  if (isFolder) {
    await copyDirectory(Directory(source), Directory(targetPath));
  } else {
    await File(source).copy(targetPath);
  }
}

Future<void> copyDirectory(Directory from, Directory to) async {
  await to.create(recursive: true);
  await for (final entity in from.list()) {
    final name = p.basename(entity.path);
    if (entity is Directory) {
      await copyDirectory(entity, Directory(p.join(to.path, name)));
    } else if (entity is File) {
      await entity.copy(p.join(to.path, name));
    }
  }
}
