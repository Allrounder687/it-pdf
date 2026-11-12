import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/ai_document_service.dart';

/// Interactive grounded AI Assistant modal sheet with citations and prompt chips.
class AiAssistantSheet extends ConsumerStatefulWidget {
  final Map<int, String> pageTexts;
  final ValueChanged<int> onJumpToPage;

  const AiAssistantSheet({
    super.key,
    required this.pageTexts,
    required this.onJumpToPage,
  });

  @override
  ConsumerState<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends ConsumerState<AiAssistantSheet> {
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
            '👋 Hello! I am your grounded **IT PDF Assistant**. Ask any question about this document, tap a quick action below, or tap the gear icon above to configure a cloud AI API key.',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _submitPrompt(String prompt, {String? displayLabel}) async {
    final prefs = ref.read(preferencesServiceProvider);
    final provider = prefs.getAiProvider();
    final apiKey = prefs.getAiApiKey();
    final model = prefs.getAiModel();
    final customEndpoint = prefs.getAiCustomEndpoint();

    setState(() {
      _messages.add(_ChatMessage(text: displayLabel ?? prompt, isUser: true));
      _isAnalyzing = true;
    });

    final answer = await _aiService.answerQuestionWithAi(
      question: prompt,
      pageTexts: widget.pageTexts,
      provider: provider,
      apiKey: apiKey,
      model: model,
      customEndpoint: customEndpoint,
    );

    if (mounted) {
      setState(() {
        _messages.add(_ChatMessage(text: answer, isUser: false));
        _isAnalyzing = false;
      });
    }
  }

  void _handleSend() {
    final text = _queryController.text.trim();
    if (text.isEmpty || _isAnalyzing) return;
    _queryController.clear();
    _submitPrompt(text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefs = ref.watch(preferencesServiceProvider);
    final provider = prefs.getAiProvider();
    final hasKey = prefs.getAiApiKey().trim().isNotEmpty;
    final engineLabel = (provider != 'offline' && hasKey)
        ? provider.toUpperCase()
        : 'OFFLINE';

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
                const SizedBox(width: 8),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.key_outlined, size: 14),
                  label: Text(
                    engineLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  tooltip: 'Configure AI provider & API key',
                  onPressed: () async {
                    await showAiSettingsDialog(context);
                    if (mounted) setState(() {});
                  },
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'AI API Key Settings',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () async {
                    await showAiSettingsDialog(context);
                    if (mounted) setState(() {});
                  },
                ),
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
                  onPressed: _isAnalyzing
                      ? null
                      : () => _submitPrompt('Summarize this document'),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: const Text('Key Dates'),
                  onPressed: _isAnalyzing
                      ? null
                      : () => _submitPrompt('Extract key dates and deadlines'),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.task_alt, size: 16),
                  label: const Text('Action Items'),
                  onPressed: _isAnalyzing
                      ? null
                      : () => _submitPrompt(
                          'Extract action items and obligations',
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
