import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/app/router/app_shell.dart';
import 'package:it_pdf/core/providers.dart';
import 'package:it_pdf/features/reader/domain/document_tabs_notifier.dart';
import 'package:it_pdf/features/reader/domain/reader_state.dart';
import 'package:it_pdf/features/reader/presentation/desktop_reader_toolbar.dart';
import 'package:it_pdf/shared/models/document_meta.dart';
import 'package:it_pdf/shared/widgets/desktop_sidebar.dart';
import 'package:it_pdf/shared/widgets/desktop_status_bar.dart';
import 'package:it_pdf/shared/widgets/desktop_tab_bar.dart';
import 'package:it_pdf/shared/widgets/desktop_title_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DesktopTitleBar Tests', () {
    testWidgets('renders brand title, active doc, and triggers callbacks', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool openClicked = false;
      bool paletteClicked = false;
      bool themeClicked = false;
      bool shortcutsClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopTitleBar(
              activeDocumentName: 'annual_report_2026.pdf',
              isDirty: true,
              onOpenPdf: () => openClicked = true,
              onOpenCommandPalette: () => paletteClicked = true,
              onToggleTheme: () => themeClicked = true,
              onShowShortcuts: () => shortcutsClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('IT PDF'), findsOneWidget);
      expect(find.textContaining('annual_report_2026.pdf'), findsOneWidget);
      expect(find.text('Ctrl+K'), findsOneWidget);

      await tester.tap(find.text('Ctrl+K'));
      await tester.pump();
      expect(paletteClicked, isTrue);

      await tester.tap(find.byTooltip('Open PDF Document (Ctrl+O)'));
      await tester.pump();
      expect(openClicked, isTrue);

      await tester.tap(find.byTooltip('Toggle Theme'));
      await tester.pump();
      expect(themeClicked, isTrue);

      await tester.tap(find.byTooltip('Keyboard Shortcuts Reference'));
      await tester.pump();
      expect(shortcutsClicked, isTrue);
    });

    testWidgets(
      'renders Back to Home button when onBackToHome provided and triggers callback',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool backClicked = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DesktopTitleBar(
                activeDocumentName: 'annual_report_2026.pdf',
                onBackToHome: () => backClicked = true,
                onOpenPdf: () {},
                onOpenCommandPalette: () {},
                onToggleTheme: () {},
                onShowShortcuts: () {},
              ),
            ),
          ),
        );

        expect(
          find.byTooltip('Back to Home Screen (Alt+Left)'),
          findsOneWidget,
        );
        expect(find.text('Home'), findsOneWidget);
        await tester.tap(find.byTooltip('Back to Home Screen (Alt+Left)'));
        await tester.pump();
        expect(backClicked, isTrue);
      },
    );
  });

  group('DesktopTabBar Tests', () {
    testWidgets('renders empty state when zero tabs open', (tester) async {
      bool newTabClicked = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DesktopTabBar(onNewTab: () => newTabClicked = true),
            ),
          ),
        ),
      );

      expect(find.text('No documents open'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(newTabClicked, isTrue);
    });

    testWidgets(
      'renders open tabs, dirty dot, and allows switching and closing',
      (tester) async {
        final meta1 = DocumentMeta(
          id: 'doc-1',
          name: 'Chapter1.pdf',
          path: '/docs/Chapter1.pdf',
          sizeInBytes: 1024,
          totalPages: 20,
          lastOpened: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final meta2 = DocumentMeta(
          id: 'doc-2',
          name: 'Report.pdf',
          path: '/docs/Report.pdf',
          sizeInBytes: 2048,
          totalPages: 50,
          lastOpened: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final container = ProviderContainer();
        final notifier = container.read(documentTabsNotifierProvider.notifier);
        notifier.openTab(meta1);
        notifier.openTab(meta2);
        notifier.setTabDirty(1, true);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(body: DesktopTabBar(onNewTab: () {})),
            ),
          ),
        );

        expect(find.text('Chapter1.pdf'), findsOneWidget);
        expect(find.text('Report.pdf'), findsOneWidget);

        // Tap tab 0 to switch to Chapter1
        await tester.tap(find.text('Chapter1.pdf'));
        await tester.pump();
        expect(container.read(documentTabsNotifierProvider).activeIndex, 0);

        // Close tab 0
        await tester.tap(find.byIcon(Icons.close_rounded).first);
        await tester.pump();
        expect(container.read(documentTabsNotifierProvider).openTabs.length, 1);
        expect(
          container.read(documentTabsNotifierProvider).openTabs.first.name,
          'Report.pdf',
        );
      },
    );

    testWidgets('renders Back to Home tab button and triggers callback', (
      tester,
    ) async {
      bool backClicked = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DesktopTabBar(
                onNewTab: () {},
                onBackToHome: () => backClicked = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byTooltip('Back to Home Screen (Alt+Left)'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to Home Screen (Alt+Left)'));
      await tester.pump();
      expect(backClicked, isTrue);
    });
  });

  group('DesktopSidebar Tests', () {
    testWidgets('renders all destinations and toggles expanded width', (
      tester,
    ) async {
      DesktopNavDestination selectedDest = DesktopNavDestination.home;
      bool expanded = true;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: DesktopSidebar(
                  currentDestination: selectedDest,
                  isExpanded: expanded,
                  hasActiveDocument: true,
                  activeDocumentTitle: 'Sample.pdf',
                  onDestinationSelected: (dest) {
                    setState(() => selectedDest = dest);
                  },
                  onToggleExpanded: () {
                    setState(() => expanded = !expanded);
                  },
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('Tools Studio'), findsOneWidget);
      expect(find.text('Uploaded Files'), findsOneWidget);
      expect(find.text('Task History'), findsOneWidget);
      expect(find.text('Active Reader'), findsOneWidget);

      // Tap Task History destination
      await tester.tap(find.text('Task History'));
      await tester.pump();
      expect(selectedDest, DesktopNavDestination.recent);

      // Tap Collapse toggle
      await tester.tap(find.text('Collapse'));
      await tester.pumpAndSettle();
      expect(expanded, isFalse);
    });
  });

  group('DesktopStatusBar Tests', () {
    testWidgets('renders page progress, zoom %, and triggers layout changes', (
      tester,
    ) async {
      bool zoomInClicked = false;
      bool zoomOutClicked = false;
      bool fitWidthClicked = false;
      ReaderLayout? selectedLayout;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopStatusBar(
              documentPath: 'C:\\Users\\Documents\\Quarterly_Review.pdf',
              currentPage: 5,
              pageCount: 20,
              currentZoom: 1.25,
              currentLayout: ReaderLayout.continuousVertical,
              isLoading: false,
              statusMessage: 'Ready',
              onZoomIn: () => zoomInClicked = true,
              onZoomOut: () => zoomOutClicked = true,
              onFitWidth: () => fitWidthClicked = true,
              onLayoutChanged: (l) => selectedLayout = l,
            ),
          ),
        ),
      );

      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Page 5 of 20 (25%)'), findsOneWidget);
      expect(find.text('125%'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(zoomInClicked, isTrue);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(zoomOutClicked, isTrue);

      await tester.tap(find.text('125%'));
      await tester.pump();
      expect(fitWidthClicked, isTrue);

      await tester.tap(find.byIcon(Icons.filter_1_rounded));
      await tester.pump();
      expect(selectedLayout, ReaderLayout.singlePage);
    });
  });

  group('DesktopReaderToolbar Tests', () {
    testWidgets('renders all toolbar tool groups and triggers actions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      bool saveInvoked = false;
      bool printInvoked = false;
      bool prevInvoked = false;
      bool nextInvoked = false;
      bool toggleLeftInvoked = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopReaderToolbar(
                documentId: 'doc-test-123',
                documentPath: '/sample.pdf',
                currentPage: 2,
                pageCount: 10,
                currentZoom: 1.0,
                currentLayout: ReaderLayout.continuousVertical,
                currentTheme: ReaderThemeMode.light,
                isLeftPanelOpen: true,
                isRightPanelOpen: false,
                isSearchOpen: false,
                isDirty: true,
                onOpen: () {},
                onSave: () => saveInvoked = true,
                onSaveAs: () {},
                onPrint: () => printInvoked = true,
                onPrevPage: () => prevInvoked = true,
                onNextPage: () => nextInvoked = true,
                onJumpToPage: (_) {},
                onZoomIn: () {},
                onZoomOut: () {},
                onSetZoom: (_) {},
                onFitWidth: () {},
                onFitPage: () {},
                onLayoutChanged: (_) {},
                onThemeChanged: (_) {},
                onToggleSearch: () {},
                onToggleLeftPanel: () => toggleLeftInvoked = true,
                onToggleRightPanel: () {},
                onOpenPageOrganizer: () {},
                onOpenPasswordProtect: () {},
                onOpenProperties: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text(' / 10'), findsOneWidget);

      await tester.tap(find.byTooltip('Save Changes (Ctrl+S)'));
      await tester.pump();
      expect(saveInvoked, isTrue);

      await tester.tap(find.byTooltip('Print Document (Ctrl+P)'));
      await tester.pump();
      expect(printInvoked, isTrue);

      await tester.tap(find.byTooltip('Previous Page (PageUp)'));
      await tester.pump();
      expect(prevInvoked, isTrue);

      await tester.tap(find.byTooltip('Next Page (PageDown)'));
      await tester.pump();
      expect(nextInvoked, isTrue);

      await tester.tap(find.byTooltip('Hide Navigation Panel'));
      await tester.pump();
      expect(toggleLeftInvoked, isTrue);
    });

    testWidgets('renders Back to Home toolbar action and triggers callback', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      bool backClicked = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopReaderToolbar(
                documentId: 'doc-test-456',
                documentPath: '/sample.pdf',
                currentPage: 1,
                pageCount: 5,
                currentZoom: 1.0,
                currentLayout: ReaderLayout.continuousVertical,
                currentTheme: ReaderThemeMode.light,
                isLeftPanelOpen: false,
                isRightPanelOpen: false,
                isSearchOpen: false,
                isDirty: false,
                onBackToHome: () => backClicked = true,
                onOpen: () {},
                onSave: () {},
                onSaveAs: () {},
                onPrint: () {},
                onPrevPage: () {},
                onNextPage: () {},
                onJumpToPage: (_) {},
                onZoomIn: () {},
                onZoomOut: () {},
                onSetZoom: (_) {},
                onFitWidth: () {},
                onFitPage: () {},
                onLayoutChanged: (_) {},
                onThemeChanged: (_) {},
                onToggleSearch: () {},
                onToggleLeftPanel: () {},
                onToggleRightPanel: () {},
                onOpenPageOrganizer: () {},
                onOpenPasswordProtect: () {},
                onOpenProperties: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byTooltip('Back to Home Screen (Alt+Left)'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to Home Screen (Alt+Left)'));
      await tester.pump();
      expect(backClicked, isTrue);
    });
  });

  group('AppShell Desktop Navigation & State Preservation Tests', () {
    testWidgets(
      'switches between Home and active tabs preserving document state in memory',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final doc = DocumentMeta(
          id: 'doc-preserve-1',
          name: 'Report_2026.pdf',
          path: '/docs/Report_2026.pdf',
          sizeInBytes: 2048,
          totalPages: 10,
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

        // Initially on Home Screen (Desktop Tools Studio)
        expect(find.text('IT PDF Tools Studio'), findsOneWidget);

        // Open tab
        container.read(documentTabsNotifierProvider.notifier).openTab(doc);
        await tester.pump();
        await tester.pump();

        // Back to Home button is visible in title bar & tab bar
        expect(find.byTooltip('Back to Home Screen (Alt+Left)'), findsWidgets);

        // Click Back to Home
        await tester.tap(
          find.byTooltip('Back to Home Screen (Alt+Left)').first,
        );
        await tester.pump();
        await tester.pump();

        // Returning Home does NOT close tabs: Report_2026.pdf tab is still open!
        expect(
          find.descendant(
            of: find.byType(DesktopTabBar),
            matching: find.text('Report_2026.pdf'),
          ),
          findsOneWidget,
        );

        // Click tab again to return to reader
        await tester.tap(
          find.descendant(
            of: find.byType(DesktopTabBar),
            matching: find.text('Report_2026.pdf'),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Returned to reader
        expect(find.byTooltip('Back to Home Screen (Alt+Left)'), findsWidgets);
      },
    );
  });
}
