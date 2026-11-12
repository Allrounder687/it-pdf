import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../app/theme/app_theme.dart';
import '../../../../core/pdf_engine/advanced_pdf_operations.dart';
import '../../../../core/providers.dart';
import '../../../annotations/domain/annotation_notifier.dart';
import '../../../library/domain/library_notifier.dart';
import '../../../reader/domain/document_tabs_notifier.dart';
import 'pdf_tool_model.dart';

class WatermarkTool extends PdfTool {
  const WatermarkTool();

  @override
  String get id => 'watermark';

  @override
  String get title => 'Watermark Studio';

  @override
  String get description =>
      'Live preview & stamp diagonal or custom vector watermarks across pages.';

  @override
  IconData get icon => Icons.branding_watermark_outlined;

  @override
  Color get color => AppTheme.toolIndigo;

  @override
  ToolCategory get category => ToolCategory.optimize;

  @override
  String get badge => 'STUDIO';

  @override
  List<String> get searchKeywords => const [
    'watermark',
    'stamp',
    'confidential',
    'draft',
    'overlay',
    'brand',
  ];

  @override
  Future<void> execute(BuildContext context, WidgetRef ref) async {
    final filePicker = ref.read(filePickerServiceProvider);
    final path = await filePicker.pickPdfFile();
    if (path == null) return;

    final summary = await ref
        .read(syncfusionPdfServiceProvider)
        .inspectPdf(path);
    if (!context.mounted) return;
    if (summary.isEncrypted || summary.pageCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot watermark an encrypted or unreadable PDF.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _WatermarkStudioScreen(sourcePath: path, summary: summary),
      ),
    );
  }
}

enum _WatermarkScope { all, firstOnly, oddPages, custom }

class _WatermarkStudioScreen extends ConsumerStatefulWidget {
  final String sourcePath;
  final PdfFileSummary summary;

  const _WatermarkStudioScreen({
    required this.sourcePath,
    required this.summary,
  });

  @override
  ConsumerState<_WatermarkStudioScreen> createState() =>
      _WatermarkStudioScreenState();
}

class _WatermarkStudioScreenState
    extends ConsumerState<_WatermarkStudioScreen> {
  final TextEditingController _textController = TextEditingController(
    text: 'CONFIDENTIAL',
  );
  final TextEditingController _rangeController = TextEditingController();
  double _fontSize = 52;
  double _opacity = 0.25;
  double _angleDegrees = -45;
  Color _color = const Color(0xFFDC2626);
  _WatermarkScope _scope = _WatermarkScope.all;
  bool _isApplying = false;

  static const _swatches = [
    Color(0xFFDC2626),
    Color(0xFF475569),
    Color(0xFF1D4ED8),
    Color(0xFF059669),
    Color(0xFFD97706),
  ];

  static const _presets = ['CONFIDENTIAL', 'DRAFT', 'DO NOT COPY', 'APPROVED'];

  @override
  void dispose() {
    _textController.dispose();
    _rangeController.dispose();
    super.dispose();
  }

  List<int>? _resolveTargetPages() {
    final maxP = widget.summary.pageCount;
    switch (_scope) {
      case _WatermarkScope.all:
        return null;
      case _WatermarkScope.firstOnly:
        return [1];
      case _WatermarkScope.oddPages:
        return [for (int p = 1; p <= maxP; p += 2) p];
      case _WatermarkScope.custom:
        final parsed = parsePageRanges(_rangeController.text, maxP);
        return parsed.isEmpty ? null : parsed;
    }
  }

  Future<void> _applyWatermark() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter watermark text.')),
      );
      return;
    }

    final filePicker = ref.read(filePickerServiceProvider);
    final baseName = p.basenameWithoutExtension(widget.sourcePath);
    final dest = await filePicker.pickSaveFilePath(
      defaultFileName: '${baseName}_watermarked.pdf',
      dialogTitle: 'Save Watermarked PDF',
    );
    if (dest == null || !mounted) return;

    setState(() => _isApplying = true);
    try {
      await ref
          .read(syncfusionPdfServiceProvider)
          .addWatermark(
            sourcePath: widget.sourcePath,
            outputPath: dest,
            text: text,
            fontSize: _fontSize,
            opacity: _opacity,
            angleDegrees: _angleDegrees,
            color: _color,
            pageNumbers: _resolveTargetPages(),
          );

      final doc = await ref
          .read(libraryNotifierProvider.notifier)
          .importFileFromPath(dest);
      if (!mounted) return;
      if (doc != null) {
        ref.read(documentTabsNotifierProvider.notifier).openTab(doc);
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Watermark applied to ${p.basename(dest)}!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isApplying = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Watermark failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _textController.text.isEmpty
        ? 'PREVIEW'
        : _textController.text;

    return Scaffold(
      appBar: AppBar(title: const Text('Watermark Studio')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;
          final controls = _buildControls();
          final preview = _buildPreviewPane(text);

          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 5, child: controls),
                const VerticalDivider(width: 1),
                Expanded(flex: 4, child: preview),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 280, child: preview),
                const Divider(height: 1),
                controls,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviewPane(String text) {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : const Color(0xFFE2E8F0),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: AspectRatio(
          aspectRatio: 0.707,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Subtle mock lines simulating document body
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        height: 10,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      for (int i = 0; i < 8; i++) ...[
                        Container(
                          width: i == 7 ? 120 : double.infinity,
                          height: 6,
                          color: Colors.grey.shade200,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
                // Live watermark preview
                ClipRect(
                  child: Transform.rotate(
                    angle: _angleDegrees * math.pi / 180,
                    child: Opacity(
                      opacity: _opacity.clamp(0.05, 1.0),
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _color,
                          fontSize: (_fontSize * 0.42).clamp(10.0, 48.0),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Document: ${p.basename(widget.sourcePath)} (${widget.summary.pageCount} pages)',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _textController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Watermark Text',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _presets
                .map(
                  (preset) => ActionChip(
                    label: Text(preset, style: const TextStyle(fontSize: 11)),
                    onPressed: () => setState(() {
                      _textController.text = preset;
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),

          // Color Swatches
          Row(
            children: [
              const Text(
                'Color:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              for (final c in _swatches)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: c,
                      child: _color == c
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          Text('Font Size: ${_fontSize.round()} pt'),
          Slider(
            value: _fontSize,
            min: 20,
            max: 96,
            onChanged: (v) => setState(() => _fontSize = v),
          ),

          Text('Opacity: ${(_opacity * 100).round()}%'),
          Slider(
            value: _opacity,
            min: 0.08,
            max: 0.85,
            onChanged: (v) => setState(() => _opacity = v),
          ),

          Text('Rotation Angle: ${_angleDegrees.round()}°'),
          Slider(
            value: _angleDegrees,
            min: -75,
            max: 75,
            onChanged: (v) => setState(() => _angleDegrees = v),
          ),

          const SizedBox(height: 10),
          const Text(
            'Target Pages',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All Pages'),
                selected: _scope == _WatermarkScope.all,
                onSelected: (_) => setState(() => _scope = _WatermarkScope.all),
              ),
              ChoiceChip(
                label: const Text('First Page'),
                selected: _scope == _WatermarkScope.firstOnly,
                onSelected: (_) =>
                    setState(() => _scope = _WatermarkScope.firstOnly),
              ),
              ChoiceChip(
                label: const Text('Odd Pages'),
                selected: _scope == _WatermarkScope.oddPages,
                onSelected: (_) =>
                    setState(() => _scope = _WatermarkScope.oddPages),
              ),
              ChoiceChip(
                label: const Text('Custom Range'),
                selected: _scope == _WatermarkScope.custom,
                onSelected: (_) =>
                    setState(() => _scope = _WatermarkScope.custom),
              ),
            ],
          ),
          if (_scope == _WatermarkScope.custom) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _rangeController,
              decoration: const InputDecoration(
                labelText: 'Pages (e.g. 1-3, 6)',
                border: OutlineInputBorder(),
              ),
            ),
          ],

          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _isApplying ? null : _applyWatermark,
            icon: const Icon(Icons.branding_watermark_outlined),
            label: Text(
              _isApplying ? 'Applying Watermark...' : 'Stamp & Save PDF',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.toolIndigo,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
