import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../domain/tool_task_notifier.dart';
import 'pdf_tool_model.dart';

/// Interactive capability preview modal with file selection, fullscreen expander,
/// and live background multi-task execution dock.
class ToolPreviewModal extends ConsumerStatefulWidget {
  final PdfTool tool;
  final VoidCallback onOpenFullscreen;
  final VoidCallback? onMinimizeToTray;

  const ToolPreviewModal({
    super.key,
    required this.tool,
    required this.onOpenFullscreen,
    this.onMinimizeToTray,
  });

  @override
  ConsumerState<ToolPreviewModal> createState() => _ToolPreviewModalState();
}

class _ToolPreviewModalState extends ConsumerState<ToolPreviewModal> {
  String? _selectedFilePath;
  bool _isFullscreen = false;

  Map<String, List<String>> get _toolCapabilities => {
    'edit_pdf': [
      'Direct visual canvas object manipulation',
      'Add, edit, or delete existing PDF text blocks',
      'Place custom electronic signatures & initials',
      'Draw vector shapes (rectangles, circles, arrows, lines)',
      'Multi-layer object selection, resizing, and rotation',
    ],
    'compress_pdf': [
      'Lossless stream & font table optimization',
      'Adjustable DPI profiles (Screen 85 DPI, Balanced 120 DPI, Print 200 DPI)',
      'Real-time before/after size & percentage savings telemetry',
      'Preserves bookmarks, hyperlinks, and vector sharpness',
    ],
    'merge_pdf': [
      'Combine multiple PDF documents into one master file',
      'Drag-and-drop reorderable file queue',
      'Custom per-file page range selections (e.g., 1-5, 8)',
      'Auto-generates hierarchical Table of Contents bookmarks',
    ],
    'split_pdf': [
      'Extract custom page ranges into standalone documents',
      'Burst mode: split every page into individual single-page PDFs',
      'Chunk mode: split into equal N-page volume segments',
      'Batch export directly into a chosen folder',
    ],
    'watermark': [
      'Direct on-canvas drag, rotate, and resize positioning',
      'Preset text badges (CONFIDENTIAL, DRAFT, APPROVED)',
      'Custom opacity, font size, rotation angle, and colors',
      'Full-page continuous tiling option across all or target pages',
    ],
    'page_numbers': [
      'Interactive 6-zone page positioning frame',
      'Bates stamping format (e.g., CASE-0001)',
      'Cover page skip option',
      'Custom starting index and typography sizing',
    ],
    'protect_pdf': [
      'Industry-standard AES-256 and AES-128 encryption',
      'Granular permission restrictions (printing, copying, annotations)',
      'Live password strength analysis meter',
      'Owner vs User authorization controls',
    ],
    'unlock_pdf': [
      'Authorized password stripping for unrestricted reading',
      'Restores full printing, copying, and modification rights',
      '100% private offline decryption on device',
    ],
    'pdf_to_images': [
      'Export pages to high-resolution PNG format',
      'Variable rendering resolutions: 72, 150, or 300 DPI',
      'Batch export all pages or target specific page subsets',
    ],
    'images_to_pdf': [
      'Convert JPEG, PNG, and WebP into crisp multi-page PDFs',
      'Page dimensions: A4, US Letter, or Fit to Image',
      'Adjustable margin padding and auto-orientation',
    ],
    'organize_pages': [
      'Visual thumbnail grid of all document pages',
      'Drag-and-drop page reordering',
      'Rotate individual or selected page batches by 90° / 180°',
      'Delete unwanted pages with live undo',
    ],
    'esign_pdf': [
      'Create and save smooth vector signatures',
      'Place signature stamps anywhere on the page',
      'Add timestamps and verified signer badges',
    ],
    'ai_assistant': [
      '1-Click Executive Summary generation',
      'Instant Key Dates & Timeline milestone extraction',
      'Action Items & Obligations extraction checklist',
      '100% offline grounded processing — zero API keys required',
    ],
    'create_blank_pdf': [
      'Blank canvas, College Ruled, Engineering Grid, and Dot Matrix',
      'Custom page counts and subtle paper background tints',
    ],
    'extract_text': [
      'Extract full text streams from any readable PDF',
      'Live search filter and word/character analytics',
      'Export clean .txt file or copy to system clipboard',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(toolTaskManagerProvider);
    final activeTask = tasks.cast<ToolTask?>().firstWhere(
      (t) => t?.toolId == widget.tool.id,
      orElse: () => null,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B0E14) : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFF1E2430)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    final capabilities =
        _toolCapabilities[widget.tool.id] ??
        [
          widget.tool.description,
          '100% private & offline processing on device',
          'Fast native execution with instant preview',
        ];

    final modalWidth = _isFullscreen
        ? MediaQuery.of(context).size.width * 0.95
        : 680.0;
    final modalHeight = _isFullscreen
        ? MediaQuery.of(context).size.height * 0.90
        : 580.0;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorder, width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: modalWidth,
        height: modalHeight,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Icon, Title, Badge, Fullscreen & Minimize Controls
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF181D27)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Icon(widget.tool.icon, size: 24, color: textPrimary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.tool.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E2430)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.tool.badge ?? widget.tool.category.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.tool.description,
                        style: TextStyle(fontSize: 12, color: textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Minimize to Tray
                if (widget.onMinimizeToTray != null)
                  IconButton(
                    tooltip: 'Minimize to Task Tray',
                    icon: const Icon(
                      Icons.vertical_align_bottom_rounded,
                      size: 20,
                    ),
                    onPressed: widget.onMinimizeToTray,
                  ),
                // Fullscreen Toggle
                IconButton(
                  tooltip: _isFullscreen
                      ? 'Exit Fullscreen'
                      : 'Expand Fullscreen',
                  icon: Icon(
                    _isFullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() => _isFullscreen = !_isFullscreen);
                  },
                ),
                // Close
                IconButton(
                  tooltip: 'Close Preview',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: cardBorder, height: 1),
            const SizedBox(height: 16),

            // Middle Content: Capabilities & Status
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Capabilities Column
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF111622)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.checklist_rounded,
                                size: 16,
                                color: textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'CAPABILITIES & FEATURES',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView(
                              children: capabilities.map((cap) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 14,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          cap,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.35,
                                            color: textPrimary.withAlpha(220),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Execution / Status Column
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Live Status Badge if Active Task
                        if (activeTask != null) ...[
                          _buildActiveTaskCard(activeTask, isDark),
                          const SizedBox(height: 12),
                        ],

                        // File Dropzone / Picker
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picker = ref.read(
                                filePickerServiceProvider,
                              );
                              final path = await picker.pickPdfFile();
                              if (path != null) {
                                setState(() => _selectedFilePath = path);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF111622)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedFilePath != null
                                      ? Colors.blueAccent
                                      : cardBorder,
                                  style: BorderStyle.solid,
                                  width: _selectedFilePath != null ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _selectedFilePath != null
                                        ? Icons.description_rounded
                                        : Icons.upload_file_rounded,
                                    size: 36,
                                    color: _selectedFilePath != null
                                        ? Colors.blueAccent
                                        : textSecondary,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _selectedFilePath != null
                                        ? _selectedFilePath!
                                              .split(r'\')
                                              .last
                                              .split('/')
                                              .last
                                        : 'Click or Drop PDF here',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _selectedFilePath != null
                                        ? 'Ready to process'
                                        : 'Select document for this tool',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bottom Action Bar
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.fullscreen_rounded, size: 18),
                    label: const Text('Open Fullscreen Studio'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(color: cardBorder),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onOpenFullscreen();
                    },
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Launch Tool'),
                    style: FilledButton.styleFrom(
                      backgroundColor: textPrimary,
                      foregroundColor: bgColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.tool.execute(context, ref);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTaskCard(ToolTask task, bool isDark) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (task.status) {
      case ToolTaskStatus.running:
        statusColor = const Color(0xFFEAB308); // Amber / Yellow
        statusLabel = 'Processing (${(task.progress * 100).toInt()}%)';
        statusIcon = Icons.sync_rounded;
        break;
      case ToolTaskStatus.completed:
        statusColor = const Color(0xFF10B981); // Emerald Green
        statusLabel = 'Finished';
        statusIcon = Icons.check_circle_rounded;
        break;
      case ToolTaskStatus.error:
        statusColor = const Color(0xFFEF4444); // Crimson Red
        statusLabel = 'Failed';
        statusIcon = Icons.error_rounded;
        break;
      case ToolTaskStatus.idle:
        statusColor = Colors.grey;
        statusLabel = 'Queued';
        statusIcon = Icons.hourglass_empty_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withAlpha(120), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            task.statusMessage,
            style: const TextStyle(fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (task.status == ToolTaskStatus.running) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: task.progress > 0 ? task.progress : null,
              color: statusColor,
              backgroundColor: statusColor.withAlpha(40),
            ),
          ],
        ],
      ),
    );
  }
}
