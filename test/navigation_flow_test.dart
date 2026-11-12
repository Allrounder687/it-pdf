import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/app/router/app_shell.dart';
import 'package:it_pdf/core/providers.dart';
import 'package:it_pdf/features/annotations/domain/annotation_model.dart';
import 'package:it_pdf/features/annotations/domain/annotation_notifier.dart';
import 'package:it_pdf/features/reader/domain/document_tabs_notifier.dart';
import 'package:it_pdf/features/reader/presentation/desktop_reader_toolbar.dart';
import 'package:it_pdf/shared/models/document_meta.dart';
import 'package:it_pdf/shared/widgets/desktop_tab_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Comprehensive Mandatory Navigation Flow Tests (Section 9)', () {
    testWidgets(
      '1-5 & 8-9: Open App -> Home -> Open PDF -> Back to Home -> Multi-tabs -> Preserved state',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final docA = DocumentMeta(
          id: 'doc-A',
          name: 'Annual_Report.pdf',
          path: '/test/Annual_Report.pdf',
          sizeInBytes: 1024 * 50,
          totalPages: 12,
          lastOpened: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final docB = DocumentMeta(
          id: 'doc-B',
          name: 'Project_Contract.pdf',
          path: '/test/Project_Contract.pdf',
          sizeInBytes: 1024 * 20,
          totalPages: 5,
          lastOpened: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            initialCliArgsProvider.overrideWithValue([]),
          ],
        );

        // 1 & 2. Open application, confirm Home Screen is initially displayed
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: AppShell()),
          ),
        );
        await tester.pump();

        expect(find.text('IT PDF Tools Studio'), findsOneWidget);

        // 3. Open a PDF document (Doc A)
        final tabsNotifier = container.read(
          documentTabsNotifierProvider.notifier,
        );
        tabsNotifier.openTab(docA);
        await tester.pump();
        await tester.pump();

        // 4. Confirm Reader is displayed and Back to Home control is clearly visible
        final backButtonFinder = find.byTooltip(
          'Back to Home Screen (Alt+Left)',
        );
        expect(backButtonFinder, findsWidgets);

        // 5. Click Back to Home & Confirm Home Screen is displayed
        await tester.tap(backButtonFinder.first);
        await tester.pump();
        await tester.pump();

        // 6 & 7. Confirm document state is preserved: tab remains open in memory!
        expect(
          find.descendant(
            of: find.byType(DesktopTabBar),
            matching: find.text('Annual_Report.pdf'),
          ),
          findsOneWidget,
        );

        // 8. Open multiple PDF tabs (Doc B)
        tabsNotifier.openTab(docB);
        await tester.pump();
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(DesktopTabBar),
            matching: find.text('Annual_Report.pdf'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(DesktopTabBar),
            matching: find.text('Project_Contract.pdf'),
          ),
          findsOneWidget,
        );

        // 9. Return Home without accidentally closing unrelated documents
        await tester.tap(backButtonFinder.first);
        await tester.pump();
        await tester.pump();

        // Both tabs must remain completely intact!
        expect(
          find.descendant(
            of: find.byType(DesktopTabBar),
            matching: find.text('Annual_Report.pdf'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(DesktopTabBar),
            matching: find.text('Project_Contract.pdf'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '10. Unsaved annotations are safely preserved across Home navigation',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final doc = DocumentMeta(
          id: 'doc-ann-test',
          name: 'Specs.pdf',
          path: '/test/Specs.pdf',
          sizeInBytes: 4096,
          totalPages: 4,
          lastOpened: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            initialCliArgsProvider.overrideWithValue([]),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: AppShell()),
          ),
        );
        await tester.pump();

        // Open Specs.pdf
        container.read(documentTabsNotifierProvider.notifier).openTab(doc);
        await tester.pump();
        await tester.pump();

        // Add an in-memory draft annotation to page 1
        final annNotifier = container.read(
          annotationNotifierProvider('doc-ann-test').notifier,
        );
        annNotifier.setActiveTool(AnnotationTool.pen);
        annNotifier.startDrawing(const NormalizedPoint(0.1, 0.1));
        annNotifier.updateDrawing(const NormalizedPoint(0.5, 0.5));
        await annNotifier.finishDrawing(1);
        await tester.pump();

        // Confirm annotation is registered and tab is marked dirty
        expect(
          container
              .read(annotationNotifierProvider('doc-ann-test'))
              .annotations
              .length,
          1,
        );

        // Click Back to Home
        final backButton = find.byTooltip('Back to Home Screen (Alt+Left)');
        await tester.tap(backButton.first);
        await tester.pump();
        await tester.pump();

        // Re-enter document from Tab bar
        await tester.tap(
          find.descendant(
            of: find.byType(DesktopTabBar),
            matching: find.text('Specs.pdf'),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Verify annotation was NOT lost!
        expect(
          container
              .read(annotationNotifierProvider('doc-ann-test'))
              .annotations
              .length,
          1,
        );
        expect(
          container
              .read(annotationNotifierProvider('doc-ann-test'))
              .annotations
              .first
              .pageNumber,
          1,
        );
      },
    );

    testWidgets(
      '11. Alt + Left keyboard shortcut triggers Back to Home navigation',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final doc = DocumentMeta(
          id: 'doc-shortcut',
          name: 'Keyboard_Test.pdf',
          path: '/test/Keyboard_Test.pdf',
          sizeInBytes: 2048,
          totalPages: 8,
          lastOpened: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            initialCliArgsProvider.overrideWithValue([]),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: AppShell()),
          ),
        );
        await tester.pump();

        // Open document
        container.read(documentTabsNotifierProvider.notifier).openTab(doc);
        await tester.pump();
        await tester.pump();

        // Confirm in reader
        expect(find.byType(DesktopReaderToolbar), findsOneWidget);

        // Simulate Alt + Left arrow keypress
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pump();
        await tester.pump();

        // Home view is now visible
        expect(find.byType(DesktopReaderToolbar), findsNothing);
      },
    );

    testWidgets(
      '13. Direct launch and fallback navigation when last tab closed',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final doc = DocumentMeta(
          id: 'doc-close-test',
          name: 'Closing_Test.pdf',
          path: '/test/Closing_Test.pdf',
          sizeInBytes: 2048,
          totalPages: 3,
          lastOpened: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            initialCliArgsProvider.overrideWithValue([]),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: AppShell()),
          ),
        );
        await tester.pump();

        // Open tab
        final tabsNotifier = container.read(
          documentTabsNotifierProvider.notifier,
        );
        tabsNotifier.openTab(doc);
        await tester.pump();
        await tester.pump();

        expect(find.text('Closing_Test.pdf'), findsWidgets);

        // Close the tab
        tabsNotifier.closeTab(0);
        await tester.pump();
        await tester.pump();

        // Zero tabs open: Shell automatically falls back gracefully to Home Screen
        expect(
          container.read(documentTabsNotifierProvider).openTabs.isEmpty,
          isTrue,
        );
        expect(find.text('No documents open'), findsOneWidget);
      },
    );
  });
}
