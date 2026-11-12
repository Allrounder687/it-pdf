import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_theme.dart';
import '../../features/reader/domain/document_tab.dart';
import '../../features/reader/domain/document_tabs_notifier.dart';

/// Horizontal multi-document tab bar with context menus, dirty indicators,
/// and dedicated Home navigation.
class DesktopTabBar extends ConsumerWidget {
  final VoidCallback onNewTab;
  final VoidCallback? onBackToHome;
  final ValueChanged<int>? onTabSelected;

  const DesktopTabBar({
    super.key,
    required this.onNewTab,
    this.onBackToHome,
    this.onTabSelected,
  });

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
    final bg = isDark
        ? AppTheme.darkSurfaceVariant
        : AppTheme.lightSurfaceVariant;
    final tabActiveBg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final tabInactiveBg = isDark
        ? AppTheme.darkSurfaceVariant
        : AppTheme.lightSurfaceVariant;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textSecondary = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;
    final accentColor = isDark
        ? AppTheme.primaryBlueDark
        : AppTheme.primaryBlue;

    if (tabsState.openTabs.isEmpty) {
      return Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: bg,
        child: Row(
          children: [
            if (onBackToHome != null) ...[
              Tooltip(
                message: 'Back to Home Screen (Alt+Left)',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: onBackToHome,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.home_outlined,
                          size: 15,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Home',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                height: 16,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: borderColor,
              ),
            ],
            Icon(Icons.picture_as_pdf_outlined, size: 14, color: textSecondary),
            const SizedBox(width: 6),
            Text(
              'No documents open',
              style: TextStyle(fontSize: 11, color: textSecondary),
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
      height: 34,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          if (onBackToHome != null) ...[
            Tooltip(
              message: 'Back to Home Screen (Alt+Left)',
              child: InkWell(
                onTap: onBackToHome,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: borderColor, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 14,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Home',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
                    onTap: () {
                      notifier.switchToTab(index);
                      onTabSelected?.call(index);
                    },
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 120,
                        maxWidth: 220,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isActive ? tabActiveBg : tabInactiveBg,
                        border: Border(
                          right: BorderSide(color: borderColor, width: 1),
                          top: isActive
                              ? BorderSide(color: accentColor, width: 2)
                              : BorderSide.none,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.picture_as_pdf,
                            size: 13,
                            color: isActive
                                ? (isDark
                                      ? const Color(0xFFF87171)
                                      : const Color(0xFFDC2626))
                                : textSecondary,
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
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isActive ? textPrimary : textSecondary,
                              ),
                            ),
                          ),
                          if (tab.isDirty)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: AppTheme.highlightAmber,
                                shape: BoxShape.circle,
                              ),
                            ),
                          InkWell(
                            borderRadius: BorderRadius.circular(3),
                            onTap: () => notifier.closeTab(index),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.close_rounded,
                                size: 13,
                                color: textSecondary,
                              ),
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
