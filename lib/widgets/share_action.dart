import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Hands [text] to the app the user picks in the system share sheet, and says
/// how it went in a snack bar.
Future<void> shareCodeWithMessage(
  BuildContext context, {
  required String text,
  required String fileName,
}) async {
  // await করার আগেই context ক্যাপচার
  final messenger = ScaffoldMessenger.of(context);

  final result = await SharePlus.instance.share(
    ShareParams(text: text, subject: fileName),
  );

  if (!context.mounted) return;

  if (result.status == ShareResultStatus.success) {
    messenger.showSnackBar(
      SnackBar(content: Text('"$fileName" shared successfully')),
    );
  } else if (result.status == ShareResultStatus.dismissed) {
    messenger.showSnackBar(const SnackBar(content: Text('Share cancelled')));
  } else if (result.status == ShareResultStatus.unavailable) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No app available to share')),
    );
  }
}
