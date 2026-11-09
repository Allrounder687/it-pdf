import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers.dart';
import '../data/signature_repository.dart';
import 'signature_model.dart';

/// Provider for SignatureRepository.
final signatureRepositoryProvider = Provider<SignatureRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SignatureRepository(prefs);
});

/// Riverpod Notifier managing the user's stored signatures.
class SignatureNotifier extends Notifier<List<SignatureProfile>> {
  static const _uuid = Uuid();

  SignatureRepository get _repository => ref.read(signatureRepositoryProvider);

  @override
  List<SignatureProfile> build() {
    return _repository.getSignatures();
  }

  void loadSignatures() {
    state = _repository.getSignatures();
  }

  Future<SignatureProfile> createProfile({
    required String name,
    required List<List<SignaturePoint>> strokes,
    int colorValue = 0xFF000000,
  }) async {
    final profile = SignatureProfile(
      id: _uuid.v4(),
      name: name,
      strokes: strokes,
      createdAt: DateTime.now(),
      colorValue: colorValue,
    );

    await _repository.saveSignature(profile);
    loadSignatures();
    return profile;
  }

  Future<void> deleteProfile(String id) async {
    await _repository.deleteSignature(id);
    loadSignatures();
  }
}

/// Provider for SignatureNotifier.
final signatureNotifierProvider =
    NotifierProvider<SignatureNotifier, List<SignatureProfile>>(
      SignatureNotifier.new,
    );
