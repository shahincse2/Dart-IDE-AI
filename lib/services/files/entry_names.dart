import 'dart:io';

import 'package:path/path.dart' as p;

/// Strips path separators and trims whitespace so a user-typed name
/// can't escape its intended directory or produce an empty/invalid
/// filesystem entry.
String sanitizeName(String input, {required String fallback}) {
  final cleaned = input.replaceAll(RegExp(r'[\\/]'), '').trim();
  return cleaned.isEmpty ? fallback : cleaned;
}

Future<String> uniqueDirName(Directory parent, String name) async {
  var candidate = name;
  var attempt = 1;
  while (await Directory(p.join(parent.path, candidate)).exists()) {
    attempt++;
    candidate = '$name ($attempt)';
  }
  return candidate;
}

Future<String> uniqueFileName(Directory parent, String name) async {
  final ext = p.extension(name);
  final base = p.basenameWithoutExtension(name);
  var candidate = name;
  var attempt = 1;
  while (await File(p.join(parent.path, candidate)).exists()) {
    attempt++;
    candidate = '$base ($attempt)$ext';
  }
  return candidate;
}

Future<String> uniqueName(
  Directory parent,
  String name, {
  required bool isFolder,
}) =>
    isFolder ? uniqueDirName(parent, name) : uniqueFileName(parent, name);

/// True if [path] is [folder] itself or lies below it.
bool isInside(String path, String folder) =>
    path == folder || path.startsWith('$folder/');
