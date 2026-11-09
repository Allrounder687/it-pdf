import 'package:flutter/widgets.dart';

// Intent definitions for keyboard shortcuts in PDF Reader Viewport
class SaveDocumentIntent extends Intent {
  const SaveDocumentIntent();
}

class SearchDocumentIntent extends Intent {
  const SearchDocumentIntent();
}

class UndoActionIntent extends Intent {
  const UndoActionIntent();
}

class RedoActionIntent extends Intent {
  const RedoActionIntent();
}

class ZoomInDocumentIntent extends Intent {
  const ZoomInDocumentIntent();
}

class ZoomOutDocumentIntent extends Intent {
  const ZoomOutDocumentIntent();
}

class ZoomResetDocumentIntent extends Intent {
  const ZoomResetDocumentIntent();
}

class PrevPageDocumentIntent extends Intent {
  const PrevPageDocumentIntent();
}

class NextPageDocumentIntent extends Intent {
  const NextPageDocumentIntent();
}
