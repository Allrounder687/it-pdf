import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/pdf_engine/pdf_metadata_service.dart';
import '../../../core/pdf_engine/pdf_thumbnail_cache.dart';
import '../../../core/providers.dart';
import 'outline_drawer.dart';

enum NavPanelTab { pages, outline, bookmarks, attachments }

class UserBookmark {
  final String id;
  final int pageNumber;
  final String label;

  const UserBookmark({
    required this.id,
    required this.pageNumber,
    required this.label,
  });
}

/// Left docked navigation panel for desktop reader (Pages, Outline, Bookmarks, Attachments).
class DesktopNavigationPanel extends ConsumerStatefulWidget {
  final String documentPath;
  final int pageCount;
  final int currentPage;
  final List<OutlineItem> outline;
  final ValueChanged<int> onJumpToPage;
  final ValueChanged<OutlineItem> onSelectOutline;
  final VoidCallback onClose;

  const DesktopNavigationPanel({
    super.key,
    required this.documentPath,
    required this.pageCount,
    required this.currentPage,
    required this.outline,
    required this.onJumpToPage,
    required this.onSelectOutline,
    required this.onClose,
  });

  @override
  ConsumerState<DesktopNavigationPanel> createState() =>
      _DesktopNavigationPanelState();
}

class _DesktopNavigationPanelState
    extends ConsumerState<DesktopNavigationPanel> {
  NavPanelTab _activeTab = NavPanelTab.pages;
  final List<UserBookmark> _userBookmarks = [];
  List<PdfAttachmentInfo>? _attachments;
  bool _loadingAttachments = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadAttachments() async {
    if (_attachments != null || _loadingAttachments) return;
    setState(() => _loadingAttachments = true);
    try {
      final service = ref.read(pdfMetadataServiceProvider);
      final atts = await service.extractAttachments(widget.documentPath);
      if (mounted) {
        setState(() {
          _attachments = atts;
          _loadingAttachments = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _attachments = const [];
          _loadingAttachments = false;
        });
      }
    }
  }

  void _addUserBookmark() {
    final cur = widget.currentPage;
    if (_userBookmarks.any((b) => b.pageNumber == cur)) return;
    setState(() {
      _userBookmarks.add(
        UserBookmark(
          id: '${DateTime.now().millisecondsSinceEpoch}',
          pageNumber: cur,
          label: 'Page $cur Bookmark',
        ),
      );
    });
  }

  Future<void> _exportAttachment(PdfAttachmentInfo attachment) async {
    final picker = ref.read(filePickerServiceProvider);
    final targetPath = await picker.pickSaveFilePath(
      dialogTitle: 'Export Attachment',
      defaultFileName: attachment.fileName,
      initialBytes: attachment.data,
    );
    if (targetPath != null) {
      final service = ref.read(pdfMetadataServiceProvider);
      final success = await service.exportAttachment(
        attachment: attachment,
        targetPath: targetPath,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Attachment exported to $targetPath'
                  : 'Failed to export attachment.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF161F2E) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? const Color(0xFF263346)
        : const Color(0xFFE2E8F0);

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        children: [
          // Header Tab Strip
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: [
                _buildTabButton(
                  tab: NavPanelTab.pages,
                  icon: Icons.grid_view_rounded,
                  tooltip: 'Page Thumbnails',
                ),
                _buildTabButton(
                  tab: NavPanelTab.outline,
                  icon: Icons.toc_rounded,
                  tooltip: 'Table of Contents',
                ),
                _buildTabButton(
                  tab: NavPanelTab.bookmarks,
                  icon: Icons.bookmark_border_rounded,
                  tooltip: 'Bookmarks',
                ),
                _buildTabButton(
                  tab: NavPanelTab.attachments,
                  icon: Icons.attach_file_rounded,
                  tooltip: 'Attachments',
                  onSelect: _loadAttachments,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  tooltip: 'Close Navigation Panel',
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: switch (_activeTab) {
              NavPanelTab.pages => _buildPagesView(isDark),
              NavPanelTab.outline => _buildOutlineView(isDark),
              NavPanelTab.bookmarks => _buildBookmarksView(isDark),
              NavPanelTab.attachments => _buildAttachmentsView(isDark),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required NavPanelTab tab,
    required IconData icon,
    required String tooltip,
    VoidCallback? onSelect,
  }) {
    final isActive = _activeTab == tab;
    return IconButton(
      icon: Icon(
        icon,
        size: 19,
        color: isActive ? Colors.blueAccent : Colors.grey,
      ),
      tooltip: tooltip,
      onPressed: () {
        setState(() => _activeTab = tab);
        onSelect?.call();
      },
    );
  }

  Widget _buildPagesView(bool isDark) {
    return widget.pageCount <= 0
        ? const Center(child: Text('No pages found.'))
        : GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
            itemCount: widget.pageCount,
            itemBuilder: (context, index) {
              final pageNum = index + 1;
              final isSelected = pageNum == widget.currentPage;

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => widget.onJumpToPage(pageNum),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Colors.blueAccent
                          : (isDark ? Colors.white12 : Colors.black12),
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: Colors.blueAccent.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(7),
                          ),
                          child: PdfPageThumbnailView(
                            documentPath: widget.documentPath,
                            pageNumber: pageNum,
                            width: 120,
                            height: 150,
                            placeholder: Center(
                              child: Text(
                                '$pageNum',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.blueAccent
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '$pageNum',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? Colors.blueAccent : null,
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

  Widget _buildOutlineView(bool isDark) {
    if (widget.outline.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.toc_outlined, size: 36, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'No outline or bookmarks found in this document.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.outline.length,
      itemBuilder: (context, index) {
        final item = widget.outline[index];
        final isActive = item.targetPage == widget.currentPage;

        return InkWell(
          onTap: () => widget.onSelectOutline(item),
          child: Container(
            padding: EdgeInsets.only(
              left: 12.0 + (item.level * 14.0),
              right: 12,
              top: 7,
              bottom: 7,
            ),
            color: isActive
                ? Colors.blueAccent.withValues(alpha: 0.12)
                : Colors.transparent,
            child: Row(
              children: [
                Icon(
                  item.level == 0
                      ? Icons.bookmark_outline_rounded
                      : Icons.subdirectory_arrow_right_rounded,
                  size: 15,
                  color: isActive ? Colors.blueAccent : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive ? Colors.blueAccent : null,
                    ),
                  ),
                ),
                if (item.targetPage != null)
                  Text(
                    '${item.targetPage}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive ? Colors.blueAccent : Colors.grey,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Unresolved',
                      style: TextStyle(fontSize: 9, color: Colors.amber),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookmarksView(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.bookmark_add_outlined, size: 16),
            label: Text('Bookmark Page ${widget.currentPage}'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(36),
            ),
            onPressed: _addUserBookmark,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _userBookmarks.isEmpty
              ? const Center(
                  child: Text(
                    'No bookmarks added yet.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _userBookmarks.length,
                  itemBuilder: (context, index) {
                    final bm = _userBookmarks[index];
                    final isActive = bm.pageNumber == widget.currentPage;

                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.bookmark_rounded,
                        size: 18,
                        color: isActive ? Colors.blueAccent : Colors.grey,
                      ),
                      title: Text(
                        bm.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text('Page ${bm.pageNumber}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        onPressed: () {
                          setState(() => _userBookmarks.removeAt(index));
                        },
                      ),
                      onTap: () => widget.onJumpToPage(bm.pageNumber),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAttachmentsView(bool isDark) {
    if (_loadingAttachments) {
      return const Center(child: CircularProgressIndicator());
    }

    final atts = _attachments ?? [];
    if (atts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.attachment_outlined, size: 36, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'No embedded attachments found in this PDF.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: atts.length,
      itemBuilder: (context, index) {
        final a = atts[index];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.insert_drive_file_outlined, size: 20),
          title: Text(
            a.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          subtitle: Text('${a.formattedSize} • ${a.mimeType ?? "Binary"}'),
          trailing: IconButton(
            icon: const Icon(Icons.download_rounded, size: 18),
            tooltip: 'Export Attachment',
            onPressed: () => _exportAttachment(a),
          ),
        );
      },
    );
  }
}
