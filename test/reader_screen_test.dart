import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/core/providers.dart';
import 'package:it_pdf/features/reader/domain/reader_notifier.dart';
import 'package:it_pdf/features/reader/presentation/reader_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  testWidgets(
    'ReaderScreen mounts and initializes without throwing null check errors',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final tempDir = Directory.systemTemp.createTempSync('reader_test_');
      final dummyPdfPath = '${tempDir.path}/test.pdf';
      final doc = sf.PdfDocument();
      doc.pages.add();
      File(dummyPdfPath).writeAsBytesSync(doc.saveSync());
      doc.dispose();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            home: ReaderScreen(
              params: ReaderNotifierParams(
                id: 'test-doc-1',
                name: 'test.pdf',
                path: dummyPdfPath,
                initialPage: 1,
                initialPageCount: 1,
              ),
            ),
          ),
        ),
      );

      // Initial pump must not throw Null check operator used on a null value
      expect(tester.takeException(), isNull);
      expect(find.byType(ReaderScreen), findsOneWidget);

      tempDir.deleteSync(recursive: true);
    },
  );
}
