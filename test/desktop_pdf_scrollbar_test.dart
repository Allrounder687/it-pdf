import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:it_pdf/features/reader/presentation/desktop_pdf_scrollbar.dart';

void main() {
  testWidgets('DesktopPdfScrollbar renders vertically when content overflows', (
    tester,
  ) async {
    final controller = PdfViewerController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: DesktopPdfScrollbar(
              controller: controller,
              orientation: Axis.vertical,
              pageCount: 10,
              currentPage: 1,
            ),
          ),
        ),
      ),
    );

    // Initial state before viewer is ready should be empty without exceptions
    expect(find.byType(DesktopPdfScrollbar), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'DesktopPdfScrollbar renders horizontally without throwing errors',
    (tester) async {
      final controller = PdfViewerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: DesktopPdfScrollbar(
                controller: controller,
                orientation: Axis.horizontal,
                pageCount: 5,
                currentPage: 1,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DesktopPdfScrollbar), findsOneWidget);
      await tester.pumpAndSettle();
    },
  );
}
