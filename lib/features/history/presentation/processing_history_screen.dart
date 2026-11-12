import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../editor/domain/tool_task_notifier.dart';
import '../../reader/domain/document_tabs_notifier.dart';
import '../../reader/domain/reader_notifier.dart';
import '../../reader/presentation/reader_screen.dart';

/// Non-obtrusive dedicated Processing History page for completed, active, and failed tool tasks.
class ProcessingHistoryScreen extends ConsumerWidget {
  const ProcessingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(toolTaskManagerProvider);
    final notifier = ref.read(toolTaskManagerProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBorder = isDark
        ? const Color(0xFF1E2430)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.history_rounded, size: 20),
            SizedBox(width: 8),
            Text(
              'Processing & Export History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          if (tasks.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Clear Completed'),
              onPressed: () => notifier.clearCompleted(),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 48,
                    color: textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No processing history yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Run any tool from the Tools Studio to track live progress and exports here.',
                    style: TextStyle(fontSize: 13, color: textSecondary),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _HistoryTaskCard(
                  task: task,
                  isDark: isDark,
                  cardBorder: cardBorder,
                );
              },
            ),
    );
  }
}

class _HistoryTaskCard extends ConsumerWidget {
  final ToolTask task;
  final bool isDark;
  final Color cardBorder;

  const _HistoryTaskCard({
    required this.task,
    required this.isDark,
    required this.cardBorder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (task.status) {
      case ToolTaskStatus.completed:
        statusColor = const Color(0xFF10B981); // Emerald Green
        statusText = 'Completed';
        statusIcon = Icons.check_circle_rounded;
        break;
      case ToolTaskStatus.running:
        statusColor = const Color(0xFFEAB308); // Amber / Yellow
        statusText = 'Running (${(task.progress * 100).toInt()}%)';
        statusIcon = Icons.sync_rounded;
        break;
      case ToolTaskStatus.error:
        statusColor = const Color(0xFFEF4444); // Crimson Red
        statusText = 'Failed';
        statusIcon = Icons.error_rounded;
        break;
      case ToolTaskStatus.idle:
        statusColor = Colors.grey;
        statusText = 'Queued';
        statusIcon = Icons.hourglass_empty_rounded;
        break;
    }

    final timeFormat = DateFormat('MMM d, h:mm a');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111622) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.status == ToolTaskStatus.completed
              ? statusColor.withAlpha(90)
              : cardBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF181D27)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(task.toolIcon, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.toolTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeFormat.format(task.startedAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withAlpha(120)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(task.statusMessage, style: const TextStyle(fontSize: 12)),
          if (task.outputPath != null &&
              File(task.outputPath!).existsSync()) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF181D27)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.file_present_rounded,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.outputPath!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.share_outlined, size: 14),
                  label: const Text('Export / Share'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () {
                    Share.shareXFiles([XFile(task.outputPath!)]);
                  },
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Open in Workspace'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () async {
                    final file = File(task.outputPath!);
                    if (!file.existsSync()) return;
                    final isDesktop = MediaQuery.of(context).size.width >= 800;
                    if (isDesktop) {
                      await ref
                          .read(documentTabsNotifierProvider.notifier)
                          .openFileFromPath(file.path);
                    } else {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReaderScreen(
                            params: ReaderNotifierParams(
                              id: file.path,
                              name: file.uri.pathSegments.last,
                              path: file.path,
                              initialPage: 1,
                              initialPageCount: 1,
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
