import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

/// Top application title bar for Windows desktop with Back to Home navigation,
/// document title, command search pill, and quick global actions.
class DesktopTitleBar extends StatelessWidget {
  final String? activeDocumentName;
  final bool isDirty;
  final VoidCallback? onBackToHome;
  final VoidCallback onOpenPdf;
  final VoidCallback onOpenCommandPalette;
  final VoidCallback onToggleTheme;
  final VoidCallback onShowShortcuts;

  const DesktopTitleBar({
    super.key,
    this.activeDocumentName,
    this.isDirty = false,
    this.onBackToHome,
    required this.onOpenPdf,
    required this.onOpenCommandPalette,
    required this.onToggleTheme,
    required this.onShowShortcuts,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textSecondary = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          // Upper-left Back to Home control (when reader or navigation callback provided)
          if (onBackToHome != null) ...[
            Tooltip(
              message: 'Back to Home Screen (Alt+Left)',
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: onBackToHome,
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorderSubtle
                          : AppTheme.lightBorderSubtle,
                    ),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 16,
                        color: textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Home',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              height: 18,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: borderColor,
            ),
          ],

          // App Branding
          Icon(
            Icons.picture_as_pdf_rounded,
            color: isDark ? AppTheme.primaryBlueDark : AppTheme.primaryBlue,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'IT PDF',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: textPrimary,
            ),
          ),

          if (activeDocumentName != null) ...[
            Flexible(
              child: Text(
                '  —  $activeDocumentName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (isDirty) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.highlightAmber,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],

          const Spacer(),

          // Spotlight Command Search Pill (Ctrl+K)
          Flexible(
            flex: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onOpenCommandPalette,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 260, minWidth: 60),
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurfaceVariant
                      : AppTheme.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_rounded, size: 15, color: textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search commands & tools...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black12,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'Ctrl+K',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
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
