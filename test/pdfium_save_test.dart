import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfium_dart/pdfium_dart.dart';

BytesBuilder _saveBuffer = BytesBuilder();

int _customWriteBlock(
  Pointer<FPDF_FILEWRITE> pThis,
  Pointer<Void> pData,
  int size,
) {
  final bytes = pData.cast<Uint8>().asTypedList(size);
  _saveBuffer.add(bytes);
  return 1;
}

void main() {
  test('PDFium FFI save using Pointer.fromFunction', () {
    final pdfium = getPdfium();
    pdfium.FPDF_InitLibrary();

    final doc = pdfium.FPDF_CreateNewDocument();
    final page = pdfium.FPDFPage_New(doc, 0, 612.0, 792.0);

    // Create a font and text object
    final fontName = 'Helvetica-Bold'.toNativeUtf8();
    final font = pdfium.FPDFText_LoadStandardFont(doc, fontName.cast());
    calloc.free(fontName);

    final textObj = pdfium.FPDFPageObj_CreateTextObj(doc, font, 24.0);
    final textUnits = 'Hello PDFium World'.codeUnits;
    final textPtr = calloc<Uint16>(textUnits.length + 1);
    for (var i = 0; i < textUnits.length; i++) {
      textPtr[i] = textUnits[i];
    }
    textPtr[textUnits.length] = 0;
    pdfium.FPDFText_SetText(textObj, textPtr.cast());
    calloc.free(textPtr);

    // Position at (100, 700)
    pdfium.FPDFPageObj_Transform(textObj, 1.0, 0.0, 0.0, 1.0, 100.0, 700.0);
    pdfium.FPDFPage_InsertObject(page, textObj);
    final genRes = pdfium.FPDFPage_GenerateContent(page);
    expect(genRes, equals(1));

    // Save
    _saveBuffer.clear();
    final fw = calloc<FPDF_FILEWRITE>();
    fw.ref.version = 1;
    fw.ref.WriteBlock =
        Pointer.fromFunction<
          Int Function(Pointer<FPDF_FILEWRITE>, Pointer<Void>, UnsignedLong)
        >(_customWriteBlock, 0);

    final saveRes = pdfium.FPDF_SaveAsCopy(doc, fw, 0);
    expect(saveRes, equals(1));
    calloc.free(fw);

    final savedBytes = _saveBuffer.takeBytes();
    expect(savedBytes.length, greaterThan(100));

    pdfium.FPDF_ClosePage(page);
    pdfium.FPDF_CloseDocument(doc);
    pdfium.FPDF_DestroyLibrary();

    // Verify written file is readable
    final tmpFile = File('test_dart_created.pdf');
    tmpFile.writeAsBytesSync(savedBytes);
    expect(tmpFile.existsSync(), isTrue);
    tmpFile.deleteSync();
  });
}
