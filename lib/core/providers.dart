import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'platform/file_picker_service.dart';
import 'storage/preferences_service.dart';
import 'storage/safe_document_storage.dart';

/// Provider for global SharedPreferences instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in ProviderScope');
});

/// Provider for PreferencesService.
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesService(prefs);
});

/// Provider for FilePickerService.
final filePickerServiceProvider = Provider<FilePickerService>((ref) {
  return FilePickerService();
});

/// Provider for SafeDocumentStorage.
final safeDocumentStorageProvider = Provider<SafeDocumentStorage>((ref) {
  return SafeDocumentStorage();
});

/// Provider for initial command-line arguments passed on app launch.
final initialCliArgsProvider = Provider<List<String>>((ref) {
  return const [];
});


