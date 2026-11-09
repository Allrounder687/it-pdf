import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../library/domain/library_notifier.dart';
import '../../../shared/models/document_meta.dart';
import 'document_tab.dart';
import 'document_tabs_state.dart';

/// Provider managing open document tabs in the desktop shell.
final documentTabsNotifierProvider =
    NotifierProvider<DocumentTabsNotifier, DocumentTabsState>(
      DocumentTabsNotifier.new,
    );

class DocumentTabsNotifier extends Notifier<DocumentTabsState> {
  @override
  DocumentTabsState build() {
    return const DocumentTabsState();
  }

  /// Open a document as an active tab. If already open, switch to it.
  void openTab(DocumentMeta doc) {
    final existingIndex = state.openTabs.indexWhere(
      (tab) => tab.path == doc.path || tab.id == doc.id,
    );

    if (existingIndex >= 0) {
      state = state.copyWith(activeIndex: existingIndex);
      return;
    }

    final newTab = DocumentTab.fromMeta(doc);
    final updatedTabs = List<DocumentTab>.from(state.openTabs)..add(newTab);
    state = state.copyWith(
      openTabs: updatedTabs,
      activeIndex: updatedTabs.length - 1,
    );
  }

  /// Import from file path and open as tab.
  Future<void> openFileFromPath(String path) async {
    final libraryNotifier = ref.read(libraryNotifierProvider.notifier);
    final doc = await libraryNotifier.importFileFromPath(path);
    if (doc != null) {
      openTab(doc);
    }
  }

  /// Switch the active tab to a specific index.
  void switchToTab(int index) {
    if (index >= 0 && index < state.openTabs.length) {
      state = state.copyWith(activeIndex: index);
    }
  }

  /// Close the tab at the given index.
  void closeTab(int index) {
    if (index < 0 || index >= state.openTabs.length) return;

    final closedTab = state.openTabs[index];
    final updatedTabs = List<DocumentTab>.from(state.openTabs)..removeAt(index);

    final updatedRecentlyClosed = List<DocumentTab>.from(
      state.recentlyClosedTabs,
    )..insert(0, closedTab);
    if (updatedRecentlyClosed.length > 10) {
      updatedRecentlyClosed.removeLast();
    }

    int nextActiveIndex;
    if (updatedTabs.isEmpty) {
      nextActiveIndex = -1;
    } else if (state.activeIndex >= updatedTabs.length) {
      nextActiveIndex = updatedTabs.length - 1;
    } else if (state.activeIndex > index) {
      nextActiveIndex = state.activeIndex - 1;
    } else {
      nextActiveIndex = state.activeIndex;
    }

    state = state.copyWith(
      openTabs: updatedTabs,
      activeIndex: nextActiveIndex,
      recentlyClosedTabs: updatedRecentlyClosed,
    );
  }

  /// Close all other tabs except the one at [keepIndex].
  void closeOtherTabs(int keepIndex) {
    if (keepIndex < 0 || keepIndex >= state.openTabs.length) return;
    final keptTab = state.openTabs[keepIndex];
    state = state.copyWith(openTabs: [keptTab], activeIndex: 0);
  }

  /// Close all tabs to the right of [index].
  void closeTabsToRight(int index) {
    if (index < 0 || index >= state.openTabs.length - 1) return;
    final updatedTabs = state.openTabs.sublist(0, index + 1);
    final nextActive = state.activeIndex > index ? index : state.activeIndex;
    state = state.copyWith(openTabs: updatedTabs, activeIndex: nextActive);
  }

  /// Close all open tabs.
  void closeAllTabs() {
    state = state.copyWith(openTabs: const [], activeIndex: -1);
  }

  /// Reopen the most recently closed tab.
  void reopenLastClosedTab() {
    if (state.recentlyClosedTabs.isEmpty) return;
    final lastClosed = state.recentlyClosedTabs.first;
    final remainingRecent = state.recentlyClosedTabs.sublist(1);

    final updatedTabs = List<DocumentTab>.from(state.openTabs)..add(lastClosed);
    state = state.copyWith(
      openTabs: updatedTabs,
      activeIndex: updatedTabs.length - 1,
      recentlyClosedTabs: remainingRecent,
    );
  }

  /// Switch to the next tab (Ctrl+Tab).
  void nextTab() {
    if (state.openTabs.length <= 1) return;
    final nextIndex = (state.activeIndex + 1) % state.openTabs.length;
    state = state.copyWith(activeIndex: nextIndex);
  }

  /// Switch to the previous tab (Ctrl+Shift+Tab).
  void previousTab() {
    if (state.openTabs.length <= 1) return;
    final prevIndex =
        (state.activeIndex - 1 + state.openTabs.length) % state.openTabs.length;
    state = state.copyWith(activeIndex: prevIndex);
  }

  /// Update reading progress for the active tab.
  void updateActiveTabProgress(int page, int totalPages) {
    if (!state.hasActiveTab) return;
    final current = state.activeTab!;
    final updated = current.copyWith(initialPage: page, totalPages: totalPages);
    final updatedTabs = List<DocumentTab>.from(state.openTabs);
    updatedTabs[state.activeIndex] = updated;
    state = state.copyWith(openTabs: updatedTabs);
  }
}
