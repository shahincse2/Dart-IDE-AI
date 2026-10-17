import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../../utils/transfer_destinations.dart';

/// The folders offered by the copy/move dialog, indented like the tree, with
/// a spinner while they are being read and a note if there is nothing to show.
class TransferFolderList extends StatelessWidget {
  const TransferFolderList({
    super.key,
    required this.destinations,
    required this.onPick,
  });

  final Future<List<TransferDestination>> destinations;
  final ValueChanged<TransferDestination> onPick;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TransferDestination>>(
      future: destinations,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _Note('Could not read this project.');
        }
        final folders = snapshot.data;
        if (folders == null) {
          return const Padding(
            padding: EdgeInsets.all(AppConstants.spaceMd),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (folders.isEmpty) return const _Note('No folder to choose here.');
        return ListView(
          shrinkWrap: true,
          children: [
            for (final folder in folders)
              ListTile(
                dense: true,
                contentPadding: EdgeInsetsDirectional.only(
                  start: AppConstants.spaceMd + folder.depth * AppConstants.spaceLg,
                  end: AppConstants.spaceMd,
                ),
                leading: const Icon(Icons.folder_outlined, size: 20),
                title: Text(folder.label, overflow: TextOverflow.ellipsis),
                onTap: () => onPick(folder),
              ),
          ],
        );
      },
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}
