import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/editor/presentation/tools_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/library/domain/library_notifier.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/reader/domain/reader_notifier.dart';
import '../../features/reader/presentation/reader_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

/// Responsive shell providing NavigationRail on desktop and NavigationBar on mobile
/// with native drag-and-drop file ingestion.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;
  bool _isDragging = false;

  static const List<Widget> _destinations = [
    HomeScreen(),
    LibraryScreen(),
    ToolsScreen(),
    SettingsScreen(),
  ];

  Future<void> _handleDroppedFiles(DropDoneDetails details) async {
    final notifier = ref.read(libraryNotifierProvider.notifier);

    for (final file in details.files) {
      if (file.path.toLowerCase().endsWith('.pdf')) {
        final doc = await notifier.importFileFromPath(file.path);
        if (doc != null && mounted) {
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
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        await _handleDroppedFiles(details);
      },
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 800;

              if (isDesktop) {
                return Scaffold(
                  body: Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _currentIndex,
                        onDestinationSelected: (index) => setState(() => _currentIndex = index),
                        labelType: NavigationRailLabelType.all,
                        leading: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Icon(Icons.picture_as_pdf, color: Colors.blueAccent, size: 32),
                        ),
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home),
                            label: Text('Home'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.folder_outlined),
                            selectedIcon: Icon(Icons.folder),
                            label: Text('Library'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.build_outlined),
                            selectedIcon: Icon(Icons.build),
                            label: Text('Tools'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.settings_outlined),
                            selectedIcon: Icon(Icons.settings),
                            label: Text('Settings'),
                          ),
                        ],
                      ),
                      const VerticalDivider(thickness: 1, width: 1),
                      Expanded(
                        child: IndexedStack(
                          index: _currentIndex,
                          children: _destinations,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Scaffold(
                body: IndexedStack(
                  index: _currentIndex,
                  children: _destinations,
                ),
                bottomNavigationBar: NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) => setState(() => _currentIndex = index),
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
            },
          ),
          if (_isDragging)
            Positioned.fill(
              child: Container(
                color: Colors.blueAccent.withValues(alpha: 0.85),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_download, size: 64, color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Drop PDF Files to Open',
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
  }
}
