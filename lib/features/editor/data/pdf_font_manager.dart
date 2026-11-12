/// Comprehensive font management for genuine PDF content editing.
/// Supports standard PDF 14 base fonts, system fonts, and substitution heuristics.
class PdfFontManager {
  static const List<String> standard14Fonts = [
    'Helvetica',
    'Helvetica-Bold',
    'Helvetica-Oblique',
    'Helvetica-BoldOblique',
    'Times-Roman',
    'Times-Bold',
    'Times-Italic',
    'Times-BoldItalic',
    'Courier',
    'Courier-Bold',
    'Courier-Oblique',
    'Courier-BoldOblique',
    'Symbol',
    'ZapfDingbats',
  ];

  static const List<String> availableEditorFontFamilies = [
    'Helvetica',
    'Times-Roman',
    'Courier',
    'Arial',
    'Times New Roman',
    'Courier New',
    'Georgia',
    'Segoe UI',
    'Roboto',
  ];

  /// Resolves the exact standard PDF font name based on family, bold, and italic flags.
  static String resolveStandardFontName({
    required String family,
    bool isBold = false,
    bool isItalic = false,
  }) {
    final lower = family.toLowerCase().replaceAll(' ', '').replaceAll('-', '');

    if (lower.contains('times')) {
      if (isBold && isItalic) return 'Times-BoldItalic';
      if (isBold) return 'Times-Bold';
      if (isItalic) return 'Times-Italic';
      return 'Times-Roman';
    } else if (lower.contains('courier')) {
      if (isBold && isItalic) return 'Courier-BoldOblique';
      if (isBold) return 'Courier-Bold';
      if (isItalic) return 'Courier-Oblique';
      return 'Courier';
    } else if (lower.contains('symbol')) {
      return 'Symbol';
    } else if (lower.contains('zapf')) {
      return 'ZapfDingbats';
    } else {
      // Default to Helvetica (Arial fallback)
      if (isBold && isItalic) return 'Helvetica-BoldOblique';
      if (isBold) return 'Helvetica-Bold';
      if (isItalic) return 'Helvetica-Oblique';
      return 'Helvetica';
    }
  }

  /// Determines if a font name is one of the standard 14 PDF fonts.
  static bool isStandardFont(String fontName) {
    return standard14Fonts.any(
      (f) => f.toLowerCase() == fontName.toLowerCase(),
    );
  }

  /// Verifies whether all characters in [text] can be safely represented
  /// in Standard 14 PDF fonts (Latin-1 / WinAnsiEncoding), or if Unicode
  /// substitution is required.
  static bool canEncodeWithStandardFont(String text) {
    for (final rune in text.runes) {
      // Standard 14 fonts safely support ASCII and Latin-1 supplement (0x20 to 0xFF)
      if (rune > 0xFF) {
        return false;
      }
    }
    return true;
  }
}
