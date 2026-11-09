import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/platform/file_picker_service.dart';
import '../../../core/providers.dart';
import '../../library/domain/library_notifier.dart';
import '../../page_organizer/domain/page_organizer_notifier.dart';
import '../../signatures/presentation/signature_pad_dialog.dart';

/// Tools Screen providing conversion, merging, creation and signature utilities.
class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filePicker = ref.watch(filePickerServiceProvider);
    final organizerService = ref.watch(pageOrganizerServiceProvider);
    final libraryNotifier = ref.read(libraryNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PDF Tools',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ToolCard(
            icon: Icons.image_outlined,
            title: 'Images to PDF',
            description:
                'Convert photos, scans and gallery images into a single clean PDF document.',
            color: Colors.blueAccent,
            onTap: () => _handleImagesToPdf(
              context,
              filePicker,
              organizerService,
              libraryNotifier,
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.call_merge,
            title: 'Merge PDF Documents',
            description:
                'Combine multiple PDF files into one continuous compiled document.',
            color: Colors.teal,
            onTap: () => _handleMergePdfs(
              context,
              filePicker,
              organizerService,
              libraryNotifier,
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.note_add_outlined,
            title: 'Create Blank PDF',
            description:
                'Generate a new blank notebook or drafting document ready for annotation.',
            color: Colors.purpleAccent,
            onTap: () => _handleCreateBlankPdf(
              context,
              filePicker,
              organizerService,
              libraryNotifier,
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.draw_outlined,
            title: 'Handwritten Signatures',
            description:
                'Draw, save and manage custom vector signatures for rapid document signing.',
            color: Colors.orangeAccent,
            onTap: () => _handleSignaturePad(context),
          ),
        ],
      ),
    );
  }

  Future<void> _handleImagesToPdf(
    BuildContext context,
    FilePickerService filePicker,
    dynamic organizerService,
    LibraryNotifier libraryNotifier,
  ) async {
    final images = await filePicker.pickImageFiles();
    if (images.isEmpty) return;

    final dest = await filePicker.getSaveDestinationPath(
      defaultFileName: 'converted_images.pdf',
    );
    if (dest == null) return;

    try {
      await organizerService.convertImagesToPdf(
        imagePaths: images,
        outputPath: dest,
      );
      final doc = await libraryNotifier.importFileFromPath(dest);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully created ${doc?.name ?? "PDF"}!'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Conversion failed: $e')));
      }
    }
  }

  Future<void> _handleMergePdfs(
    BuildContext context,
    FilePickerService filePicker,
    dynamic organizerService,
    LibraryNotifier libraryNotifier,
  ) async {
    final files = await filePicker.pickMultiplePdfFiles();
    if (files.length < 2) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least 2 PDF files to merge.'),
          ),
        );
      }
      return;
    }

    final dest = await filePicker.getSaveDestinationPath(
      defaultFileName: 'merged_document.pdf',
    );
    if (dest == null) return;

    try {
      await organizerService.mergePdfs(sourcePaths: files, outputPath: dest);
      final doc = await libraryNotifier.importFileFromPath(dest);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully merged into ${doc?.name ?? "PDF"}!'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Merge failed: $e')));
      }
    }
  }

  Future<void> _handleCreateBlankPdf(
    BuildContext context,
    FilePickerService filePicker,
    dynamic organizerService,
    LibraryNotifier libraryNotifier,
  ) async {
    final controller = TextEditingController(text: 'New Document');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Blank Document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Document Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final dest = await filePicker.getSaveDestinationPath(
      defaultFileName: '${controller.text.trim()}.pdf',
    );
    if (dest == null) return;

    try {
      await organizerService.createBlankDocument(
        title: controller.text.trim(),
        outputPath: dest,
      );
      await libraryNotifier.importFileFromPath(dest);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created ${controller.text.trim()}!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Creation failed: $e')));
      }
    }
  }

  Future<void> _handleSignaturePad(BuildContext context) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (ctx) => const SignaturePadDialog(),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signature profile saved!')));
    }
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
