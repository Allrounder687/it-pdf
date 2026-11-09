import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  test('verify pdfrx and syncfusion baseline instantiation', () {
    expect(PdfTextSearcher, isNotNull);
    final doc = sf.PdfDocument();
    doc.pages.add();
    expect(doc.pages.count, 1);
    doc.dispose();
  });
}
