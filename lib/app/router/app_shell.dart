import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../features/editor/presentation/tools_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/library/domain/library_notifier.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/reader/domain/document_tab.dart';
import '../../features/reader/domain/document_tabs_notifier.dart';
import '../../features/reader/domain/reader_notifier.dart';
import '../../features/reader/presentation/desktop_reader_workspace.dart';
import '../../features/reader/presentation/reader_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../shared/widgets/command_palette_dialog.dart';
import '../../shared/widgets/desktop_sidebar.dart';
import '../../shared/widgets/desktop_status_bar.dart';
import '../../shared/widgets/desktop_tab_bar.dart';
import '../../shared/widgets/desktop_title_bar.dart';

/// Responsive application shell providing an Acrobat/Edge-grade desktop workspace
/// on Windows and preserving full mobile navigation on touch devices.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _mobileIndex = 0;
  DesktopNavDestination _desktopDestination = DesktopNavDestination.home;
  bool _isSidebarExpanded = true;
  bool _isDragging = false;

  static const List<Widget> _mobileDestinations = [
    HomeScreen(),
    LibraryScreen(),
    ToolsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCliLaunchArgs();
    });
  }

  void _checkCliLaunchArgs() {
    final args = ref.read(initialCliArgsProvider);
    for (final arg in args) {
      if (arg.toLowerCase().endsWith('.pdf') && File(arg).existsSync()) {
        ref.read(documentTabsNotifierProvider.notifier).openFileFromPath(arg);
        setState(() {
          _desktopDestination = DesktopNavDestination.activeDocument;
        });
        break;
      }
    }
  }

  Future<void> _handleDroppedFiles(
    DropDoneDetails details,
    bool isDesktop,
  ) async {
    final notifier = ref.read(libraryNotifierProvider.notifier);

    for (final file in details.files) {
      if (file.path.toLowerCase().endsWith('.pdf')) {
        final doc = await notifier.importFileFromPath(file.path);
        if (doc != null && mounted) {
          if (isDesktop) {
            ref.read(documentTabsNotifierProvider.notifier).openTab(doc);
            setState(() {
              _desktopDestination = DesktopNavDestination.activeDocument;
            });
          } else {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReaderScreen(
                  params: ReaderNotifierParams(
                    id: doc.id,
                    name: doc.name,
                    path: doc.path,
                    initialPage: doc.lastPageRead,
                    initialPageCount: doc.totalPages,
                  ),
                ),
              ),
            );
          }
          break;
        }
      }
    }
  }

  Future<void> _openPdfWithPicker() async {
    final picker = ref.read(filePickerServiceProvider);
    final path = await picker.pickPdfFile();
    if (path != null && mounted) {
      await ref
          .read(documentTabsNotifierProvider.notifier)
          .openFileFromPath(path);
      setState(() {
        _desktopDestination = DesktopNavDestination.activeDocument;
      });
    }
  }

  void _showShortcutsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard_outlined, color: Colors.blueAccent),
            SizedBox(width: 10),
            Text('Keyboard Shortcuts'),
          ],
        ),
        content: const SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShortcutRow('Ctrl + O', 'Open PDF Document'),
              _ShortcutRow('Ctrl + S', 'Save / Burn Annotations (ISO 32000)'),
              _ShortcutRow('Ctrl + Shift + S', 'Save As (New Document Copy)'),
              _ShortcutRow('Ctrl + P', 'Print Document'),
              _ShortcutRow('Ctrl + F', 'Search Text in Document'),
              _ShortcutRow('Ctrl + K', 'Spotlight Command Palette'),
              _ShortcutRow('Ctrl + + / -', 'Zoom In / Out'),
              _ShortcutRow('Ctrl + 0', 'Fit Width / Reset Zoom'),
              _ShortcutRow('Ctrl + Tab', 'Switch to Next Document Tab'),
              _ShortcutRow('Ctrl + Shift + Tab', 'Switch to Previous Tab'),
              _ShortcutRow('Page Up / Down', 'Navigate Pages'),
              _ShortcutRow('Home / End', 'First / Last Page'),
              _ShortcutRow('Ctrl + Z / Y', 'Undo / Redo Annotation'),
              _ShortcutRow('Escape', 'Close Dialog / Exit Tool'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _openCommandPalette() {
    showDialog<void>(
      context: context,
      builder: (_) => CommandPaletteDialog(
        customCommands: [
          CommandItem(
            title: 'Open PDF Document',
            subtitle: 'Choose a PDF file to open in a new tab',
            icon: Icons.folder_open_outlined,
            shortcut: 'Ctrl+O',
            onExecute: _openPdfWithPicker,
          ),
          CommandItem(
            title: 'Toggle Color Theme',
            subtitle: 'Switch between light and dark appearance',
            icon: Icons.brightness_6_outlined,
            onExecute: () {
              final current = ref.read(themeModeProvider);
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(
                    current == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                  );
            },
          ),
          CommandItem(
            title: 'Close All Document Tabs',
            subtitle: 'Close all open document tabs in the workspace',
            icon: Icons.close_fullscreen_rounded,
            onExecute: () {
              ref.read(documentTabsNotifierProvider.notifier).closeAllTabs();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to active tab changes: if a new tab is opened, automatically navigate to reader
    ref.listen<int>(documentTabsNotifierProvider.select((s) => s.activeIndex), (
      prev,
      next,
    ) {
      if (next >= 0 &&
          _desktopDestination != DesktopNavDestination.activeDocument) {
        setState(
          () => _desktopDestination = DesktopNavDestination.activeDocument,
        );
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        return DropTarget(
          onDragEntered: (_) => setState(() => _isDragging = true),
          onDragExited: (_) => setState(() => _isDragging = false),
          onDragDone: (details) async {
            setState(() => _isDragging = false);
            await _handleDroppedFiles(details, isDesktop);
          },
          child: Stack(
            children: [
              if (isDesktop)
                _buildDesktopShell(context)
              else
                _buildMobileShell(context),

              if (_isDragging)
                Positioned.fill(
                  child: Container(
                    color: Colors.blueAccent.withValues(alpha: 0.88),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.file_download,
                            size: 64,
                            color: Colors.white,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Drop PDF Files to Open in Workspace',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopShell(BuildContext context) {
    final tabsState = ref.watch(documentTabsNotifierProvider);
    final activeTab = tabsState.activeTab;

    // Determine what to show in main workspace
    final showReader =
        _desktopDestination == DesktopNavDestination.activeDocument &&
        tabsState.hasActiveTab;

    return Scaffold(
      body: Column(
        children: [
          // Top Title Bar
          DesktopTitleBar(
            activeDocumentName: activeTab?.name,
            isDirty: activeTab?.isDirty ?? false,
            onOpenPdf: _openPdfWithPicker,
            onOpenCommandPalette: _openCommandPalette,
            onToggleTheme: () {
              final current = ref.read(themeModeProvider);
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(
                    current == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                  );
            },
            onShowShortcuts: _showShortcutsDialog,
          ),

          // Multi-Document Tab Strip
          DesktopTabBar(onNewTab: _openPdfWithPicker),

          // Central Body: Left Sidebar + Content Area
          Expanded(
            child: Row(
              children: [
                DesktopSidebar(
                  currentDestination: _desktopDestination,
                  isExpanded: _isSidebarExpanded,
                  hasActiveDocument: tabsState.hasActiveTab,
                  activeDocumentTitle: activeTab?.name,
                  onToggleExpanded: () {
                    setState(() => _isSidebarExpanded = !_isSidebarExpanded);
                  },
                  onDestinationSelected: (dest) {
                    setState(() => _desktopDestination = dest);
                  },
                ),

                // Main Content Workspace
                Expanded(
                  child: showReader
                      ? IndexedStack(
                          index: tabsState.activeIndex,
                          children: tabsState.openTabs
                              .map(
                                (tab) => DesktopReaderWorkspace(
                                  key: ValueKey('workspace_${tab.id}'),
                                  tab: tab,
                                ),
                              )
                              .toList(),
                        )
                      : switch (_desktopDestination) {
                          DesktopNavDestination.home => const HomeScreen(),
                          DesktopNavDestination.allDocuments ||
                          DesktopNavDestination.recent ||
                          DesktopNavDestination.favorites =>
                            const LibraryScreen(),
                          DesktopNavDestination.tools => const ToolsScreen(),
                          DesktopNavDestination.settings =>
                            const SettingsScreen(),
                          DesktopNavDestination.activeDocument =>
                            const HomeScreen(),
                        },
                ),
              ],
            ),
          ),

          // Docked Bottom Status Bar (when reader is visible)
          if (showReader && activeTab != null) _buildActiveStatusBar(activeTab),
        ],
      ),
    );
  }

  Widget _buildActiveStatusBar(DocumentTab tab) {
    final readerState = ref.watch(readerNotifierProvider(tab.readerParams));
    final notifier = ref.read(
      readerNotifierProvider(tab.readerParams).notifier,
    );

    return DesktopStatusBar(
      documentPath: tab.path,
      currentPage: readerState.currentPage,
      pageCount: readerState.pageCount,
      currentZoom: readerState.currentZoom,
      currentLayout: readerState.layout,
      isLoading: readerState.isLoading,
      statusMessage: readerState.isLoading ? 'Rendering PDF...' : 'Ready',
      onZoomIn: () {},
      onZoomOut: () {},
      onFitWidth: () {},
      onLayoutChanged: notifier.setLayout,
    );
  }

  Widget _buildMobileShell(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _mobileIndex, children: _mobileDestinations),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _mobileIndex,
        onDestinationSelected: (index) => setState(() => _mobileIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Tools',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String keys;
  final String description;

  const _ShortcutRow(this.keys, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white12
                  : Colors.black12,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              keys,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(description, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
