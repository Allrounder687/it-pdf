import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/annotation_model.dart';

/// Storage layer for serializing and storing annotations per document.
class AnnotationStorage {
  static const String _prefix = 'it_pdf_annotations_doc_';
  final SharedPreferences _prefs;

  AnnotationStorage(this._prefs);

  /// Load annotations for a given document.
  List<Annotation> loadAnnotations(String documentId) {
    try {
      final key = '$_prefix$documentId';
      final jsonString = _prefs.getString(key);
      if (jsonString == null || jsonString.isEmpty) return [];
      final List<dynamic> list = jsonDecode(jsonString) as List<dynamic>;
      return list
          .map((item) => Annotation.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      AppLogger.error('Failed to load annotations for $documentId', error: e, stackTrace: st);
      return [];
    }
  }

  /// Persist annotations for a given document.
  Future<bool> saveAnnotations(String documentId, List<Annotation> annotations) async {
    try {
      final key = '$_prefix$documentId';
      final list = annotations.map((a) => a.toMap()).toList();
      return await _prefs.setString(key, jsonEncode(list));
    } catch (e, st) {
      AppLogger.error('Failed to persist annotations for $documentId', error: e, stackTrace: st);
      return false;
    }
  }
}
