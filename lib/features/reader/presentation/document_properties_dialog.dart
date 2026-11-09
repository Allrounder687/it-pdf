import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/pdf_engine/pdf_metadata_service.dart';
import '../../../core/providers.dart';

/// Modal dialog providing ISO 32000 PDF document properties and metadata inspection.
class DocumentPropertiesDialog extends ConsumerStatefulWidget {
  final String documentPath;

  const DocumentPropertiesDialog({super.key, required this.documentPath});

  @override
  ConsumerState<DocumentPropertiesDialog> createState() =>
      _DocumentPropertiesDialogState();
}

class _DocumentPropertiesDialogState
    extends ConsumerState<DocumentPropertiesDialog> {
  PdfDocumentProperties? _properties;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    try {
      final service = ref.read(pdfMetadataServiceProvider);
      final props = await service.inspectDocument(widget.documentPath);
      if (mounted) {
        setState(() {
          _properties = props;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard(BuildContext context) {
    if (_properties == null) return;
    final p = _properties!;
    final sb = StringBuffer()
      ..writeln('File: ${p.fileName}')
      ..writeln('Path: ${p.filePath}')
      ..writeln('Size: ${p.formattedFileSize}')
      ..writeln('Pages: ${p.pageCount}')
      ..writeln('Page Dimensions: ${p.standardPageSizeName}')
      ..writeln('PDF Version: ${p.pdfVersion}')
      ..writeln('Title: ${p.title ?? "None"}')
      ..writeln('Author: ${p.author ?? "None"}')
      ..writeln('Subject: ${p.subject ?? "None"}')
      ..writeln('Keywords: ${p.keywords ?? "None"}')
      ..writeln('Creator: ${p.creator ?? "None"}')
      ..writeln('Producer: ${p.producer ?? "None"}')
      ..writeln('Created: ${p.creationDate ?? "Unknown"}')
      ..writeln('Modified: ${p.modificationDate ?? "Unknown"}')
      ..writeln('Encrypted: ${p.isEncrypted}')
      ..writeln('Attachments: ${p.attachmentCount}');

    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document properties copied to clipboard.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blueAccent),
          SizedBox(width: 10),
          Text(
            'Document Properties',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 440,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(
                  'Failed to load properties: $_error',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FILE & FORMAT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const Divider(),
                    _buildRow('File Name', _properties!.fileName),
                    _buildRow('File Path', _properties!.filePath),
                    _buildRow('File Size', _properties!.formattedFileSize),
                    _buildRow('Page Count', '${_properties!.pageCount}'),
                    _buildRow('Dimensions', _properties!.standardPageSizeName),
                    _buildRow('PDF Version', _properties!.pdfVersion),
                    _buildRow(
                      'Security',
                      _properties!.isEncrypted
                          ? 'Password Protected (Encrypted)'
                          : 'None (Unencrypted)',
                    ),
                    _buildRow(
                      'Attachments',
                      '${_properties!.attachmentCount} embedded file(s)',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'METADATA & ATTRIBUTES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const Divider(),
                    _buildRow('Title', _properties!.title ?? '—'),
                    _buildRow('Author', _properties!.author ?? '—'),
                    _buildRow('Subject', _properties!.subject ?? '—'),
                    _buildRow('Keywords', _properties!.keywords ?? '—'),
                    _buildRow('Application', _properties!.creator ?? '—'),
                    _buildRow('PDF Producer', _properties!.producer ?? '—'),
                    _buildRow(
                      'Created',
                      _properties!.creationDate != null
                          ? _properties!.creationDate!.toLocal().toString()
                          : '—',
                    ),
                    _buildRow(
                      'Modified',
                      _properties!.modificationDate != null
                          ? _properties!.modificationDate!.toLocal().toString()
                          : '—',
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        if (_properties != null)
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Details'),
            onPressed: () => _copyToClipboard(context),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
