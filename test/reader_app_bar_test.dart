import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/features/reader/domain/reader_state.dart';
import 'package:it_pdf/features/reader/presentation/reader_app_bar.dart';

void main() {
  group('ReaderAppBar Responsive Tests', () {
    testWidgets('renders desktop actions on wide screens', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: ReaderAppBar(
              documentName: 'test.pdf',
              currentPage: 1,
              pageCount: 5,
              currentZoom: 1.0,
              currentLayout: ReaderLayout.continuousVertical,
              themeMode: ReaderThemeMode.light,
              isToolActive: false,
              hasAnnotations: false,
              isSearchActive: false,
              isSearchReady: true,
              showThumbnails: false,
              onZoomIn: () {},
              onZoomOut: () {},
              onSelectZoom: (_) {},
              onFitWidth: () {},
              onFitPage: () {},
              onSelectLayout: (_) {},
              onJumpToPage: (_) {},
              onOpenOutline: () {},
              onOpenAiAssistant: () {},
              onToggleSearch: () {},
              onToggleThumbnails: () {},
              onCycleTheme: () {},
              onToggleAnnotations: () {},
              onSaveAnnotations: () {},
              onOpenOrganizer: () {},
              onOpenForms: () {},
              onOpenProtect: () {},
            ),
          ),
        ),
      );

      expect(find.text('test.pdf'), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.byIcon(Icons.bookmarks_outlined), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('renders mobile compact overflow layout on narrow screens', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: ReaderAppBar(
              documentName: 'mobile_doc.pdf',
              currentPage: 2,
              pageCount: 10,
              currentZoom: 1.0,
              currentLayout: ReaderLayout.continuousVertical,
              themeMode: ReaderThemeMode.light,
              isToolActive: false,
              hasAnnotations: false,
              isSearchActive: false,
              isSearchReady: true,
              showThumbnails: false,
              onZoomIn: () {},
              onZoomOut: () {},
              onSelectZoom: (_) {},
              onFitWidth: () {},
              onFitPage: () {},
              onSelectLayout: (_) {},
              onJumpToPage: (_) {},
              onOpenOutline: () {},
              onOpenAiAssistant: () {},
              onToggleSearch: () {},
              onToggleThumbnails: () {},
              onCycleTheme: () {},
              onToggleAnnotations: () {},
              onSaveAnnotations: () {},
              onOpenOrganizer: () {},
              onOpenForms: () {},
              onOpenProtect: () {},
            ),
          ),
        ),
      );

      expect(find.text('mobile_doc.pdf'), findsOneWidget);
      expect(find.text('2 / 10'), findsOneWidget);
      // Overflow menu should exist and not cause horizontal overflow
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
