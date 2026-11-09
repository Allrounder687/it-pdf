import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/features/reader/domain/document_tab.dart';
import 'package:it_pdf/features/reader/domain/document_tabs_notifier.dart';
import 'package:it_pdf/shared/models/document_meta.dart';

void main() {
  group('DocumentTabsNotifier Unit Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    final doc1 = DocumentMeta(
      id: 'doc_1',
      name: 'Alpha.pdf',
      path: '/docs/Alpha.pdf',
      sizeInBytes: 1024,
      lastOpened: DateTime(2026, 11, 9),
      createdAt: DateTime(2026, 11, 9),
      lastPageRead: 1,
      totalPages: 10,
    );

    final doc2 = DocumentMeta(
      id: 'doc_2',
      name: 'Beta.pdf',
      path: '/docs/Beta.pdf',
      sizeInBytes: 2048,
      lastOpened: DateTime(2026, 11, 9),
      createdAt: DateTime(2026, 11, 9),
      lastPageRead: 3,
      totalPages: 25,
    );

    final doc3 = DocumentMeta(
      id: 'doc_3',
      name: 'Gamma.pdf',
      path: '/docs/Gamma.pdf',
      sizeInBytes: 4096,
      lastOpened: DateTime(2026, 11, 9),
      createdAt: DateTime(2026, 11, 9),
      lastPageRead: 5,
      totalPages: 50,
    );

    test('initial state has zero tabs and activeIndex -1', () {
      final state = container.read(documentTabsNotifierProvider);
      expect(state.openTabs, isEmpty);
      expect(state.activeIndex, -1);
      expect(state.hasActiveTab, false);
      expect(state.activeTab, isNull);
    });

    test('openTab opens new document and sets activeIndex', () {
      final notifier = container.read(documentTabsNotifierProvider.notifier);
      notifier.openTab(doc1);

      var state = container.read(documentTabsNotifierProvider);
      expect(state.openTabs.length, 1);
      expect(state.activeIndex, 0);
      expect(state.activeTab?.id, 'doc_1');
      expect(state.activeTab?.name, 'Alpha.pdf');

      // Opening second tab
      notifier.openTab(doc2);
      state = container.read(documentTabsNotifierProvider);
      expect(state.openTabs.length, 2);
      expect(state.activeIndex, 1);
      expect(state.activeTab?.id, 'doc_2');
    });

    test('openTab on already open document switches to existing tab without duplicating', () {
      final notifier = container.read(documentTabsNotifierProvider.notifier);
      notifier.openTab(doc1);
      notifier.openTab(doc2);

      // Re-open doc1
      notifier.openTab(doc1);
      final state = container.read(documentTabsNotifierProvider);
      expect(state.openTabs.length, 2);
      expect(state.activeIndex, 0);
      expect(state.activeTab?.id, 'doc_1');
    });

    test('closeTab adjusts activeIndex and preserves recentlyClosedTabs', () {
      final notifier = container.read(documentTabsNotifierProvider.notifier);
      notifier.openTab(doc1);
      notifier.openTab(doc2);
      notifier.openTab(doc3);

      // Active is doc3 (index 2)
      notifier.closeTab(2);
      var state = container.read(documentTabsNotifierProvider);
      expect(state.openTabs.length, 2);
      expect(state.activeIndex, 1);
      expect(state.activeTab?.id, 'doc_2');
      expect(state.recentlyClosedTabs.first.id, 'doc_3');

      // Reopen last closed tab
      notifier.reopenLastClosedTab();
      state = container.read(documentTabsNotifierProvider);
      expect(state.openTabs.length, 3);
      expect(state.activeTab?.id, 'doc_3');
    });

    test('closeOtherTabs and closeTabsToRight operate cleanly', () {
      final notifier = container.read(documentTabsNotifierProvider.notifier);
      notifier.openTab(doc1);
      notifier.openTab(doc2);
      notifier.openTab(doc3);

      notifier.closeTabsToRight(1);
      var state = container.read(documentTabsNotifierProvider);
      expect(state.openTabs.length, 2);
      expect(state.openTabs.map((t) => t.id), ['doc_1', 'doc_2']);

      notifier.closeOtherTabs(0);
      state = container.read(documentTabsNotifierProvider);
      expect(state.openTabs.length, 1);
      expect(state.activeTab?.id, 'doc_1');
    });

    test('nextTab and previousTab cycle with wrap-around', () {
      final notifier = container.read(documentTabsNotifierProvider.notifier);
      notifier.openTab(doc1);
      notifier.openTab(doc2);
      notifier.openTab(doc3);

      // currently at index 2
      notifier.nextTab();
      expect(container.read(documentTabsNotifierProvider).activeIndex, 0);

      notifier.previousTab();
      expect(container.read(documentTabsNotifierProvider).activeIndex, 2);

      notifier.previousTab();
      expect(container.read(documentTabsNotifierProvider).activeIndex, 1);
    });
  });
}
