import 'package:flutter/material.dart';
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
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFCBD5E1);

    final progressPct = pageCount > 0
        ? ((currentPage / pageCount) * 100).round()
        : 0;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isLoading ? Colors.amber : Colors.greenAccent.shade700,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isLoading ? 'Processing...' : statusMessage,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),

          if (documentPath != null) ...[
            const SizedBox(width: 12),
            const Text('•', style: TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                documentPath!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ] else
            const Spacer(),

          // Page Progress
          if (documentPath != null && pageCount > 0) ...[
            Text(
              'Page $currentPage of $pageCount ($progressPct%)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 16),
          ],

          // Reading Layout Mode Segmented Icons
          _buildLayoutIcon(
            icon: Icons.view_stream_rounded,
            tooltip: 'Continuous Vertical',
            isActive: currentLayout == ReaderLayout.continuousVertical,
            onTap: () => onLayoutChanged(ReaderLayout.continuousVertical),
          ),
          _buildLayoutIcon(
            icon: Icons.filter_1_rounded,
            tooltip: 'Single Page',
            isActive: currentLayout == ReaderLayout.singlePage,
            onTap: () => onLayoutChanged(ReaderLayout.singlePage),
          ),
          _buildLayoutIcon(
            icon: Icons.auto_stories_rounded,
            tooltip: 'Two Page Spread',
            isActive: currentLayout == ReaderLayout.twoPage,
            onTap: () => onLayoutChanged(ReaderLayout.twoPage),
          ),
          _buildLayoutIcon(
            icon: Icons.view_column_rounded,
            tooltip: 'Continuous Horizontal',
            isActive: currentLayout == ReaderLayout.continuousHorizontal,
            onTap: () => onLayoutChanged(ReaderLayout.continuousHorizontal),
          ),

          const SizedBox(width: 12),

          // Zoom Controls
          InkWell(
            onTap: onZoomOut,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(Icons.remove, size: 14),
            ),
          ),
          InkWell(
            onTap: onFitWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                '${(currentZoom * 100).round()}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: onZoomIn,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(Icons.add, size: 14),
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
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Icon(
            icon,
            size: 15,
            color: isActive ? Colors.blueAccent : Colors.grey,
          ),
        ),
      ),
    );
  }
}
