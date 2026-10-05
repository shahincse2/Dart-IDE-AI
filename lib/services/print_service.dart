import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Converts Dart source code to PDF and triggers the system
/// print/share dialog. Completely decoupled from UI.
class PrintService {
  /// Shows the system print dialog for [source] code.
  /// [fileName] is used as the document title.
  Future<void> printCode({
    required String source,
    required String fileName,
  }) async {
    await Printing.layoutPdf(
      name: fileName,
      onLayout: (format) => _buildPdf(source, fileName, format),
    );
  }

  /// Shares the code as a PDF file via OS share sheet.
  Future<void> sharePdf({
    required String source,
    required String fileName,
  }) async {
    await Printing.sharePdf(
      bytes: await _buildPdf(source, fileName, PdfPageFormat.a4),
      filename: '${fileName.replaceAll('.dart', '')}.pdf',
    );
  }

  Future<Uint8List> _buildPdf(
    String source,
    String fileName,
    PdfPageFormat format,
  ) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.robotoMonoRegular();
    final lines = source.split('\n');

    // Split into pages of ~60 lines each so long files paginate cleanly.
    const linesPerPage = 60;
    final pages = <List<String>>[];
    for (var i = 0; i < lines.length; i += linesPerPage) {
      pages.add(lines.sublist(
        i,
        i + linesPerPage > lines.length ? lines.length : i + linesPerPage,
      ));
    }

    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final pageLines = pages[pageIndex];
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with file name and page number.
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    fileName,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Page ${pageIndex + 1} of ${pages.length}',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              // Code content with line numbers.
              ...pageLines.asMap().entries.map((entry) {
                final lineNum = pageIndex * linesPerPage + entry.key + 1;
                return pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 36,
                      child: pw.Text(
                        '$lineNum',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 9,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        entry.value,
                        style: pw.TextStyle(font: font, fontSize: 9),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      );
    }

    return doc.save();
  }
}
