import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Contextual search overlay bar with real-time occurrence counter and next/prev match jumping.
class ReaderSearchBar extends StatefulWidget {
  final PdfTextSearcher searcher;
  final VoidCallback onClose;

  const ReaderSearchBar({
    super.key,
    required this.searcher,
    required this.onClose,
  });

  @override
  State<ReaderSearchBar> createState() => _ReaderSearchBarState();
}

class _ReaderSearchBarState extends State<ReaderSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.searcher.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.searcher.removeListener(_onSearchChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _search(String query) {
    if (query.trim().isEmpty) {
      widget.searcher.resetTextSearch();
    } else {
      widget.searcher.startTextSearch(query.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalMatches = widget.searcher.matches.length;
    final currentIdx = widget.searcher.currentIndex;

    String matchText = '';
    if (_controller.text.isNotEmpty) {
      if (widget.searcher.isSearching) {
        matchText = 'Searching...';
      } else if (totalMatches == 0) {
        matchText = '0 matches';
      } else {
        matchText = '${(currentIdx ?? 0) + 1} of $totalMatches';
      }
    }

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search text in document...',
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: _search,
              ),
            ),
            if (matchText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  matchText,
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: 20),
              tooltip: 'Previous Match',
              onPressed: totalMatches > 0 ? () => widget.searcher.goToPrevMatch() : null,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              tooltip: 'Next Match',
              onPressed: totalMatches > 0 ? () => widget.searcher.goToNextMatch() : null,
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Close Search',
              onPressed: () {
                widget.searcher.resetTextSearch();
                widget.onClose();
              },
            ),
          ],
        ),
      ),
    );
  }
}
