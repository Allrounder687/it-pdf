/// Application domain failure representations.
sealed class Failure {
  final String message;
  final Object? cause;

  const Failure(this.message, [this.cause]);

  @override
  String toString() => '$runtimeType: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Document loading or decoding failure.
class DocumentLoadFailure extends Failure {
  const DocumentLoadFailure(super.message, [super.cause]);
}

/// File system read or write failure.
class FileSystemFailure extends Failure {
  const FileSystemFailure(super.message, [super.cause]);
}

/// Page manipulation failure (reorder, rotate, delete, merge).
class PageOperationFailure extends Failure {
  const PageOperationFailure(super.message, [super.cause]);
}

/// Annotation persistence failure.
class AnnotationFailure extends Failure {
  const AnnotationFailure(super.message, [super.cause]);
}

/// Unsupported or corrupted format failure.
class CorruptedDocumentFailure extends Failure {
  const CorruptedDocumentFailure(super.message, [super.cause]);
}

/// Permission denied failure.
class PermissionDeniedFailure extends Failure {
  const PermissionDeniedFailure(super.message, [super.cause]);
}
