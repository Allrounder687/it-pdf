import 'dart:convert';
import 'dart:io';

/// Grounded AI Document Assistant service.
/// Analyzes extracted page text with strict citation guardrails [Page X].
class AiDocumentService {
  /// Generate a grounded executive summary of the document.
  String generateSummary(Map<int, String> pageTexts) {
    if (pageTexts.isEmpty) {
      return 'No readable text content extracted from document.';
    }

    final totalWords = pageTexts.values.fold<int>(
      0,
      (sum, text) =>
          sum + text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
    );

    final buffer = StringBuffer();
    buffer.writeln('📋 **Executive Document Summary**');
    buffer.writeln(
      '• **Scope:** ${pageTexts.length} pages, ~$totalWords total words analyzed.',
    );
    buffer.writeln();

    for (final entry in pageTexts.entries) {
      final pageNum = entry.key;
      final text = entry.value;
      if (text.isEmpty) continue;

      final sentences = text
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((s) => s.trim())
          .where((s) => s.length > 20)
          .take(2)
          .toList();

      if (sentences.isNotEmpty) {
        buffer.writeln('**[Page $pageNum]**');
        for (final s in sentences) {
          buffer.writeln('• $s');
        }
        buffer.writeln();
      }
    }

    return buffer.toString().trim();
  }

  /// Extract all dates, deadlines, and milestones with grounded page citations.
  String extractKeyDates(Map<int, String> pageTexts) {
    final dateRegex = RegExp(
      r'\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}|\b20\d{2}\b)',
      caseSensitive: false,
    );

    final results = <String>[];

    for (final entry in pageTexts.entries) {
      final pageNum = entry.key;
      final matches = dateRegex.allMatches(entry.value);
      for (final m in matches) {
        final dateStr = m.group(0)!;
        // Find sentence containing the date
        final start = (m.start - 40).clamp(0, entry.value.length);
        final end = (m.end + 60).clamp(0, entry.value.length);
        final snippet = entry.value
            .substring(start, end)
            .replaceAll('\n', ' ')
            .trim();
        results.add('• **$dateStr** — "...$snippet..." **[Page $pageNum]**');
      }
    }

    if (results.isEmpty) {
      return 'No specific dates or calendar milestones detected in the document.';
    }

    return '📅 **Key Dates & Milestones (Grounded Extracted):**\n\n${results.take(15).join('\n\n')}';
  }

  /// Extract obligations, requirements, and action items with page citations.
  String extractActionItems(Map<int, String> pageTexts) {
    final actionRegex = RegExp(
      r'([^.!?]*\b(?:shall|must|required to|agrees to|responsible for|deadline|deliverable|action item)\b[^.!?]*)',
      caseSensitive: false,
    );

    final results = <String>[];

    for (final entry in pageTexts.entries) {
      final pageNum = entry.key;
      final matches = actionRegex.allMatches(entry.value);
      for (final m in matches) {
        final snippet = m.group(1)?.replaceAll('\n', ' ').trim();
        if (snippet != null && snippet.length > 25) {
          results.add('• $snippet **[Page $pageNum]**');
        }
      }
    }

    if (results.isEmpty) {
      return 'No explicit action items or mandatory obligations detected in document text.';
    }

    return '✅ **Action Items & Obligations:**\n\n${results.take(12).join('\n\n')}';
  }

  /// Grounded Question & Answer with mandatory page references.
  String answerQuestion({
    required String question,
    required Map<int, String> pageTexts,
  }) {
    final qTerms = question
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 3)
        .toList();

    if (qTerms.isEmpty) {
      return 'Please enter a more specific question regarding the document.';
    }

    final scoredPages = <int, List<String>>{};

    for (final entry in pageTexts.entries) {
      final pageNum = entry.key;
      final sentences = entry.value.split(RegExp(r'(?<=[.!?])\s+'));

      for (final sentence in sentences) {
        final lower = sentence.toLowerCase();
        int matchCount = 0;
        for (final term in qTerms) {
          if (lower.contains(term)) matchCount++;
        }

        if (matchCount > 0) {
          scoredPages.putIfAbsent(pageNum, () => []).add(sentence.trim());
        }
      }
    }

    if (scoredPages.isEmpty) {
      return 'Information regarding "$question" was not found in this document.';
    }

    final buffer = StringBuffer();
    buffer.writeln('💡 **Answer (Grounded in Document Content):**\n');

    for (final entry in scoredPages.entries.take(3)) {
      final pageNum = entry.key;
      final excerpts = entry.value.take(2);
      for (final exc in excerpts) {
        buffer.writeln('• "$exc" **[Page $pageNum]**\n');
      }
    }

    return buffer.toString().trim();
  }

  /// Unified entrypoint for document queries returning grounded answer and citation page numbers.
  AiResponse queryDocument({
    required Map<int, String> pageTexts,
    required String query,
  }) {
    final lower = query.toLowerCase();
    String text;
    if (lower.contains('summar')) {
      text = generateSummary(pageTexts);
    } else if (lower.contains('date') ||
        lower.contains('deadline') ||
        lower.contains('timeline')) {
      text = extractKeyDates(pageTexts);
    } else if (lower.contains('action') ||
        lower.contains('obligation') ||
        lower.contains('task')) {
      text = extractActionItems(pageTexts);
    } else {
      text = answerQuestion(question: query, pageTexts: pageTexts);
    }

    final pageRegex = RegExp(r'\[Page\s+(\d+)\]', caseSensitive: false);
    final pages = <int>{};
    for (final m in pageRegex.allMatches(text)) {
      final p = int.tryParse(m.group(1)!);
      if (p != null) pages.add(p);
    }

    return AiResponse(answer: text, citedPages: pages.toList()..sort());
  }

  /// Queries a configured cloud AI provider (Gemini or OpenAI-compatible),
  /// strictly grounded in extracted `[Page X]` text, with automatic fallback
  /// to the offline grounded engine if unconfigured or unreachable.
  Future<String> answerQuestionWithAi({
    required String question,
    required Map<int, String> pageTexts,
    String provider = 'offline',
    String apiKey = '',
    String model = '',
    String customEndpoint = '',
  }) async {
    final normalizedProvider = provider.trim().toLowerCase();
    final trimmedKey = apiKey.trim();

    if (normalizedProvider == 'offline' || trimmedKey.isEmpty) {
      return queryDocument(pageTexts: pageTexts, query: question).answer;
    }

    final contextBuffer = StringBuffer();
    final sortedKeys = pageTexts.keys.toList()..sort();
    for (final pageNum in sortedKeys) {
      final pageBody = (pageTexts[pageNum] ?? '').trim();
      if (pageBody.isEmpty) continue;
      if (contextBuffer.length + pageBody.length > 48000) {
        contextBuffer.writeln(
          '\n[Truncated remaining pages to stay within request context limit]',
        );
        break;
      }
      contextBuffer.writeln('--- [Page $pageNum] ---\n$pageBody\n');
    }

    final docContext = contextBuffer.toString().trim();
    if (docContext.isEmpty) {
      return 'No readable text content extracted from document.';
    }

    const systemPrompt =
        'You are the IT PDF Document Assistant. Answer strictly using the '
        'provided document excerpts and always cite sources as [Page X]. '
        'If the answer is not in the document, state that clearly.';
    final userPrompt =
        'Document excerpts:\n$docContext\n\nUser request: $question';

    try {
      if (normalizedProvider == 'gemini') {
        final resolvedModel = model.trim().isEmpty
            ? 'gemini-2.5-flash'
            : model.trim();
        return await _queryGemini(
          apiKey: trimmedKey,
          model: resolvedModel,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
        );
      }

      if (normalizedProvider == 'openai') {
        final resolvedModel = model.trim().isEmpty
            ? 'gpt-4o-mini'
            : model.trim();
        return await _queryOpenAi(
          apiKey: trimmedKey,
          model: resolvedModel,
          customEndpoint: customEndpoint.trim(),
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
        );
      }
    } catch (e) {
      final offlineFallback = queryDocument(
        pageTexts: pageTexts,
        query: question,
      ).answer;
      return '$offlineFallback\n\n_(Cloud AI fallback notice: $e)_';
    }

    return queryDocument(pageTexts: pageTexts, query: question).answer;
  }

  Future<String> _queryGemini({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '${Uri.encodeComponent(model)}:generateContent?key=${Uri.encodeQueryComponent(apiKey)}',
    );
    final payload = {
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userPrompt},
          ],
        },
      ],
    };

    final body = await _postJson(uri: uri, payload: payload);
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini returned no candidates.');
    }
    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final text = parts
        ?.map((p) => (p as Map<String, dynamic>)['text']?.toString() ?? '')
        .join('\n')
        .trim();
    if (text == null || text.isEmpty) {
      throw Exception('Gemini returned an empty response.');
    }
    return text;
  }

  Future<String> _queryOpenAi({
    required String apiKey,
    required String model,
    required String customEndpoint,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final endpointUrl = customEndpoint.isNotEmpty
        ? customEndpoint
        : 'https://api.openai.com/v1/chat/completions';
    final uri = Uri.parse(endpointUrl);
    final payload = {
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': 0.2,
    };

    final body = await _postJson(
      uri: uri,
      payload: payload,
      headers: {'Authorization': 'Bearer $apiKey'},
    );
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('OpenAI-compatible endpoint returned no choices.');
    }
    final msg = choices.first['message'] as Map<String, dynamic>?;
    final text = msg?['content']?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw Exception('OpenAI-compatible endpoint returned empty content.');
    }
    return text;
  }

  Future<String> _postJson({
    required Uri uri,
    required Map<String, dynamic> payload,
    Map<String, String> headers = const {},
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      headers.forEach(request.headers.set);
      request.write(jsonEncode(payload));
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: $responseBody');
      }
      return responseBody;
    } finally {
      client.close(force: true);
    }
  }
}

/// Grounded response from the AI Document Assistant with page citations.
class AiResponse {
  final String answer;
  final List<int> citedPages;

  const AiResponse({required this.answer, this.citedPages = const []});
}
