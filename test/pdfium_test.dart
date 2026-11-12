import 'package:flutter_test/flutter_test.dart';
import 'package:pdfium_dart/pdfium_dart.dart';

void main() {
  test('PDFium FFI bindings load and initialize correctly', () {
    final pdfium = getPdfium();
    expect(pdfium, isNotNull);
    pdfium.FPDF_InitLibrary();

    final doc = pdfium.FPDF_CreateNewDocument();
    expect(doc.address != 0, isTrue);

    final page = pdfium.FPDFPage_New(doc, 0, 612.0, 792.0);
    expect(page.address != 0, isTrue);

    final count = pdfium.FPDFPage_CountObjects(page);
    expect(count, equals(0));

    pdfium.FPDF_ClosePage(page);
    pdfium.FPDF_CloseDocument(doc);
    pdfium.FPDF_DestroyLibrary();
  });
}
