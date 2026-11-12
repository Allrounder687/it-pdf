import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../app/theme/app_theme.dart';
import '../../../../core/pdf_engine/advanced_pdf_operations.dart';
import '../../../../core/pdf_engine/pdf_thumbnail_cache.dart';
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
      'Drag, rotate & resize watermarks directly on your PDF page or tile grids.';

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
    'drag',
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
  double _fontSize = 48;
  double _opacity = 0.35;
  double _angleDegrees = -35;
  double _xFraction = 0.5;
  double _yFraction = 0.5;
  bool _tiled = false;
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
    final dest = await filePicker.resolveWritableOutputPath(
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
            xFraction: _xFraction,
            yFraction: _yFraction,
            tiled: _tiled,
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
      appBar: AppBar(
        title: const Text('Watermark Studio'),
        actions: [
          if (!_tiled)
            TextButton.icon(
              onPressed: () => setState(() {
                _xFraction = 0.5;
                _yFraction = 0.5;
                _angleDegrees = -35;
              }),
              icon: const Icon(Icons.center_focus_strong_rounded, size: 16),
              label: const Text('Center'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;
          final controls = _buildControls();
          final preview = _buildInteractivePreviewPane(text);

          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 4, child: controls),
                const VerticalDivider(width: 1),
                Expanded(flex: 5, child: preview),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 360, child: preview),
                const Divider(height: 1),
                controls,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInteractivePreviewPane(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              const SizedBox(width: 6),
              Text(
                _tiled
                    ? 'Tiled repeat grid across entire page'
                    : 'Drag watermark directly on page • Drag corner handle to rotate & scale',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 0.707,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final pageW = box.maxWidth;
                    final pageH = box.maxHeight;
                    final scaledFont = (_fontSize * (pageW / 595.0)).clamp(
                      10.0,
                      72.0,
                    );

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Live actual Page 1 PDF background
                            PdfPageThumbnailView(
                              documentPath: widget.sourcePath,
                              pageNumber: 1,
                              width: pageW.clamp(180, 460),
                              height: pageH.clamp(220, 650),
                            ),

                            // Direct Interactive Watermark Overlay (clipped cleanly to PAGE bounds, never text bounds!)
                            if (_tiled)
                              _buildTiledPreview(text, scaledFont)
                            else
                              _buildDraggableWatermark(
                                text: text,
                                scaledFont: scaledFont,
                                pageW: pageW,
                                pageH: pageH,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTiledPreview(String text, double scaledFont) {
    return IgnorePointer(
      child: Opacity(
        opacity: _opacity.clamp(0.05, 1.0),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
          ),
          itemCount: 12,
          itemBuilder: (_, _) => Center(
            child: Transform.rotate(
              angle: _angleDegrees * math.pi / 180,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  style: TextStyle(
                    color: _color,
                    fontSize: scaledFont * 0.72,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableWatermark({
    required String text,
    required double scaledFont,
    required double pageW,
    required double pageH,
  }) {
    final cx = pageW * _xFraction;
    final cy = pageH * _yFraction;

    return Stack(
      children: [
        Positioned(
          left: cx,
          top: cy,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: Transform.rotate(
              angle: _angleDegrees * math.pi / 180,
              child: GestureDetector(
                onPanUpdate: (details) {
                  // Convert rotated/local screen delta back to page coordinates
                  final rad = _angleDegrees * math.pi / 180;
                  final dxPage =
                      details.delta.dx * math.cos(rad) -
                      details.delta.dy * math.sin(rad);
                  final dyPage =
                      details.delta.dx * math.sin(rad) +
                      details.delta.dy * math.cos(rad);
                  setState(() {
                    _xFraction = ((_xFraction * pageW + dxPage) / pageW).clamp(
                      0.08,
                      0.92,
                    );
                    _yFraction = ((_yFraction * pageH + dyPage) / pageH).clamp(
                      0.08,
                      0.92,
                    );
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTheme.toolIndigo.withValues(alpha: 0.75),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    color: AppTheme.toolIndigo.withValues(alpha: 0.04),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: _opacity.clamp(0.05, 1.0),
                        child: Text(
                          text,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            color: _color,
                            fontSize: scaledFont,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Direct Corner Handle for Rotation & Resize without sliders!
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          setState(() {
                            _angleDegrees =
                                (_angleDegrees + details.delta.dy * 0.6).clamp(
                                  -90.0,
                                  90.0,
                                );
                            _fontSize = (_fontSize + details.delta.dx * 0.35)
                                .clamp(16.0, 110.0);
                          });
                        },
                        child: Tooltip(
                          message:
                              'Drag up/down to rotate • left/right to resize',
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: AppTheme.toolIndigo,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.open_with_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
          const SizedBox(height: 14),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Tile Across Entire Page',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Disable to freely drag & position anywhere on the page',
              style: TextStyle(fontSize: 11.5),
            ),
            value: _tiled,
            onChanged: (v) => setState(() => _tiled = v),
          ),
          const SizedBox(height: 10),

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
            min: 16,
            max: 110,
            onChanged: (v) => setState(() => _fontSize = v),
          ),

          Text('Opacity: ${(_opacity * 100).round()}%'),
          Slider(
            value: _opacity,
            min: 0.08,
            max: 0.90,
            onChanged: (v) => setState(() => _opacity = v),
          ),

          Text('Rotation Angle: ${_angleDegrees.round()}°'),
          Slider(
            value: _angleDegrees,
            min: -90,
            max: 90,
            onChanged: (v) => setState(() => _angleDegrees = v),
          ),

          if (!_tiled)
            Text(
              'Position: X ${(100 * _xFraction).round()}% • Y ${(100 * _yFraction).round()}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

          const SizedBox(height: 12),
          const Text(
            'Target Pages',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
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
