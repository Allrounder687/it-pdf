import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ToolCategory {
  all('All Tools', Icons.apps_rounded),
  organize('Organize & Pages', Icons.view_quilt_rounded),
  convert('Convert & Create', Icons.transform_rounded),
  optimize('Optimize & Stamp', Icons.auto_fix_high_rounded),
  security('Security & Sign', Icons.verified_user_rounded),
  ai('AI Assistant', Icons.auto_awesome_rounded);

  final String label;
  final IconData icon;
  const ToolCategory(this.label, this.icon);
}

/// Base contract for a standalone, modular PDF tool.
/// Each tool lives in its own dedicated file and manages its UI/execution flow.
abstract class PdfTool {
  const PdfTool();

  String get id;
  String get title;
  String get description;
  IconData get icon;
  Color get color;
  ToolCategory get category;
  String? get badge => null;
  List<String> get searchKeywords;

  Future<void> execute(BuildContext context, WidgetRef ref);
}

/// Parses comma-separated 1-based page numbers/ranges (e.g., "1-3, 5, 8-10").
List<int> parsePageRanges(String input, int maxPage) {
  final result = <int>[];
  final seen = <int>{};
  for (final rawPart in input.split(',')) {
    final part = rawPart.trim();
    if (part.isEmpty) continue;
    if (part.contains('-')) {
      final bounds = part.split('-');
      if (bounds.length != 2) continue;
      final start = int.tryParse(bounds[0].trim());
      final end = int.tryParse(bounds[1].trim());
      if (start == null || end == null || start > end) continue;
      for (int p = start; p <= end; p++) {
        if (p >= 1 && p <= maxPage && seen.add(p)) {
          result.add(p);
        }
      }
    } else {
      final p = int.tryParse(part);
      if (p != null && p >= 1 && p <= maxPage && seen.add(p)) {
        result.add(p);
      }
    }
  }
  return result;
}

/// Formats byte counts cleanly for studio telemetry cards.
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}
