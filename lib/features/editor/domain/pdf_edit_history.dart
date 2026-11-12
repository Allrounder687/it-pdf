import 'pdf_edit_transaction.dart';

/// Transactional undo/redo history manager for the PDF content editor.
class PdfEditHistory {
  final List<PdfEditTransaction> _undoStack = [];
  final List<PdfEditTransaction> _redoStack = [];
  final int maxHistoryLength;

  PdfEditHistory({this.maxHistoryLength = 100});

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;

  /// Pushes a completed transaction onto the undo stack and clears redo.
  void pushTransaction(PdfEditTransaction transaction) {
    _undoStack.add(transaction);
    if (_undoStack.length > maxHistoryLength) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  /// Pops the most recent transaction for undoing.
  PdfEditTransaction? popUndo() {
    if (!canUndo) return null;
    final transaction = _undoStack.removeLast();
    _redoStack.add(transaction);
    return transaction;
  }

  /// Pops the most recent transaction for redoing.
  PdfEditTransaction? popRedo() {
    if (!canRedo) return null;
    final transaction = _redoStack.removeLast();
    _undoStack.add(transaction);
    return transaction;
  }

  /// Clears history, typically upon file save or new file load.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
