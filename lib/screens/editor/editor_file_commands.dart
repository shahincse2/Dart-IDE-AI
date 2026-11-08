import 'package:flutter/widgets.dart';

import '../../providers/file_provider.dart';
import '../../services/file_share_service.dart';
import '../../services/print_service.dart';
import '../../widgets/export_action.dart';
import '../../widgets/file_tree/import_action.dart';
import '../../widgets/share_action.dart';
import 'editor_controllers.dart';

/// The name of the file at [path] (the part after the last `/`).
String fileNameOf(String path) => path.split('/').last;

/// What the editor does with the file being edited: save it, export it, import
/// another, share it, print it.
class EditorFileCommands {
  EditorFileCommands({
    required BuildContext Function() context,
    required FileProvider files,
    required EditorControllers editors,
    FileShareService? shareService,
    PrintService? printService,
  })  : _context = context,
        _files = files,
        _editors = editors,
        _shareService = shareService ?? FileShareService(),
        _printService = printService ?? PrintService();

  final BuildContext Function() _context;
  final FileProvider _files;
  final EditorControllers _editors;
  final FileShareService _shareService;
  final PrintService _printService;

  void save() => _editors.withActive((path, c) => _files.saveNow(path, c.text));

  /// Saves the file ON THE DEVICE (Downloads/DartLab on Android) and says where.
  void export() => _editors.withActive(
        (path, c) => exportWithMessage(
          _context(),
          content: c.text,
          fileName: fileNameOf(path),
          service: _shareService,
        ),
      );

  /// The file goes into the folder last tapped in the file tree, or the folder
  /// of the file being edited (see [importIntoCurrentFolder]).
  Future<void> importFile() =>
      importIntoCurrentFolder(_context(), service: _shareService);

  void shareCode() => _editors.withActive(
        (path, c) => shareCodeWithMessage(
          _context(),
          text: c.text,
          fileName: fileNameOf(path),
        ),
      );

  void printCode() => _editors.withActive(
        (path, c) =>
            _printService.printCode(source: c.text, fileName: fileNameOf(path)),
      );

  void sharePdf() => _editors.withActive(
        (path, c) =>
            _printService.sharePdf(source: c.text, fileName: fileNameOf(path)),
      );
}
