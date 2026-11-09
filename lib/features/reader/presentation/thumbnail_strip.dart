import 'package:flutter/material.dart';
import '../../../core/pdf_engine/pdf_thumbnail_cache.dart';

/// Horizontal thumbnail strip for rapid multi-page browsing in Reader.
/// Displays cached, asynchronously rendered page thumbnails.
class ThumbnailStrip extends StatelessWidget {
  final String? documentPath;
  final int pageCount;
  final int currentPage;
  final ValueChanged<int> onSelectPage;

  const ThumbnailStrip({
    super.key,
    this.documentPath,
    required this.pageCount,
    required this.currentPage,
    required this.onSelectPage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2A) : Colors.white,
        border: const Border(top: BorderSide(color: Colors.black12)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: pageCount,
        itemBuilder: (context, index) {
          final pageNum = index + 1;
          final isSelected = pageNum == currentPage;

          return InkWell(
            onTap: () => onSelectPage(pageNum),
            child: Container(
              width: 58,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? Colors.blueAccent : Colors.grey.shade400,
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                      child: documentPath != null
                          ? PdfPageThumbnailView(
                              documentPath: documentPath!,
                              pageNumber: pageNum,
                              width: 58,
                              height: 70,
                              placeholder: Center(
                                child: Text(
                                  '$pageNum',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected ? Colors.blueAccent : Colors.grey,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.description_outlined,
                                size: 20,
                                color: isSelected ? Colors.blueAccent : Colors.grey,
                              ),
                            ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: isDark ? Colors.black26 : Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '$pageNum',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.blueAccent : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
