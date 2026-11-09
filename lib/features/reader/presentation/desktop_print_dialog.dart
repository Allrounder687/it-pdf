import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../annotations/domain/annotation_notifier.dart';

enum PrintPageRange { all, current, custom }

/// Windows desktop print dialog with native spooling and lossless page extraction.
class DesktopPrintDialog extends ConsumerStatefulWidget {
  final String documentPath;
  final String documentName;
  final int currentPage;
  final int pageCount;

  const DesktopPrintDialog({
    super.key,
    required this.documentPath,
    required this.documentName,
    required this.currentPage,
    required this.pageCount,
  });

  @override
  ConsumerState<DesktopPrintDialog> createState() => _DesktopPrintDialogState();
}

class _DesktopPrintDialogState extends ConsumerState<DesktopPrintDialog> {
  PrintPageRange _range = PrintPageRange.all;
  final TextEditingController _customRangeController = TextEditingController();
  int _copies = 1;
  bool _isSpooling = false;
  String? _errorMessage;

  @override
  void dispose() {
    _customRangeController.dispose();
    super.dispose();
  }

  List<int> _parseCustomRange(String text) {
    final result = <int>{};
    final parts = text.split(',');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.contains('-')) {
        final rangeParts = trimmed.split('-');
        if (rangeParts.length == 2) {
          final start = int.tryParse(rangeParts[0].trim());
          final end = int.tryParse(rangeParts[1].trim());
          if (start != null && end != null && start <= end) {
            for (int p = start; p <= end; p++) {
              if (p >= 1 && p <= widget.pageCount) result.add(p);
            }
          }
        }
      } else {
        final p = int.tryParse(trimmed);
        if (p != null && p >= 1 && p <= widget.pageCount) {
          result.add(p);
        }
      }
    }
    final sorted = result.toList()..sort();
    return sorted;
  }

  Future<void> _handlePrint() async {
    setState(() {
      _isSpooling = true;
      _errorMessage = null;
    });

    try {
      String fileToPrint = widget.documentPath;
      List<int>? targetPages;

      if (_range == PrintPageRange.current) {
        targetPages = [widget.currentPage];
      } else if (_range == PrintPageRange.custom) {
        targetPages = _parseCustomRange(_customRangeController.text);
        if (targetPages.isEmpty) {
          setState(() {
            _isSpooling = false;
            _errorMessage = 'Please enter a valid page range (e.g. 1-3, 5).';
          });
          return;
        }
      }

      if (targetPages != null) {
        final tempDir = await Directory.systemTemp.createTemp('it_pdf_print_');
        final tempPath =
            '${tempDir.path}${Platform.pathSeparator}print_output.pdf';
        final pdfService = ref.read(syncfusionPdfServiceProvider);
        await pdfService.extractPages(
          sourcePath: widget.documentPath,
          pageNumbers: targetPages,
          outputPath: tempPath,
        );
        fileToPrint = tempPath;
      }

      final escapedPath = fileToPrint.replaceAll("'", "''");
      for (int i = 0; i < _copies; i++) {
        await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          "Start-Process -FilePath '$escapedPath' -Verb Print",
        ]);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSpooling = false;
          _errorMessage = 'Print dispatch failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.print_outlined, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Print: ${widget.documentName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Pages: ${widget.pageCount}  •  Current: ${widget.currentPage}',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Page Range',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            RadioListTile<PrintPageRange>(
              title: Text('All pages (1 - ${widget.pageCount})'),
              value: PrintPageRange.all,
              groupValue: _range,
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: _isSpooling
                  ? null
                  : (v) => setState(() => _range = v!),
            ),
            RadioListTile<PrintPageRange>(
              title: Text('Current page (${widget.currentPage})'),
              value: PrintPageRange.current,
              groupValue: _range,
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: _isSpooling
                  ? null
                  : (v) => setState(() => _range = v!),
            ),
            RadioListTile<PrintPageRange>(
              title: const Text('Custom range'),
              value: PrintPageRange.custom,
              groupValue: _range,
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: _isSpooling
                  ? null
                  : (v) => setState(() => _range = v!),
            ),
            if (_range == PrintPageRange.custom) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _customRangeController,
                enabled: !_isSpooling,
                decoration: InputDecoration(
                  hintText: 'e.g. 1-3, 5, 8-${widget.pageCount}',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Copies:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: (_isSpooling || _copies <= 1)
                      ? null
                      : () => setState(() => _copies--),
                ),
                Text(
                  ' $_copies ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: (_isSpooling || _copies >= 99)
                      ? null
                      : () => setState(() => _copies++),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            if (_isSpooling) ...[
              const SizedBox(height: 16),
              const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Spooling to Windows Print Queue...'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSpooling
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.print, size: 18),
          label: const Text('Print'),
          onPressed: _isSpooling ? null : _handlePrint,
        ),
      ],
    );
  }
}
