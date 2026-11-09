import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../annotations/domain/annotation_model.dart';
import '../../annotations/domain/annotation_notifier.dart';
import '../domain/reader_state.dart';

/// Desktop Reader Toolbar combining File, Navigation, View, Annotation, and Utility controls.
class DesktopReaderToolbar extends ConsumerWidget {
  final String documentId;
  final String documentPath;
  final int currentPage;
  final int pageCount;
  final double currentZoom;
  final ReaderLayout currentLayout;
  final ReaderThemeMode currentTheme;
  final bool isLeftPanelOpen;
  final bool isRightPanelOpen;
  final bool isSearchOpen;
  final bool isDirty;

  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;
  final VoidCallback onPrint;
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;
  final ValueChanged<int> onJumpToPage;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final ValueChanged<double> onSetZoom;
  final VoidCallback onFitWidth;
  final VoidCallback onFitPage;
  final ValueChanged<ReaderLayout> onLayoutChanged;
  final ValueChanged<ReaderThemeMode> onThemeChanged;
  final VoidCallback onToggleSearch;
  final VoidCallback onToggleLeftPanel;
  final VoidCallback onToggleRightPanel;
  final VoidCallback onOpenPageOrganizer;
  final VoidCallback onOpenPasswordProtect;
  final VoidCallback onOpenProperties;

  const DesktopReaderToolbar({
    super.key,
    required this.documentId,
    required this.documentPath,
    required this.currentPage,
    required this.pageCount,
    required this.currentZoom,
    required this.currentLayout,
    required this.currentTheme,
    required this.isLeftPanelOpen,
    required this.isRightPanelOpen,
    required this.isSearchOpen,
    required this.isDirty,
    required this.onOpen,
    required this.onSave,
    required this.onSaveAs,
    required this.onPrint,
    required this.onPrevPage,
    required this.onNextPage,
    required this.onJumpToPage,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onSetZoom,
    required this.onFitWidth,
    required this.onFitPage,
    required this.onLayoutChanged,
    required this.onThemeChanged,
    required this.onToggleSearch,
    required this.onToggleLeftPanel,
    required this.onToggleRightPanel,
    required this.onOpenPageOrganizer,
    required this.onOpenPasswordProtect,
    required this.onOpenProperties,
  });

  Widget _buildDivider(Color borderColor) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: borderColor,
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool isSelected = false,
    Widget? badge,
  }) {
    final button = IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      color: isSelected ? Colors.blueAccent : null,
      style: isSelected
          ? IconButton.styleFrom(
              backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
            )
          : null,
      onPressed: onPressed,
    );

    if (badge != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          button,
          Positioned(top: 6, right: 6, child: badge),
        ],
      );
    }
    return button;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final annState = ref.watch(annotationNotifierProvider(documentId));
    final annNotifier = ref.read(
      annotationNotifierProvider(documentId).notifier,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Left Panel Toggle
            _buildIconButton(
              icon: Icons.view_sidebar_outlined,
              tooltip: isLeftPanelOpen
                  ? 'Hide Navigation Panel'
                  : 'Show Navigation Panel (Pages / Outline / Bookmarks)',
              isSelected: isLeftPanelOpen,
              onPressed: onToggleLeftPanel,
            ),
            _buildDivider(borderColor),

            // File Group
            _buildIconButton(
              icon: Icons.folder_open_outlined,
              tooltip: 'Open PDF (Ctrl+O)',
              onPressed: onOpen,
            ),
            _buildIconButton(
              icon: Icons.save_outlined,
              tooltip: 'Save Changes (Ctrl+S)',
              badge: (isDirty || annState.isDirty)
                  ? Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
              onPressed: onSave,
            ),
            _buildIconButton(
              icon: Icons.save_as_outlined,
              tooltip: 'Save As (Ctrl+Shift+S)',
              onPressed: onSaveAs,
            ),
            _buildIconButton(
              icon: Icons.print_outlined,
              tooltip: 'Print Document (Ctrl+P)',
              onPressed: onPrint,
            ),
            _buildDivider(borderColor),

            // Navigation Group
            _buildIconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Previous Page (PageUp)',
              onPressed: currentPage > 1 ? onPrevPage : null,
            ),
            Container(
              width: 44,
              height: 26,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: TextFormField(
                key: ValueKey('page_input_$currentPage'),
                initialValue: '$currentPage',
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onFieldSubmitted: (val) {
                  final page = int.tryParse(val.trim());
                  if (page != null && page >= 1 && page <= pageCount) {
                    onJumpToPage(page);
                  }
                },
              ),
            ),
            Text(
              ' / $pageCount',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            _buildIconButton(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Next Page (PageDown)',
              onPressed: currentPage < pageCount ? onNextPage : null,
            ),
            _buildDivider(borderColor),

            // Zoom & View Group
            _buildIconButton(
              icon: Icons.zoom_out_rounded,
              tooltip: 'Zoom Out (Ctrl+-)',
              onPressed: onZoomOut,
            ),
            PopupMenuButton<String>(
              tooltip: 'Zoom Presets',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${(currentZoom * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'fitWidth',
                  child: Text('Fit Width'),
                ),
                const PopupMenuItem(value: 'fitPage', child: Text('Fit Page')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: '0.5', child: Text('50%')),
                const PopupMenuItem(value: '0.75', child: Text('75%')),
                const PopupMenuItem(
                  value: '1.0',
                  child: Text('100% (Actual Size)'),
                ),
                const PopupMenuItem(value: '1.25', child: Text('125%')),
                const PopupMenuItem(value: '1.5', child: Text('150%')),
                const PopupMenuItem(value: '2.0', child: Text('200%')),
              ],
              onSelected: (val) {
                if (val == 'fitWidth') {
                  onFitWidth();
                } else if (val == 'fitPage') {
                  onFitPage();
                } else {
                  final zoom = double.tryParse(val);
                  if (zoom != null) onSetZoom(zoom);
                }
              },
            ),
            _buildIconButton(
              icon: Icons.zoom_in_rounded,
              tooltip: 'Zoom In (Ctrl++)',
              onPressed: onZoomIn,
            ),
            _buildIconButton(
              icon: Icons.fit_screen_outlined,
              tooltip: 'Fit Width',
              onPressed: onFitWidth,
            ),

            // Layout Mode Popup
            PopupMenuButton<ReaderLayout>(
              tooltip: 'Page Layout Mode',
              icon: Icon(switch (currentLayout) {
                ReaderLayout.singlePage => Icons.filter_1_rounded,
                ReaderLayout.twoPage => Icons.auto_stories_rounded,
                ReaderLayout.continuousHorizontal => Icons.view_column_rounded,
                ReaderLayout.continuousVertical => Icons.view_stream_rounded,
              }, size: 18),
              onSelected: onLayoutChanged,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: ReaderLayout.continuousVertical,
                  child: Text('Continuous Vertical'),
                ),
                PopupMenuItem(
                  value: ReaderLayout.singlePage,
                  child: Text('Single Page'),
                ),
                PopupMenuItem(
                  value: ReaderLayout.twoPage,
                  child: Text('Two Page Spread'),
                ),
                PopupMenuItem(
                  value: ReaderLayout.continuousHorizontal,
                  child: Text('Continuous Horizontal'),
                ),
              ],
            ),

            // Theme Mode Popup
            PopupMenuButton<ReaderThemeMode>(
              tooltip: 'Reading Color Theme',
              icon: Icon(switch (currentTheme) {
                ReaderThemeMode.light => Icons.wb_sunny_outlined,
                ReaderThemeMode.dark => Icons.nightlight_outlined,
                ReaderThemeMode.sepia => Icons.menu_book_outlined,
                ReaderThemeMode.night => Icons.bedtime_outlined,
              }, size: 18),
              onSelected: onThemeChanged,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: ReaderThemeMode.light,
                  child: Text('Light Theme'),
                ),
                PopupMenuItem(
                  value: ReaderThemeMode.dark,
                  child: Text('Dark Theme'),
                ),
                PopupMenuItem(
                  value: ReaderThemeMode.sepia,
                  child: Text('Sepia Theme'),
                ),
                PopupMenuItem(
                  value: ReaderThemeMode.night,
                  child: Text('High Contrast Night'),
                ),
              ],
            ),
            _buildDivider(borderColor),

            // Annotation Tools Group
            _buildIconButton(
              icon: Icons.pan_tool_outlined,
              tooltip: 'Hand / Pan Mode',
              isSelected: annState.activeTool == AnnotationTool.none,
              onPressed: () => annNotifier.setActiveTool(AnnotationTool.none),
            ),
            _buildIconButton(
              icon: Icons.border_color_outlined,
              tooltip: 'Text Highlighter',
              isSelected: annState.activeTool == AnnotationTool.highlighter,
              onPressed: () => annNotifier.setActiveTool(
                annState.activeTool == AnnotationTool.highlighter
                    ? AnnotationTool.none
                    : AnnotationTool.highlighter,
              ),
            ),
            _buildIconButton(
              icon: Icons.format_underlined_outlined,
              tooltip: 'Underline',
              isSelected: annState.activeTool == AnnotationTool.underline,
              onPressed: () => annNotifier.setActiveTool(
                annState.activeTool == AnnotationTool.underline
                    ? AnnotationTool.none
                    : AnnotationTool.underline,
              ),
            ),
            _buildIconButton(
              icon: Icons.format_strikethrough_outlined,
              tooltip: 'Strikethrough',
              isSelected: annState.activeTool == AnnotationTool.strikethrough,
              onPressed: () => annNotifier.setActiveTool(
                annState.activeTool == AnnotationTool.strikethrough
                    ? AnnotationTool.none
                    : AnnotationTool.strikethrough,
              ),
            ),
            _buildIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Freehand Pen',
              isSelected: annState.activeTool == AnnotationTool.pen,
              onPressed: () => annNotifier.setActiveTool(
                annState.activeTool == AnnotationTool.pen
                    ? AnnotationTool.none
                    : AnnotationTool.pen,
              ),
            ),
            _buildIconButton(
              icon: Icons.text_fields_outlined,
              tooltip: 'Text Box / Callout',
              isSelected: annState.activeTool == AnnotationTool.textCallout,
              onPressed: () => annNotifier.setActiveTool(
                annState.activeTool == AnnotationTool.textCallout
                    ? AnnotationTool.none
                    : AnnotationTool.textCallout,
              ),
            ),
            _buildIconButton(
              icon: Icons.sticky_note_2_outlined,
              tooltip: 'Sticky Note',
              isSelected: annState.activeTool == AnnotationTool.stickyNote,
              onPressed: () => annNotifier.setActiveTool(
                annState.activeTool == AnnotationTool.stickyNote
                    ? AnnotationTool.none
                    : AnnotationTool.stickyNote,
              ),
            ),
            _buildIconButton(
              icon: Icons.crop_square_outlined,
              tooltip: 'Rectangle Shape',
              isSelected: annState.activeTool == AnnotationTool.rectangle,
              onPressed: () => annNotifier.setActiveTool(
                annState.activeTool == AnnotationTool.rectangle
                    ? AnnotationTool.none
                    : AnnotationTool.rectangle,
              ),
            ),

            if (annState.activeTool != AnnotationTool.none) ...[
              const SizedBox(width: 4),
              PopupMenuButton<Color>(
                tooltip: 'Select Color',
                icon: CircleAvatar(
                  radius: 8,
                  backgroundColor: annState.currentColor,
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: Color(0xFFFFEB3B),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: Color(0xFFFFEB3B),
                        ),
                        SizedBox(width: 8),
                        Text('Yellow'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: Color(0xFF4CAF50),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: Color(0xFF4CAF50),
                        ),
                        SizedBox(width: 8),
                        Text('Green'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: Color(0xFF2196F3),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: Color(0xFF2196F3),
                        ),
                        SizedBox(width: 8),
                        Text('Blue'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: Color(0xFFE91E63),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: Color(0xFFE91E63),
                        ),
                        SizedBox(width: 8),
                        Text('Pink'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: Color(0xFFFF9800),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: Color(0xFFFF9800),
                        ),
                        SizedBox(width: 8),
                        Text('Orange'),
                      ],
                    ),
                  ),
                ],
                onSelected: annNotifier.setColor,
              ),
              _buildIconButton(
                icon: Icons.undo_rounded,
                tooltip: 'Undo Annotation (Ctrl+Z)',
                onPressed: annState.canUndo ? annNotifier.undo : null,
              ),
              _buildIconButton(
                icon: Icons.redo_rounded,
                tooltip: 'Redo Annotation (Ctrl+Y)',
                onPressed: annState.canRedo ? annNotifier.redo : null,
              ),
            ],
            _buildDivider(borderColor),

            // Utility & Panels Group
            _buildIconButton(
              icon: Icons.search_rounded,
              tooltip: 'Find in Document (Ctrl+F)',
              isSelected: isSearchOpen,
              onPressed: onToggleSearch,
            ),
            _buildIconButton(
              icon: Icons.auto_awesome_outlined,
              tooltip: 'AI Document Assistant & Comments',
              isSelected: isRightPanelOpen,
              onPressed: onToggleRightPanel,
            ),
            _buildIconButton(
              icon: Icons.auto_stories_outlined,
              tooltip: 'Page Organizer',
              onPressed: onOpenPageOrganizer,
            ),
            _buildIconButton(
              icon: Icons.lock_outline_rounded,
              tooltip: 'Protect with Password',
              onPressed: onOpenPasswordProtect,
            ),
            _buildIconButton(
              icon: Icons.info_outline_rounded,
              tooltip: 'Document Properties',
              onPressed: onOpenProperties,
            ),
          ],
        ),
      ),
    );
  }
}
