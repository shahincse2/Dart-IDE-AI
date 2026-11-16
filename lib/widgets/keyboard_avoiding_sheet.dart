import 'package:flutter/widgets.dart';

/// For a bottom sheet with a text field in it: keeps the sheet above the
/// keyboard. (`showModalBottomSheet` with `isScrollControlled` does not move
/// the sheet when the keyboard opens, so what is typed would be hidden.)
class KeyboardAvoidingSheet extends StatelessWidget {
  const KeyboardAvoidingSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child,
    );
  }
}
