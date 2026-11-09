import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/reader/domain/document_tab.dart';
import '../../features/reader/domain/document_tabs_notifier.dart';

/// Horizontal multi-document tab bar with context menus and dirty-state indicators.
class DesktopTabBar extends ConsumerWidget {
  final VoidCallback onNewTab;

  const DesktopTabBar({super.key, required this.onNewTab});

  void _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
    DocumentTab tab,
    int tabIndex,
  ) {
    final notifier = ref.read(documentTabsNotifierProvider.notifier);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: const [
        PopupMenuItem(value: 'close', child: Text('Close Tab')),
        PopupMenuItem(value: 'closeOthers', child: Text('Close Other Tabs')),
        PopupMenuItem(
          value: 'closeRight',
          child: Text('Close Tabs to the Right'),
        ),
        PopupMenuItem(value: 'closeAll', child: Text('Close All Tabs')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'reveal', child: Text('Reveal in File Explorer')),
        PopupMenuItem(value: 'copyPath', child: Text('Copy File Path')),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'close':
          notifier.closeTab(tabIndex);
          break;
        case 'closeOthers':
          notifier.closeOtherTabs(tabIndex);
          break;
        case 'closeRight':
          notifier.closeTabsToRight(tabIndex);
          break;
        case 'closeAll':
          notifier.closeAllTabs();
          break;
        case 'reveal':
          Process.run('explorer.exe', ['/select,', tab.path]);
          break;
        case 'copyPath':
          Clipboard.setData(ClipboardData(text: tab.path));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File path copied to clipboard.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabsState = ref.watch(documentTabsNotifierProvider);
    final notifier = ref.read(documentTabsNotifierProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF131B2A) : const Color(0xFFE2E8F0);
    final tabActiveBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final tabInactiveBg = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFCBD5E1);

    if (tabsState.openTabs.isEmpty) {
      return Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: bg,
        child: Row(
          children: [
            const Icon(
              Icons.picture_as_pdf_outlined,
              size: 14,
              color: Colors.grey,
            ),
            const SizedBox(width: 6),
            const Text(
              'No documents open',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 16),
              tooltip: 'Open New Document',
              visualDensity: VisualDensity.compact,
              onPressed: onNewTab,
            ),
          ],
        ),
      );
    }

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabsState.openTabs.length,
              itemBuilder: (context, index) {
                final tab = tabsState.openTabs[index];
                final isActive = index == tabsState.activeIndex;

                return GestureDetector(
                  onSecondaryTapUp: (details) {
                    _showContextMenu(
                      context,
                      ref,
                      details.globalPosition,
                      tab,
                      index,
                    );
                  },
                  child: InkWell(
                    onTap: () => notifier.switchToTab(index),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 120,
                        maxWidth: 200,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isActive ? tabActiveBg : tabInactiveBg,
                        border: Border(
                          right: BorderSide(color: borderColor, width: 1),
                          top: isActive
                              ? const BorderSide(
                                  color: Colors.blueAccent,
                                  width: 2,
                                )
                              : BorderSide.none,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.picture_as_pdf,
                            size: 14,
                            color: isActive ? Colors.redAccent : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              tab.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isActive
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          if (tab.isDirty)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                            ),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => notifier.closeTab(index),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close_rounded, size: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 17),
            tooltip: 'Open Another Document (Ctrl+O)',
            visualDensity: VisualDensity.compact,
            onPressed: onNewTab,
          ),
          if (tabsState.recentlyClosedTabs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history_rounded, size: 16),
              tooltip:
                  'Reopen Recently Closed Tab (${tabsState.recentlyClosedTabs.first.name})',
              visualDensity: VisualDensity.compact,
              onPressed: notifier.reopenLastClosedTab,
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
