import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

enum DesktopNavDestination {
  home,
  allDocuments,
  recent,
  favorites,
  tools,
  settings,
  activeDocument,
  thumbnails,
  bookmarks,
  attachments,
}

/// Collapsible navigation sidebar for the desktop application shell.
/// Inspired by Microsoft Fluent Design 2 with subtle indicators and restrained tones.
class DesktopSidebar extends StatelessWidget {
  final DesktopNavDestination currentDestination;
  final ValueChanged<DesktopNavDestination> onDestinationSelected;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final bool hasActiveDocument;
  final String? activeDocumentTitle;

  const DesktopSidebar({
    super.key,
    required this.currentDestination,
    required this.onDestinationSelected,
    required this.isExpanded,
    required this.onToggleExpanded,
    this.hasActiveDocument = false,
    this.activeDocumentTitle,
  });

  Widget _buildItem({
    required BuildContext context,
    required DesktopNavDestination destination,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    Color? accentColor,
    String? subtitle,
  }) {
    final isSelected = currentDestination == destination;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textSecondary = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;
    final activeAccent =
        accentColor ??
        (isDark ? AppTheme.primaryBlueDark : AppTheme.primaryBlue);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Tooltip(
        message: isExpanded ? '' : label,
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => onDestinationSelected(destination),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeAccent.withValues(alpha: isDark ? 0.14 : 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                if (isSelected)
                  Container(
                    width: 3,
                    height: 18,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: activeAccent,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 18,
                  color: isSelected ? activeAccent : textSecondary,
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected ? textPrimary : textSecondary,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppTheme.darkSurfaceVariant
        : AppTheme.lightSurfaceVariant;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textSecondary = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      width: isExpanded ? 190 : 52,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),

          // Active Document Quick Jump Button (if open)
          if (hasActiveDocument) ...[
            _buildItem(
              context: context,
              destination: DesktopNavDestination.activeDocument,
              icon: Icons.chrome_reader_mode_outlined,
              selectedIcon: Icons.chrome_reader_mode,
              label: 'Active Reader',
              subtitle: activeDocumentTitle,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Divider(height: 1, color: borderColor),
            ),
          ],

          _buildItem(
            context: context,
            destination: DesktopNavDestination.home,
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Home',
          ),
          _buildItem(
            context: context,
            destination: DesktopNavDestination.allDocuments,
            icon: Icons.folder_outlined,
            selectedIcon: Icons.folder_rounded,
            label: 'All Documents',
          ),
          _buildItem(
            context: context,
            destination: DesktopNavDestination.recent,
            icon: Icons.history_rounded,
            selectedIcon: Icons.history_rounded,
            label: 'Recent',
          ),
          _buildItem(
            context: context,
            destination: DesktopNavDestination.favorites,
            icon: Icons.star_border_rounded,
            selectedIcon: Icons.star_rounded,
            label: 'Favorites',
          ),
          _buildItem(
            context: context,
            destination: DesktopNavDestination.tools,
            icon: Icons.build_outlined,
            selectedIcon: Icons.build_rounded,
            label: 'PDF Tools',
          ),

          if (hasActiveDocument) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Divider(height: 1, color: borderColor),
            ),
            _buildItem(
              context: context,
              destination: DesktopNavDestination.thumbnails,
              icon: Icons.grid_view_outlined,
              selectedIcon: Icons.grid_view_rounded,
              label: 'Thumbnails',
            ),
            _buildItem(
              context: context,
              destination: DesktopNavDestination.bookmarks,
              icon: Icons.bookmark_border_rounded,
              selectedIcon: Icons.bookmark_rounded,
              label: 'Bookmarks',
            ),
            _buildItem(
              context: context,
              destination: DesktopNavDestination.attachments,
              icon: Icons.attach_file_outlined,
              selectedIcon: Icons.attach_file_rounded,
              label: 'Attachments',
            ),
          ],

          const Spacer(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Divider(height: 1, color: borderColor),
          ),

          _buildItem(
            context: context,
            destination: DesktopNavDestination.settings,
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            label: 'Settings',
          ),

          // Collapse / Expand toggle button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Tooltip(
              message: isExpanded ? 'Collapse Sidebar' : 'Expand Sidebar',
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: onToggleExpanded,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded
                            ? Icons.menu_open_rounded
                            : Icons.menu_rounded,
                        size: 18,
                        color: textSecondary,
                      ),
                      if (isExpanded) ...[
                        const SizedBox(width: 10),
                        Text(
                          'Collapse',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
