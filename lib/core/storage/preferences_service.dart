import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/document_meta.dart';
import '../logging/app_logger.dart';

/// Offline-first persistent storage using SharedPreferences.
class PreferencesService {
  static const String _documentsKey = 'it_pdf_documents_registry_v1';
  static const String _recentDocIdsKey = 'it_pdf_recent_doc_ids_v1';
  static const String _themeModeKey = 'it_pdf_theme_mode_v1';
  static const String _readingLayoutKey = 'it_pdf_reading_layout_v1';

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  /// Load all saved documents from local storage.
  List<DocumentMeta> loadDocuments() {
    try {
      final jsonString = _prefs.getString(_documentsKey);
      if (jsonString == null || jsonString.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded
          .map((item) => DocumentMeta.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      AppLogger.error(
        'Failed to parse saved documents from disk',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Save the document list to local storage.
  Future<bool> saveDocuments(List<DocumentMeta> docs) async {
    try {
      final list = docs.map((d) => d.toMap()).toList();
      return await _prefs.setString(_documentsKey, jsonEncode(list));
    } catch (e, st) {
      AppLogger.error(
        'Failed to persist documents to disk',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Get recent document IDs.
  List<String> getRecentDocIds() {
    return _prefs.getStringList(_recentDocIdsKey) ?? [];
  }

  /// Save recent document IDs.
  Future<bool> saveRecentDocIds(List<String> ids) async {
    return await _prefs.setStringList(_recentDocIdsKey, ids);
  }

  /// Get user preferred theme mode ('light', 'dark', 'system').
  String getThemeMode() {
    return _prefs.getString(_themeModeKey) ?? 'system';
  }

  /// Set user preferred theme mode.
  Future<bool> setThemeMode(String mode) async {
    return await _prefs.setString(_themeModeKey, mode);
  }

  /// Get default reading layout ('continuous_vertical', 'single_page', 'two_page').
  String getReadingLayout() {
    return _prefs.getString(_readingLayoutKey) ?? 'continuous_vertical';
  }

  /// Set default reading layout.
  Future<bool> setReadingLayout(String layout) async {
    return await _prefs.setString(_readingLayoutKey, layout);
  }
}
