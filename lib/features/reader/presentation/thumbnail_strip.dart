import 'package:flutter/material.dart';

/// Horizontal thumbnail strip for rapid multi-page browsing in Reader.
class ThumbnailStrip extends StatelessWidget {
  final int pageCount;
  final int currentPage;
  final ValueChanged<int> onSelectPage;

  const ThumbnailStrip({
    super.key,
    required this.pageCount,
    required this.currentPage,
    required this.onSelectPage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 90,
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
              width: 52,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 24,
                    color: isSelected ? Colors.blueAccent : Colors.grey,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$pageNum',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.blueAccent : null,
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
