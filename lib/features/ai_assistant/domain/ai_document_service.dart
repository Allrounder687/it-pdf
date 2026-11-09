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
}
