import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/core/storage/preferences_service.dart';
import 'package:it_pdf/features/library/data/document_repository.dart';
import 'package:it_pdf/shared/models/document_meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DocumentRepository Tests', () {
    late PreferencesService prefsService;
    late DocumentRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      prefsService = PreferencesService(prefs);
      repository = DocumentRepository(prefsService);
    });

    test('adds, retrieves and updates document registry', () async {
      final doc1 = DocumentMeta(
        id: 'doc-1',
        name: 'Spec.pdf',
        path: '/tmp/spec.pdf',
        sizeInBytes: 12345,
        lastOpened: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await repository.saveDocument(doc1);
      var all = await repository.getDocuments();
      expect(all.length, 1);
      expect(all.first.name, 'Spec.pdf');

      // Update progress
      await repository.updateReadingProgress('doc-1', 7, 20);
      all = await repository.getDocuments();
      expect(all.first.lastPageRead, 7);
      expect(all.first.totalPages, 20);

      // Toggle favorite
      await repository.toggleFavorite('doc-1');
      all = await repository.getDocuments();
      expect(all.first.isFavorite, true);

      // Rename
      await repository.renameDocument('doc-1', 'Renamed_Spec.pdf');
      all = await repository.getDocuments();
      expect(all.first.name, 'Renamed_Spec.pdf');

      // Set folder
      await repository.setFolder('doc-1', 'Projects');
      all = await repository.getDocuments();
      expect(all.first.folder, 'Projects');

      // Remove from registry without deleting source
      await repository.removeDocument('doc-1', deleteSourceFile: false);
      all = await repository.getDocuments();
      expect(all.isEmpty, true);
    });
  });
}
