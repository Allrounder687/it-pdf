import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../logging/app_logger.dart';

/// Lightweight cancellation handle wrapping a native pdfrx token once created.
class ThumbnailCancelHandle {
  bool _isCanceled = false;
  PdfPageRenderCancellationToken? _nativeToken;

  bool get isCanceled => _isCanceled;

  void bindNative(PdfPageRenderCancellationToken token) {
    _nativeToken = token;
    if (_isCanceled) {
      token.cancel();
    }
  }

  void cancel() {
    _isCanceled = true;
    _nativeToken?.cancel();
  }
}

/// LRU-cached asynchronous page thumbnail rendering service.
/// Uses PDFium to render vector-accurate preview thumbnails with full-page scaling.
class PdfThumbnailCache {
  static final PdfThumbnailCache instance = PdfThumbnailCache._internal();
  PdfThumbnailCache._internal();

  factory PdfThumbnailCache() => instance;

  static const int _maxCacheEntries = 140;

  // Key: "$filePath:$pageNumber:$targetWidth" -> PNG bytes
  final LinkedHashMap<String, Uint8List> _memoryCache = LinkedHashMap();
  final Map<String, Future<Uint8List?>> _inFlightRenders = {};

  String _cacheKey(String path, int pageNumber, int width) =>
      '$path:$pageNumber:$width';

  /// Get cached thumbnail bytes if present in memory.
  Uint8List? getCachedThumbnail(
    String path,
    int pageNumber, {
    int width = 180,
  }) {
    final key = _cacheKey(path, pageNumber, width);
    if (_memoryCache.containsKey(key)) {
      final value = _memoryCache.remove(key)!;
      _memoryCache[key] = value;
      return value;
    }
    return null;
  }

  /// Asynchronously render thumbnail for a specific page.
  Future<Uint8List?> renderThumbnail({
    required String path,
    required int pageNumber, // 1-based page number
    int width = 180,
    ThumbnailCancelHandle? cancelHandle,
  }) async {
    final key = _cacheKey(path, pageNumber, width);

    if (_memoryCache.containsKey(key)) {
      final value = _memoryCache.remove(key)!;
      _memoryCache[key] = value;
      return value;
    }

    if (_inFlightRenders.containsKey(key)) {
      return _inFlightRenders[key];
    }

    final future = _doRender(
      path: path,
      pageNumber: pageNumber,
      width: width,
      cancelHandle: cancelHandle,
    );

    _inFlightRenders[key] = future;

    try {
      final bytes = await future;
      if (bytes != null) {
        _putInCache(key, bytes);
      }
      return bytes;
    } finally {
      unawaited(_inFlightRenders.remove(key));
    }
  }

  Future<Uint8List?> _doRender({
    required String path,
    required int pageNumber,
    required int width,
    ThumbnailCancelHandle? cancelHandle,
  }) async {
    final file = File(path);
    if (!await file.exists()) return null;

    PdfDocument? document;
    PdfImage? pdfImage;
    try {
      document = await PdfDocument.openFile(path);
      if (pageNumber < 1 || pageNumber > document.pages.length) return null;
      if (cancelHandle?.isCanceled ?? false) return null;

      final page = document.pages[pageNumber - 1];
      final nativeToken = page.createCancellationToken();
      cancelHandle?.bindNative(nativeToken);

      final aspectRatio = page.width > 0 ? (page.height / page.width) : 1.414;
      final targetW = width.clamp(80, 600);
      final targetH = (targetW * aspectRatio).round().clamp(80, 800);

      // CRITICAL: Pass fullWidth & fullHeight so PDFium scales the page to fill the thumbnail!
      pdfImage = await page.render(
        width: targetW,
        height: targetH,
        fullWidth: targetW.toDouble(),
        fullHeight: targetH.toDouble(),
        backgroundColor: 0xffffffff,
        cancellationToken: nativeToken,
      );

      if (pdfImage == null) return null;

      final uiImage = await pdfImage.createImage();
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();

      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      AppLogger.warn('Thumbnail render error for $path (p. $pageNumber): $e');
      return null;
    } finally {
      pdfImage?.dispose();
      await document?.dispose();
    }
  }

  void _putInCache(String key, Uint8List bytes) {
    if (_memoryCache.containsKey(key)) {
      _memoryCache.remove(key);
    } else if (_memoryCache.length >= _maxCacheEntries) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[key] = bytes;
  }

  /// Invalidate all thumbnails for a specific document.
  void invalidateDocument(String path) {
    final keysToRemove = _memoryCache.keys
        .where((k) => k.startsWith('$path:'))
        .toList();
    for (final k in keysToRemove) {
      _memoryCache.remove(k);
    }
  }

  /// Clear complete cache.
  void clear() {
    _memoryCache.clear();
    _inFlightRenders.clear();
  }
}

/// Widget that displays an asynchronously rendered page thumbnail with caching.
class PdfPageThumbnailView extends StatefulWidget {
  final String documentPath;
  final int pageNumber;
  final int rotationDegrees;
  final double width;
  final double height;
  final Widget? placeholder;

  const PdfPageThumbnailView({
    super.key,
    required this.documentPath,
    required this.pageNumber,
    this.rotationDegrees = 0,
    this.width = 140,
    this.height = 190,
    this.placeholder,
  });

  @override
  State<PdfPageThumbnailView> createState() => _PdfPageThumbnailViewState();
}

class _PdfPageThumbnailViewState extends State<PdfPageThumbnailView> {
  Uint8List? _bytes;
  bool _isLoading = true;
  ThumbnailCancelHandle? _cancelHandle;

  int get _renderWidth => (widget.width * 2).round().clamp(140, 480);

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant PdfPageThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentPath != widget.documentPath ||
        oldWidget.pageNumber != widget.pageNumber) {
      _cancelHandle?.cancel();
      _loadThumbnail();
    }
  }

  @override
  void dispose() {
    _cancelHandle?.cancel();
    super.dispose();
  }

  Future<void> _loadThumbnail() async {
    final cached = PdfThumbnailCache.instance.getCachedThumbnail(
      widget.documentPath,
      widget.pageNumber,
      width: _renderWidth,
    );

    if (cached != null) {
      if (mounted) {
        setState(() {
          _bytes = cached;
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }
    final handle = ThumbnailCancelHandle();
    _cancelHandle = handle;

    final bytes = await PdfThumbnailCache.instance.renderThumbnail(
      path: widget.documentPath,
      pageNumber: widget.pageNumber,
      width: _renderWidth,
      cancelHandle: handle,
    );

    if (mounted && !handle.isCanceled) {
      setState(() {
        _bytes = bytes;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_bytes != null) {
      child = Image.memory(
        _bytes!,
        fit: BoxFit.contain,
        width: widget.width,
        height: widget.height,
      );
    } else if (_isLoading) {
      child =
          widget.placeholder ??
          Container(
            color: Colors.black12,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
    } else {
      child = Container(
        color: Colors.black12,
        child: const Center(
          child: Icon(Icons.picture_as_pdf, color: Colors.grey, size: 36),
        ),
      );
    }

    if (widget.rotationDegrees != 0) {
      return RotatedBox(
        quarterTurns: (widget.rotationDegrees / 90).round(),
        child: child,
      );
    }
    return child;
  }
}
