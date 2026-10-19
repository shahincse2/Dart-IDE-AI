import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/constants.dart';

OverlayEntry? _current;
Timer? _timer;

/// Shows [message] at the bottom of the screen for a few seconds, ABOVE
/// everything, the open drawer included. (A SnackBar belongs to the page
/// under the drawer, so a message that starts in the drawer would be hidden
/// behind it.) A new message replaces the one still showing.
///
/// Take [overlay] with `Overlay.of(context, rootOverlay: true)` BEFORE any
/// `await`, so no BuildContext is needed afterwards.
void showOverlayMessage(
  OverlayState overlay,
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  _timer?.cancel();
  _close(_current);

  final entry = OverlayEntry(builder: (_) => _MessageBar(message: message));
  overlay.insert(entry);
  _current = entry;
  _timer = Timer(duration, () {
    if (identical(_current, entry)) _current = null;
    _close(entry);
  });
}

void _close(OverlayEntry? entry) {
  if (entry == null || !entry.mounted) return;
  entry.remove();
  entry.dispose();
}

class _MessageBar extends StatelessWidget {
  const _MessageBar({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          // Only a message: it must not block taps on what is under it.
          child: IgnorePointer(
            child: Material(
              color: scheme.inverseSurface,
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  message,
                  style: TextStyle(color: scheme.onInverseSurface),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
