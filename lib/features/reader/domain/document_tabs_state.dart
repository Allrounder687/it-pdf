import 'document_tab.dart';

/// State of the multi-document tab management system.
class DocumentTabsState {
  final List<DocumentTab> openTabs;
  final int activeIndex;
  final List<DocumentTab> recentlyClosedTabs;

  const DocumentTabsState({
    this.openTabs = const [],
    this.activeIndex = -1,
    this.recentlyClosedTabs = const [],
  });

  bool get hasActiveTab => activeIndex >= 0 && activeIndex < openTabs.length;

  DocumentTab? get activeTab => hasActiveTab ? openTabs[activeIndex] : null;

  int get tabCount => openTabs.length;

  DocumentTabsState copyWith({
    List<DocumentTab>? openTabs,
    int? activeIndex,
    List<DocumentTab>? recentlyClosedTabs,
  }) {
    return DocumentTabsState(
      openTabs: openTabs ?? this.openTabs,
      activeIndex: activeIndex ?? this.activeIndex,
      recentlyClosedTabs: recentlyClosedTabs ?? this.recentlyClosedTabs,
    );
  }
}
