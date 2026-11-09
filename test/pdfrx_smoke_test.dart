import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

void main() {
  test('verify pdfrx and pdf engine symbols', () async {
    expect(PdfDocument, isNotNull);
    expect(PdfPageFormat.a4, isNotNull);

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(child: pw.Text('IT PDF Test Page')),
      ),
    );

    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
  });
}
