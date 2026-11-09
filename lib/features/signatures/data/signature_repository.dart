import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/signature_model.dart';

/// Storage repository for persisting user signature profiles.
class SignatureRepository {
  static const String _storageKey = 'it_pdf_user_signatures_v1';
  final SharedPreferences _prefs;

  SignatureRepository(this._prefs);

  /// Load all stored signature profiles.
  List<SignatureProfile> getSignatures() {
    try {
      final jsonString = _prefs.getString(_storageKey);
      if (jsonString == null || jsonString.isEmpty) return [];
      final List<dynamic> list = jsonDecode(jsonString) as List<dynamic>;
      return list
          .map((item) => SignatureProfile.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      AppLogger.error(
        'Failed to load user signatures',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Save new or updated signature profile.
  Future<bool> saveSignature(SignatureProfile profile) async {
    try {
      final current = getSignatures();
      final index = current.indexWhere((p) => p.id == profile.id);
      if (index >= 0) {
        current[index] = profile;
      } else {
        current.insert(0, profile);
      }
      final jsonList = current.map((p) => p.toMap()).toList();
      return await _prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      AppLogger.error(
        'Failed to save signature profile',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Delete signature profile by ID.
  Future<bool> deleteSignature(String id) async {
    try {
      final current = getSignatures();
      current.removeWhere((p) => p.id == id);
      final jsonList = current.map((p) => p.toMap()).toList();
      return await _prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      AppLogger.error('Failed to delete signature', error: e, stackTrace: st);
      return false;
    }
  }
}
