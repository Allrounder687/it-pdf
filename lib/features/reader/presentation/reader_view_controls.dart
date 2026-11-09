import 'package:flutter/material.dart';
import '../domain/reader_state.dart';

/// Interactive desktop/tablet top-bar controls for page scaling, layout modes, and page jumping.
class ReaderViewControls extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final double currentZoom;
  final ReaderLayout currentLayout;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final ValueChanged<double> onSelectZoom;
  final VoidCallback onFitWidth;
  final VoidCallback onFitPage;
  final ValueChanged<ReaderLayout> onSelectLayout;
  final ValueChanged<int> onJumpToPage;

  const ReaderViewControls({
    super.key,
    required this.currentPage,
    required this.pageCount,
    required this.currentZoom,
    required this.currentLayout,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onSelectZoom,
    required this.onFitWidth,
    required this.onFitPage,
    required this.onSelectLayout,
    required this.onJumpToPage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zoomPercent = (currentZoom * 100).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Page jump pill
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _showJumpDialog(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Text(
                  '$currentPage / $pageCount',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, size: 16),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Zoom Out
        IconButton(
          icon: const Icon(Icons.remove, size: 18),
          tooltip: 'Zoom Out (Ctrl+-)',
          visualDensity: VisualDensity.compact,
          onPressed: onZoomOut,
        ),

        // Zoom Dropdown
        PopupMenuButton<String>(
          tooltip: 'Zoom & Fit Options',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Text(
                  '$zoomPercent%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, size: 16),
              ],
            ),
          ),
          onSelected: (val) {
            switch (val) {
              case 'fit_width':
                onFitWidth();
                break;
              case 'fit_page':
                onFitPage();
                break;
              case 'actual':
                onSelectZoom(1.0);
                break;
              default:
                final parsed = double.tryParse(val);
                if (parsed != null) {
                  onSelectZoom(parsed);
                }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'fit_width',
              child: Row(
                children: [
                  Icon(Icons.fit_screen, size: 18),
                  SizedBox(width: 8),
                  Text('Fit to Width'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'fit_page',
              child: Row(
                children: [
                  Icon(Icons.fullscreen, size: 18),
                  SizedBox(width: 8),
                  Text('Fit to Page'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'actual',
              child: Row(
                children: [
                  Icon(Icons.aspect_ratio, size: 18),
                  SizedBox(width: 8),
                  Text('Actual Size (100%)'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: '0.50', child: Text('50%')),
            const PopupMenuItem(value: '0.75', child: Text('75%')),
            const PopupMenuItem(value: '1.00', child: Text('100%')),
            const PopupMenuItem(value: '1.25', child: Text('125%')),
            const PopupMenuItem(value: '1.50', child: Text('150%')),
            const PopupMenuItem(value: '2.00', child: Text('200%')),
            const PopupMenuItem(value: '3.00', child: Text('300%')),
          ],
        ),

        // Zoom In
        IconButton(
          icon: const Icon(Icons.add, size: 18),
          tooltip: 'Zoom In (Ctrl++)',
          visualDensity: VisualDensity.compact,
          onPressed: onZoomIn,
        ),

        // Fit Width quick toggle button
        IconButton(
          icon: const Icon(Icons.fit_screen, size: 18),
          tooltip: 'Fit Width',
          visualDensity: VisualDensity.compact,
          onPressed: onFitWidth,
        ),

        // Fit Page quick toggle button
        IconButton(
          icon: const Icon(Icons.fullscreen, size: 18),
          tooltip: 'Fit Page',
          visualDensity: VisualDensity.compact,
          onPressed: onFitPage,
        ),
      ],
    );
  }

  void _showJumpDialog(BuildContext context) {
    final controller = TextEditingController(text: '$currentPage');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Go to Page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Page Number (1 - $pageCount)',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            final page = int.tryParse(val.trim());
            if (page != null && page >= 1 && page <= pageCount) {
              Navigator.of(ctx).pop();
              onJumpToPage(page);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final page = int.tryParse(controller.text.trim());
              if (page != null && page >= 1 && page <= pageCount) {
                Navigator.of(ctx).pop();
                onJumpToPage(page);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }
}
