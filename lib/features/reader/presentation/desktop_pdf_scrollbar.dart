import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// A precision desktop scrollbar designed specifically for [PdfViewerController].
///
/// Features:
/// - Real-time synchronization with document size, visible rectangle, and zoom.
/// - Dynamic thumb sizing proportional to visible document area.
/// - Fluid thumb dragging and direct track click-to-jump.
/// - Adaptive hover states with width expansion and contrast-aware colors.
/// - Floating page pill indicator ("Page X of Y") during hover and drag.
/// - Automatic hiding when the document fits inside the viewport.
class DesktopPdfScrollbar extends StatefulWidget {
  final PdfViewerController controller;
  final Axis orientation;
  final int pageCount;
  final int currentPage;
  final double trackMargin;

  const DesktopPdfScrollbar({
    super.key,
    required this.controller,
    this.orientation = Axis.vertical,
    this.pageCount = 0,
    this.currentPage = 1,
    this.trackMargin = 2.0,
  });

  @override
  State<DesktopPdfScrollbar> createState() => _DesktopPdfScrollbarState();
}

class _DesktopPdfScrollbarState extends State<DesktopPdfScrollbar> {
  bool _isHovered = false;
  bool _isDragging = false;
  double _dragStartPos = 0.0;
  double _dragStartProgress = 0.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void didUpdateWidget(DesktopPdfScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerUpdate);
      widget.controller.addListener(_onControllerUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _scrollToProgress(double progress, {required bool isVertical}) {
    if (!widget.controller.isReady) return;

    final docSize = widget.controller.documentSize;
    final visible = widget.controller.visibleRect;
    final center = widget.controller.centerPosition;

    if (isVertical) {
      final maxScroll = docSize.height - visible.height;
      if (maxScroll <= 0) return;
      final targetDocY = progress * maxScroll + (visible.height / 2);
      final targetMatrix = widget.controller.calcMatrixFor(
        Offset(center.dx, targetDocY),
      );
      widget.controller.value = widget.controller.makeMatrixInSafeRange(
        targetMatrix,
      );
    } else {
      final maxScroll = docSize.width - visible.width;
      if (maxScroll <= 0) return;
      final targetDocX = progress * maxScroll + (visible.width / 2);
      final targetMatrix = widget.controller.calcMatrixFor(
        Offset(targetDocX, center.dy),
      );
      widget.controller.value = widget.controller.makeMatrixInSafeRange(
        targetMatrix,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isReady) {
      return const SizedBox.shrink();
    }

    final isVertical = widget.orientation == Axis.vertical;
    final docSize = widget.controller.documentSize;
    final visible = widget.controller.visibleRect;

    final docTotal = isVertical ? docSize.height : docSize.width;
    final viewSize = isVertical ? visible.height : visible.width;

    // Hide if content fits without scrolling
    if (docTotal <= viewSize + 1.0 || docTotal <= 0 || viewSize <= 0) {
      return const SizedBox.shrink();
    }

    final maxScroll = math.max(1.0, docTotal - viewSize);
    final currentScroll = isVertical ? visible.top : visible.left;
    final scrollProgress = (currentScroll / maxScroll).clamp(0.0, 1.0);
    final visibleRatio = (viewSize / docTotal).clamp(0.03, 1.0);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackLength = isVertical
            ? constraints.maxHeight
            : constraints.maxWidth;
        if (trackLength <= 0) return const SizedBox.shrink();

        final thumbLength = (visibleRatio * trackLength)
            .clamp(36.0, math.max(36.0, trackLength - 8.0))
            .toDouble();
        final travel = math.max(1.0, trackLength - thumbLength);
        final thumbOffset = (scrollProgress * travel)
            .clamp(0.0, travel)
            .toDouble();

        final active = _isHovered || _isDragging;
        final trackThickness = active ? 14.0 : 8.0;
        final thumbThickness = active ? 10.0 : 6.0;

        // Visual Colors
        final trackBg = active
            ? (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05))
            : Colors.transparent;

        final thumbColor = isDark
            ? (_isDragging
                  ? Colors.white.withValues(alpha: 0.80)
                  : (_isHovered
                        ? Colors.white.withValues(alpha: 0.60)
                        : Colors.white.withValues(alpha: 0.35)))
            : (_isDragging
                  ? Colors.black.withValues(alpha: 0.80)
                  : (_isHovered
                        ? Colors.black.withValues(alpha: 0.60)
                        : Colors.black.withValues(alpha: 0.35)));

        final displayPage = widget.controller.pageNumber ?? widget.currentPage;
        final totalPages = widget.pageCount > 0
            ? widget.pageCount
            : widget.controller.document.pages.length;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            width: isVertical ? trackThickness : null,
            height: isVertical ? null : trackThickness,
            decoration: BoxDecoration(
              color: trackBg,
              borderRadius: BorderRadius.circular(trackThickness / 2),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Track click detector
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final tapPos = isVertical
                          ? details.localPosition.dy
                          : details.localPosition.dx;
                      final targetProgress =
                          ((tapPos - thumbLength / 2) / travel).clamp(0.0, 1.0);
                      _scrollToProgress(targetProgress, isVertical: isVertical);
                    },
                  ),
                ),

                // Thumb Draggable
                Positioned(
                  top: isVertical
                      ? thumbOffset
                      : (trackThickness - thumbThickness) / 2.0,
                  left: isVertical
                      ? (trackThickness - thumbThickness) / 2.0
                      : thumbOffset,
                  width: isVertical ? thumbThickness : thumbLength,
                  height: isVertical ? thumbLength : thumbThickness,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: isVertical
                        ? (details) {
                            setState(() {
                              _isDragging = true;
                              _dragStartPos = details.globalPosition.dy;
                              _dragStartProgress = scrollProgress;
                            });
                          }
                        : null,
                    onVerticalDragUpdate: isVertical
                        ? (details) {
                            if (travel <= 0) return;
                            final delta =
                                details.globalPosition.dy - _dragStartPos;
                            final deltaProgress = delta / travel;
                            final targetProgress =
                                (_dragStartProgress + deltaProgress).clamp(
                                  0.0,
                                  1.0,
                                );
                            _scrollToProgress(targetProgress, isVertical: true);
                          }
                        : null,
                    onVerticalDragEnd: isVertical
                        ? (_) => setState(() => _isDragging = false)
                        : null,
                    onHorizontalDragStart: !isVertical
                        ? (details) {
                            setState(() {
                              _isDragging = true;
                              _dragStartPos = details.globalPosition.dx;
                              _dragStartProgress = scrollProgress;
                            });
                          }
                        : null,
                    onHorizontalDragUpdate: !isVertical
                        ? (details) {
                            if (travel <= 0) return;
                            final delta =
                                details.globalPosition.dx - _dragStartPos;
                            final deltaProgress = delta / travel;
                            final targetProgress =
                                (_dragStartProgress + deltaProgress).clamp(
                                  0.0,
                                  1.0,
                                );
                            _scrollToProgress(
                              targetProgress,
                              isVertical: false,
                            );
                          }
                        : null,
                    onHorizontalDragEnd: !isVertical
                        ? (_) => setState(() => _isDragging = false)
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: thumbColor,
                        borderRadius: BorderRadius.circular(thumbThickness / 2),
                      ),
                    ),
                  ),
                ),

                // Page Indicator Tooltip Badge (Vertical only, displayed during hover or drag)
                if (isVertical && active && totalPages > 1)
                  Positioned(
                    top: (thumbOffset + (thumbLength / 2) - 14.0)
                        .clamp(8.0, trackLength - 36.0)
                        .toDouble(),
                    right: trackThickness + 10.0,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: active ? 1.0 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E2124)
                                : Colors.black87,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Page $displayPage of $totalPages',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
