import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/features/reader/domain/reader_state.dart';
import 'package:it_pdf/features/reader/presentation/outline_drawer.dart';
import 'package:it_pdf/features/reader/presentation/reader_view_controls.dart';

void main() {
  group('ReaderViewControls Tests', () {
    testWidgets('renders current page, zoom percentage and triggers callbacks', (tester) async {
      bool zoomInTriggered = false;
      bool zoomOutTriggered = false;
      bool fitWidthTriggered = false;
      bool fitPageTriggered = false;
      int? jumpedPage;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderViewControls(
              currentPage: 3,
              pageCount: 15,
              currentZoom: 1.25,
              currentLayout: ReaderLayout.continuousVertical,
              onZoomIn: () => zoomInTriggered = true,
              onZoomOut: () => zoomOutTriggered = true,
              onSelectZoom: (_) {},
              onFitWidth: () => fitWidthTriggered = true,
              onFitPage: () => fitPageTriggered = true,
              onSelectLayout: (_) {},
              onJumpToPage: (page) => jumpedPage = page,
            ),
          ),
        ),
      );

      // Verify page indicator text
      expect(find.text('3 / 15'), findsOneWidget);
      // Verify zoom text (1.25 -> 125%)
      expect(find.text('125%'), findsOneWidget);

      // Tap Zoom In (+)
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(zoomInTriggered, isTrue);

      // Tap Zoom Out (-)
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(zoomOutTriggered, isTrue);

      // Tap Fit Width
      await tester.tap(find.byIcon(Icons.fit_screen));
      await tester.pump();
      expect(fitWidthTriggered, isTrue);

      // Tap Fit Page
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pump();
      expect(fitPageTriggered, isTrue);

      // Open Page Jump Dialog
      await tester.tap(find.text('3 / 15'));
      await tester.pumpAndSettle();
      expect(find.text('Go to Page'), findsOneWidget);

      // Enter page 8 and tap Go
      await tester.enterText(find.byType(TextField), '8');
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(jumpedPage, equals(8));
    });
  });

  group('OutlineDrawer Tests', () {
    testWidgets('renders empty bookmark state cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: OutlineDrawer(
              outline: const [],
              onSelect: (_) {},
            ),
            body: const Text('Content'),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Table of Contents'), findsOneWidget);
      expect(find.text('No Table of Contents'), findsOneWidget);
    });

    testWidgets('renders outline hierarchy and triggers onSelect callback with target', (tester) async {
      OutlineItem? selectedItem;
      final mockOutline = [
        const OutlineItem(title: 'Chapter 1: Genesis', targetPage: 1, level: 0),
        const OutlineItem(title: 'Section 1.1: Foundations', targetPage: 4, level: 1),
        const OutlineItem(title: 'Chapter 2: Architecture', targetPage: 12, level: 0),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: OutlineDrawer(
              outline: mockOutline,
              currentPage: 4,
              onSelect: (entry) => selectedItem = entry,
            ),
            body: const Text('Content'),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Chapter 1: Genesis'), findsOneWidget);
      expect(find.text('Section 1.1: Foundations'), findsOneWidget);
      expect(find.text('Chapter 2: Architecture'), findsOneWidget);
      expect(find.text('p. 4'), findsOneWidget);

      // Tap on Section 1.1
      await tester.tap(find.text('Section 1.1: Foundations'));
      await tester.pumpAndSettle();

      expect(selectedItem, isNotNull);
      expect(selectedItem!.targetPage, equals(4));
      expect(selectedItem!.title, equals('Section 1.1: Foundations'));
    });
  });
}
