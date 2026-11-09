import 'package:flutter/material.dart';
import '../domain/ai_document_service.dart';

/// Interactive grounded AI Assistant modal sheet with citations and prompt chips.
class AiAssistantSheet extends StatefulWidget {
  final Map<int, String> pageTexts;
  final ValueChanged<int> onJumpToPage;

  const AiAssistantSheet({
    super.key,
    required this.pageTexts,
    required this.onJumpToPage,
  });

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  final AiDocumentService _aiService = AiDocumentService();
  final TextEditingController _queryController = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      const _ChatMessage(
        text:
            '👋 Hello! I am your grounded **IT PDF Assistant**. Ask any question about this document, or tap a quick action below.',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _runAction(String label, String Function() action) {
    setState(() {
      _messages.add(_ChatMessage(text: label, isUser: true));
      _isAnalyzing = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      final answer = action();
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(text: answer, isUser: false));
          _isAnalyzing = false;
        });
      }
    });
  }

  void _handleSend() {
    final text = _queryController.text.trim();
    if (text.isEmpty) return;

    _queryController.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isAnalyzing = true;
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      final answer = _aiService.answerQuestion(
        question: text,
        pageTexts: widget.pageTexts,
      );
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(text: answer, isUser: false));
          _isAnalyzing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header Drag Handle & Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.blueAccent),
                const SizedBox(width: 8),
                const Text(
                  'AI Document Assistant',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Quick Action Suggestion Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.summarize_outlined, size: 16),
                  label: const Text('Summarize PDF'),
                  onPressed: () => _runAction(
                    'Summarize this document',
                    () => _aiService.generateSummary(widget.pageTexts),
                  ),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: const Text('Key Dates'),
                  onPressed: () => _runAction(
                    'Extract key dates and deadlines',
                    () => _aiService.extractKeyDates(widget.pageTexts),
                  ),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.task_alt, size: 16),
                  label: const Text('Action Items'),
                  onPressed: () => _runAction(
                    'Extract action items and obligations',
                    () => _aiService.extractActionItems(widget.pageTexts),
                  ),
                ),
              ],
            ),
          ),

          // Chat Messages List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _MessageBubble(
                  message: msg,
                  onJumpToPage: widget.onJumpToPage,
                );
              },
            ),
          ),

          if (_isAnalyzing)
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
                    'Analyzing document text...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

          // Input field
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161F30) : Colors.white,
              border: const Border(top: BorderSide(color: Colors.black12)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      decoration: InputDecoration(
                        hintText: 'Ask anything about this document...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send, size: 18),
                    onPressed: _handleSend,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final ValueChanged<int> onJumpToPage;

  const _MessageBubble({required this.message, required this.onJumpToPage});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? Colors.blueAccent
              : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(14),
        ),
        child: SelectableText(
          message.text,
          style: TextStyle(
            color: message.isUser
                ? Colors.white
                : (isDark ? Colors.white : Colors.black87),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
