import 'package:flutter/widgets.dart';
import '../domain/reader_state.dart';

/// Applies color filter matrix to the document viewport for dark, night, and sepia modes.
Widget applyReaderThemeFilter({
  required ReaderThemeMode themeMode,
  required Widget child,
}) {
  switch (themeMode) {
    case ReaderThemeMode.dark:
    case ReaderThemeMode.night:
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1.0,
          0,
          0,
          0,
          255,
          0,
          -1.0,
          0,
          0,
          255,
          0,
          0,
          -1.0,
          0,
          255,
          0,
          0,
          0,
          1.0,
          0,
        ]),
        child: child,
      );
    case ReaderThemeMode.sepia:
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.9,
          0,
          0,
          0,
          40,
          0,
          0.85,
          0,
          0,
          30,
          0,
          0,
          0.75,
          0,
          10,
          0,
          0,
          0,
          1.0,
          0,
        ]),
        child: child,
      );
    case ReaderThemeMode.light:
      return child;
  }
}
