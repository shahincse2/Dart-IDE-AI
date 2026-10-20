import 'package:flutter/material.dart';

import '../services/file_share_service.dart';
import 'overlay_message.dart';

/// Exports a file to the device and tells the user how it went: where it was
/// saved, or that it could not be. Closing the save dialog says nothing.
Future<void> exportWithMessage(
  BuildContext context, {
  required String content,
  required String fileName,
  FileShareService? service,
}) async {
  // Taken before the await, so no BuildContext is needed afterwards.
  final overlay = Overlay.of(context, rootOverlay: true);
  final outcome = await (service ?? FileShareService())
      .exportDartFile(content: content, fileName: fileName);

  final savedTo = outcome.savedTo;
  if (savedTo != null) {
    showOverlayMessage(
      overlay,
      'Saved to $savedTo',
      duration: const Duration(seconds: 6),
    );
  } else if (outcome.failed) {
    showOverlayMessage(
      overlay,
      'Could not save "$fileName"',
      duration: const Duration(seconds: 6),
    );
  }
}
