import 'package:flutter/material.dart';

/// Top application title bar for Windows desktop with command search pill and quick actions.
class DesktopTitleBar extends StatelessWidget {
  final String? activeDocumentName;
  final bool isDirty;
  final VoidCallback onOpenPdf;
  final VoidCallback onOpenCommandPalette;
  final VoidCallback onToggleTheme;
  final VoidCallback onShowShortcuts;

  const DesktopTitleBar({
    super.key,
    this.activeDocumentName,
    this.isDirty = false,
    required this.onOpenPdf,
    required this.onOpenCommandPalette,
    required this.onToggleTheme,
    required this.onShowShortcuts,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFCBD5E1);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          // App Branding
          const Icon(
            Icons.picture_as_pdf_rounded,
            color: Colors.blueAccent,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'IT PDF',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),

          if (activeDocumentName != null) ...[
            Text(
              '  —  $activeDocumentName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            if (isDirty) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],

          const Spacer(),

          // Spotlight Command Search Pill (Ctrl+K)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onOpenCommandPalette,
            child: Container(
              width: 280,
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Search commands & tools...',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Ctrl+K',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Quick Actions
          IconButton(
            icon: const Icon(Icons.file_open_outlined, size: 17),
            tooltip: 'Open PDF Document (Ctrl+O)',
            visualDensity: VisualDensity.compact,
            onPressed: onOpenPdf,
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 17,
            ),
            tooltip: 'Toggle Theme',
            visualDensity: VisualDensity.compact,
            onPressed: onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_outlined, size: 17),
            tooltip: 'Keyboard Shortcuts Reference',
            visualDensity: VisualDensity.compact,
            onPressed: onShowShortcuts,
          ),
        ],
      ),
    );
  }
}
