import 'package:flutter/material.dart';

enum DesktopNavDestination {
  home,
  allDocuments,
  recent,
  favorites,
  tools,
  settings,
  activeDocument,
}

/// Collapsible navigation sidebar for the desktop application shell.
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Tooltip(
        message: isExpanded ? '' : label,
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onDestinationSelected(destination),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (accentColor != null
                        ? accentColor.withValues(alpha: 0.15)
                        : (isDark
                              ? Colors.blueAccent.withValues(alpha: 0.2)
                              : Colors.blueAccent.withValues(alpha: 0.12)))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(
                      color:
                          accentColor ??
                          Colors.blueAccent.withValues(alpha: 0.4),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 19,
                  color: isSelected
                      ? (accentColor ?? Colors.blueAccent)
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
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
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? (accentColor ?? Colors.blueAccent)
                                : null,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
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
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isExpanded ? 200 : 56,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Active Document Quick Jump Button (if open)
          if (hasActiveDocument) ...[
            _buildItem(
              context: context,
              destination: DesktopNavDestination.activeDocument,
              icon: Icons.chrome_reader_mode_outlined,
              selectedIcon: Icons.chrome_reader_mode,
              label: 'Active Reader',
              subtitle: activeDocumentTitle,
              accentColor: Colors.blueAccent,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Divider(height: 1),
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

          const Spacer(),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Divider(height: 1),
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Tooltip(
              message: isExpanded ? 'Collapse Sidebar' : 'Expand Sidebar',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onToggleExpanded,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded
                            ? Icons.menu_open_rounded
                            : Icons.menu_rounded,
                        size: 19,
                        color: Colors.grey,
                      ),
                      if (isExpanded) ...[
                        const SizedBox(width: 12),
                        const Text(
                          'Collapse',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
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
