import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_theme.dart';
import '../../annotations/domain/annotation_model.dart';
import '../../annotations/domain/annotation_notifier.dart';
import '../domain/reader_state.dart';

/// Desktop Reader Toolbar combining Navigation, View, Annotation, and Document tools
/// with an executive Microsoft Fluent aesthetic and primary Back to Home control.
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

  final VoidCallback? onBackToHome;
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
    this.onBackToHome,
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
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: borderColor,
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool isSelected = false,
    Widget? badge,
    Color? activeColor,
    Color? inactiveColor,
  }) {
    final effectiveActive = activeColor ?? AppTheme.primaryBlue;
    final button = IconButton(
      icon: Icon(icon, size: 16),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      color: isSelected ? effectiveActive : inactiveColor,
      style: isSelected
          ? IconButton.styleFrom(
              backgroundColor: effectiveActive.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            )
          : IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
      onPressed: onPressed,
    );

    if (badge != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          button,
          Positioned(top: 5, right: 5, child: badge),
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

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Upper-left Back to Home Action
            if (onBackToHome != null) ...[
              Tooltip(
                message: 'Back to Home Screen (Alt+Left)',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: onBackToHome,
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 15,
                          color: textPrimary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Home',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildDivider(borderColor),
            ],

            // Navigation Panel Toggle
            _buildIconButton(
              icon: Icons.view_sidebar_outlined,
              tooltip: isLeftPanelOpen
                  ? 'Hide Navigation Panel'
                  : 'Show Navigation Panel (Pages / Outline / Bookmarks)',
              isSelected: isLeftPanelOpen,
              activeColor: accentColor,
              inactiveColor: textSecondary,
              onPressed: onToggleLeftPanel,
            ),
            _buildDivider(borderColor),

            // Page Navigation Group
            _buildIconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Previous Page (PageUp)',
              onPressed: currentPage > 1 ? onPrevPage : null,
              activeColor: accentColor,
              inactiveColor: textSecondary,
            ),
            Container(
              width: 38,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: TextFormField(
                key: ValueKey('page_input_$currentPage'),
                initialValue: '$currentPage',
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3),
                    borderSide: BorderSide(color: accentColor),
                  ),
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
              style: TextStyle(fontSize: 11, color: textSecondary),
            ),
            _buildIconButton(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Next Page (PageDown)',
              onPressed: currentPage < pageCount ? onNextPage : null,
              activeColor: accentColor,
              inactiveColor: textSecondary,
            ),
            _buildDivider(borderColor),

            // Zoom & View Group
            _buildIconButton(
              icon: Icons.zoom_out_rounded,
              tooltip: 'Zoom Out (Ctrl+-)',
              onPressed: onZoomOut,
              activeColor: accentColor,
              inactiveColor: textSecondary,
            ),
            PopupMenuButton<String>(
              tooltip: 'Zoom Presets',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${(currentZoom * 100).round()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 14, color: textSecondary),
                  ],
                ),
              ),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'fitWidth', child: Text('Fit Width')),
                PopupMenuItem(value: 'fitPage', child: Text('Fit Page')),
                PopupMenuDivider(),
                PopupMenuItem(value: '0.5', child: Text('50%')),
                PopupMenuItem(value: '0.75', child: Text('75%')),
                PopupMenuItem(value: '1.0', child: Text('100% (Actual Size)')),
                PopupMenuItem(value: '1.25', child: Text('125%')),
                PopupMenuItem(value: '1.5', child: Text('150%')),
                PopupMenuItem(value: '2.0', child: Text('200%')),
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
              activeColor: accentColor,
              inactiveColor: textSecondary,
            ),
            _buildIconButton(
              icon: Icons.fit_screen_outlined,
              tooltip: 'Fit Width',
              onPressed: onFitWidth,
              activeColor: accentColor,
              inactiveColor: textSecondary,
            ),

            // Reading Layout Mode Dropdown
            PopupMenuButton<ReaderLayout>(
              tooltip: 'Page Layout Mode',
              icon: Icon(
                switch (currentLayout) {
                  ReaderLayout.singlePage => Icons.filter_1_rounded,
                  ReaderLayout.twoPage => Icons.auto_stories_rounded,
                  ReaderLayout.continuousHorizontal =>
                    Icons.view_column_rounded,
                  ReaderLayout.continuousVertical => Icons.view_stream_rounded,
                },
                size: 16,
                color: textSecondary,
              ),
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

            // Color Theme Mode Dropdown
            PopupMenuButton<ReaderThemeMode>(
              tooltip: 'Reading Color Theme',
              icon: Icon(
                switch (currentTheme) {
                  ReaderThemeMode.light => Icons.wb_sunny_outlined,
                  ReaderThemeMode.dark => Icons.nightlight_outlined,
                  ReaderThemeMode.sepia => Icons.menu_book_outlined,
                  ReaderThemeMode.night => Icons.bedtime_outlined,
                },
                size: 16,
                color: textSecondary,
              ),
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
              activeColor: accentColor,
              inactiveColor: textSecondary,
              onPressed: () => annNotifier.setActiveTool(AnnotationTool.none),
            ),
            _buildIconButton(
              icon: Icons.border_color_outlined,
              tooltip: 'Text Highlighter',
              isSelected: annState.activeTool == AnnotationTool.highlighter,
              activeColor: accentColor,
              inactiveColor: textSecondary,
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
              activeColor: accentColor,
              inactiveColor: textSecondary,
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
              activeColor: accentColor,
              inactiveColor: textSecondary,
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
              activeColor: accentColor,
              inactiveColor: textSecondary,
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
              activeColor: accentColor,
              inactiveColor: textSecondary,
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
              activeColor: accentColor,
              inactiveColor: textSecondary,
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
              activeColor: accentColor,
              inactiveColor: textSecondary,
              onPressed: () => annNotifier.setActiveTool(
                annState.activeTool == AnnotationTool.rectangle
                    ? AnnotationTool.none
                    : AnnotationTool.rectangle,
              ),
            ),

            if (annState.activeTool != AnnotationTool.none) ...[
              const SizedBox(width: 2),
              PopupMenuButton<Color>(
                tooltip: 'Select Color',
                icon: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: annState.currentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor),
                  ),
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: Color(0xFFFFEB3B),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 7,
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
                          radius: 7,
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
                          radius: 7,
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
                          radius: 7,
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
                          radius: 7,
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
                activeColor: accentColor,
                inactiveColor: textSecondary,
              ),
              _buildIconButton(
                icon: Icons.redo_rounded,
                tooltip: 'Redo Annotation (Ctrl+Y)',
                onPressed: annState.canRedo ? annNotifier.redo : null,
                activeColor: accentColor,
                inactiveColor: textSecondary,
              ),
            ],
            _buildDivider(borderColor),

            // Document & File Group
            _buildIconButton(
              icon: Icons.save_outlined,
              tooltip: 'Save Changes (Ctrl+S)',
              badge: (isDirty || annState.isDirty)
                  ? Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.highlightAmber,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
              activeColor: accentColor,
              inactiveColor: textSecondary,
              onPressed: onSave,
            ),
            _buildIconButton(
              icon: Icons.save_as_outlined,
              tooltip: 'Save As (Ctrl+Shift+S)',
              activeColor: accentColor,
              inactiveColor: textSecondary,
              onPressed: onSaveAs,
            ),
            _buildIconButton(
              icon: Icons.print_outlined,
              tooltip: 'Print Document (Ctrl+P)',
              activeColor: accentColor,
              inactiveColor: textSecondary,
              onPressed: onPrint,
            ),
            _buildIconButton(
              icon: Icons.search_rounded,
              tooltip: 'Find in Document (Ctrl+F)',
              isSelected: isSearchOpen,
              activeColor: accentColor,
              inactiveColor: textSecondary,
              onPressed: onToggleSearch,
            ),
            _buildIconButton(
              icon: Icons.auto_awesome_outlined,
              tooltip: 'AI Document Assistant & Comments',
              isSelected: isRightPanelOpen,
              activeColor: accentColor,
              inactiveColor: textSecondary,
              onPressed: onToggleRightPanel,
            ),

            // More Document Actions Overflow Popup
            PopupMenuButton<String>(
              tooltip: 'More Document Actions',
              icon: Icon(
                Icons.more_horiz_rounded,
                size: 16,
                color: textSecondary,
              ),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'organizer',
                  child: Row(
                    children: [
                      Icon(Icons.auto_stories_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Page Organizer'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'protect',
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Protect with Password'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'properties',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Document Properties'),
                    ],
                  ),
                ),
              ],
              onSelected: (val) {
                switch (val) {
                  case 'organizer':
                    onOpenPageOrganizer();
                    break;
                  case 'protect':
                    onOpenPasswordProtect();
                    break;
                  case 'properties':
                    onOpenProperties();
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
