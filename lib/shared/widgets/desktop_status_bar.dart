import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../features/reader/domain/reader_state.dart';

/// Docked bottom status bar displaying document status, page progress, and quick layout/zoom controls.
class DesktopStatusBar extends StatelessWidget {
  final String? documentPath;
  final int currentPage;
  final int pageCount;
  final double currentZoom;
  final ReaderLayout currentLayout;
  final bool isLoading;
  final String statusMessage;

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitWidth;
  final ValueChanged<ReaderLayout> onLayoutChanged;

  const DesktopStatusBar({
    super.key,
    this.documentPath,
    this.currentPage = 1,
    this.pageCount = 1,
    this.currentZoom = 1.0,
    this.currentLayout = ReaderLayout.continuousVertical,
    this.isLoading = false,
    this.statusMessage = 'Ready',
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitWidth,
    required this.onLayoutChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
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

    final progressPct = pageCount > 0
        ? ((currentPage / pageCount) * 100).round()
        : 0;

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          // Status indicator dot
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isLoading
                  ? AppTheme.highlightAmber
                  : AppTheme.successGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isLoading ? 'Processing...' : statusMessage,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
          ),

          if (documentPath != null) ...[
            const SizedBox(width: 10),
            Text('•', style: TextStyle(fontSize: 10, color: textSecondary)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                documentPath!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: textSecondary),
              ),
            ),
          ] else
            const Spacer(),

          // Page Progress
          if (documentPath != null && pageCount > 0) ...[
            Text(
              'Page $currentPage of $pageCount ($progressPct%)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(width: 14),
          ],

          // Reading Layout Mode Segmented Icons
          _buildLayoutIcon(
            icon: Icons.view_stream_rounded,
            tooltip: 'Continuous Vertical',
            isActive: currentLayout == ReaderLayout.continuousVertical,
            activeColor: accentColor,
            inactiveColor: textSecondary,
            onTap: () => onLayoutChanged(ReaderLayout.continuousVertical),
          ),
          _buildLayoutIcon(
            icon: Icons.filter_1_rounded,
            tooltip: 'Single Page',
            isActive: currentLayout == ReaderLayout.singlePage,
            activeColor: accentColor,
            inactiveColor: textSecondary,
            onTap: () => onLayoutChanged(ReaderLayout.singlePage),
          ),
          _buildLayoutIcon(
            icon: Icons.auto_stories_rounded,
            tooltip: 'Two Page Spread',
            isActive: currentLayout == ReaderLayout.twoPage,
            activeColor: accentColor,
            inactiveColor: textSecondary,
            onTap: () => onLayoutChanged(ReaderLayout.twoPage),
          ),
          _buildLayoutIcon(
            icon: Icons.view_column_rounded,
            tooltip: 'Continuous Horizontal',
            isActive: currentLayout == ReaderLayout.continuousHorizontal,
            activeColor: accentColor,
            inactiveColor: textSecondary,
            onTap: () => onLayoutChanged(ReaderLayout.continuousHorizontal),
          ),

          const SizedBox(width: 10),

          // Zoom Controls
          InkWell(
            borderRadius: BorderRadius.circular(3),
            onTap: onZoomOut,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(Icons.remove, size: 14, color: textSecondary),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(3),
            onTap: onFitWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                '${(currentZoom * 100).round()}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(3),
            onTap: onZoomIn,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(Icons.add, size: 14, color: textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutIcon({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(3),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Icon(
            icon,
            size: 15,
            color: isActive ? activeColor : inactiveColor,
          ),
        ),
      ),
    );
  }
}
