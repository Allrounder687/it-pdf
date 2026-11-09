import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/features/signatures/data/signature_repository.dart';
import 'package:it_pdf/features/signatures/domain/signature_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Signature Profile Tests', () {
    test('serializes strokes and coordinates accurately', () {
      final profile = SignatureProfile(
        id: 'sig-1',
        name: 'Work Initials',
        strokes: [
          [
            const SignaturePoint(x: 10.0, y: 15.0),
            const SignaturePoint(x: 20.0, y: 25.0),
          ],
          [
            const SignaturePoint(x: 30.0, y: 35.0),
          ]
        ],
        createdAt: DateTime.now(),
        colorValue: 0xFF0D47A1,
      );

      final json = profile.toJson();
      final fromJson = SignatureProfile.fromJson(json);

      expect(fromJson.id, 'sig-1');
      expect(fromJson.name, 'Work Initials');
      expect(fromJson.strokes.length, 2);
      expect(fromJson.strokes[0].length, 2);
      expect(fromJson.strokes[0][0].x, 10.0);
      expect(fromJson.strokes[0][1].y, 25.0);
      expect(fromJson.colorValue, 0xFF0D47A1);
    });

    test('SignatureRepository persists profiles across sessions', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SignatureRepository(prefs);

      final profile = SignatureProfile(
        id: 'sig-saved',
        name: 'Official Stamp',
        strokes: const [],
        createdAt: DateTime.now(),
      );

      await repo.saveSignature(profile);
      var all = repo.getSignatures();
      expect(all.length, 1);
      expect(all.first.name, 'Official Stamp');

      await repo.deleteSignature('sig-saved');
      all = repo.getSignatures();
      expect(all.isEmpty, true);
    });
  });
}
