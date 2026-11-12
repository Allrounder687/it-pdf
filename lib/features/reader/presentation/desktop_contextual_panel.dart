import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_theme.dart';
import '../../ai_assistant/domain/ai_document_service.dart';
import '../../annotations/domain/annotation_notifier.dart';

enum ContextualPanelMode { ai, annotations }

/// Right docked contextual panel for AI assistance and annotation management.
class DesktopContextualPanel extends ConsumerStatefulWidget {
  final String documentId;
  final String documentPath;
  final Map<int, String> pageTexts;
  final int currentPage;
  final ValueChanged<int> onJumpToPage;
  final VoidCallback onClose;
  final ContextualPanelMode initialMode;

  const DesktopContextualPanel({
    super.key,
    required this.documentId,
    required this.documentPath,
    required this.pageTexts,
    required this.currentPage,
    required this.onJumpToPage,
    required this.onClose,
    this.initialMode = ContextualPanelMode.ai,
  });

  @override
  ConsumerState<DesktopContextualPanel> createState() =>
      _DesktopContextualPanelState();
}

class _DesktopContextualPanelState
    extends ConsumerState<DesktopContextualPanel> {
  late ContextualPanelMode _mode;
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  final List<_AiChatMessage> _chatMessages = [];
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    if (_chatMessages.isEmpty) {
      _chatMessages.add(
        const _AiChatMessage(
          isUser: false,
          text:
              'Hello! I can analyze, summarize, and answer questions about this PDF document with grounded page citations.',
        ),
      );
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  Future<void> _askAi(String prompt) async {
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty || _isGenerating) return;

    setState(() {
      _chatMessages.add(_AiChatMessage(isUser: true, text: cleanPrompt));
      _isGenerating = true;
      _queryController.clear();
    });

    _scrollToBottom();

    try {
      final aiService = AiDocumentService();
      final response = aiService.queryDocument(
        pageTexts: widget.pageTexts,
        query: cleanPrompt,
      );

      if (mounted) {
        setState(() {
          _chatMessages.add(
            _AiChatMessage(
              isUser: false,
              text: response.answer,
              citedPages: response.citedPages,
            ),
          );
          _isGenerating = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chatMessages.add(
            _AiChatMessage(
              isUser: false,
              text: 'Unable to analyze document at this time: $e',
            ),
          );
          _isGenerating = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppTheme.darkSurfaceVariant
        : AppTheme.lightSurfaceVariant;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: [
                SegmentedButton<ContextualPanelMode>(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: ContextualPanelMode.ai,
                      icon: Icon(Icons.auto_awesome, size: 15),
                      label: Text(
                        'AI Assistant',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    ButtonSegment(
                      value: ContextualPanelMode.annotations,
                      icon: Icon(Icons.comment_outlined, size: 15),
                      label: Text('Comments', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (set) {
                    if (set.isNotEmpty) {
                      setState(() => _mode = set.first);
                    }
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Close Panel',
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Body Content
          Expanded(
            child: _mode == ContextualPanelMode.ai
                ? _buildAiView(isDark)
                : _buildAnnotationsView(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildAiView(bool isDark) {
    return Column(
      children: [
        // Quick prompts strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text(
                    'Summarize',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: () => _askAi(
                    'Provide a concise executive summary of this document.',
                  ),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text(
                    'Key Dates',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: () => _askAi(
                    'Identify all dates, deadlines, and timelines mentioned in this document.',
                  ),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text(
                    'Action Items',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: () => _askAi(
                    'Extract all key recommendations and actionable items.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // Message Thread
        Expanded(
          child: ListView.builder(
            controller: _chatScroll,
            padding: const EdgeInsets.all(12),
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
              final msg = _chatMessages[index];
              return _buildChatBubble(msg, isDark);
            },
          ),
        ),

        if (_isGenerating)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Analyzing document context...',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),

        // Input Box
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark
                    ? const Color(0xFF263346)
                    : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Ask about this document...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onSubmitted: _askAi,
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                icon: const Icon(Icons.send_rounded, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: () => _askAi(_queryController.text),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatBubble(_AiChatMessage msg, bool isDark) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 270),
        decoration: BoxDecoration(
          color: msg.isUser
              ? Colors.blueAccent
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: msg.isUser
              ? null
              : Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              msg.text,
              style: TextStyle(
                fontSize: 12,
                color: msg.isUser ? Colors.white : null,
              ),
            ),
            if (msg.citedPages != null && msg.citedPages!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: msg.citedPages!.map((pageNum) {
                  return InkWell(
                    onTap: () => widget.onJumpToPage(pageNum),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'p. $pageNum',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnnotationsView(bool isDark) {
    final annState = ref.watch(annotationNotifierProvider(widget.documentId));
    final annNotifier = ref.read(
      annotationNotifierProvider(widget.documentId).notifier,
    );
    final annotations = annState.annotations;

    if (annotations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.comment_outlined, size: 36, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'No annotations or comments yet.\nUse the toolbar to highlight, draw, or add sticky notes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: annotations.length,
      itemBuilder: (context, index) {
        final ann = annotations[index];
        final isCurrentPage = ann.pageNumber == widget.currentPage;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isCurrentPage
                  ? Colors.blueAccent
                  : (isDark ? Colors.white12 : Colors.black12),
              width: isCurrentPage ? 1.5 : 0.5,
            ),
          ),
          child: ListTile(
            dense: true,
            onTap: () => widget.onJumpToPage(ann.pageNumber),
            leading: CircleAvatar(radius: 10, backgroundColor: ann.color),
            title: Text(
              ann.type.name.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Page ${ann.pageNumber} • ${ann.text?.trim() ?? "Stroke / Shape"}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              tooltip: 'Delete Annotation',
              onPressed: () => annNotifier.deleteAnnotation(ann.id),
            ),
          ),
        );
      },
    );
  }
}

class _AiChatMessage {
  final bool isUser;
  final String text;
  final List<int>? citedPages;

  const _AiChatMessage({
    required this.isUser,
    required this.text,
    this.citedPages,
  });
}
