import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/shared/models/document_meta.dart';

void main() {
  group('DocumentMeta Model Tests', () {
    test('serializes to Map and JSON cleanly', () {
      final now = DateTime.now();
      final doc = DocumentMeta(
        id: 'doc-123',
        name: 'Annual_Report.pdf',
        path: '/data/user/0/com.itfeels.it_pdf/Annual_Report.pdf',
        sizeInBytes: 2048576, // ~1.95 MB
        lastOpened: now,
        lastPageRead: 14,
        totalPages: 85,
        isFavorite: true,
        folder: 'Finance',
        createdAt: now,
        tags: const ['taxes', '2026'],
      );

      final map = doc.toMap();
      expect(map['id'], 'doc-123');
      expect(map['name'], 'Annual_Report.pdf');
      expect(map['isFavorite'], true);
      expect(map['tags'], ['taxes', '2026']);

      final json = doc.toJson();
      final fromJson = DocumentMeta.fromJson(json);

      expect(fromJson.id, doc.id);
      expect(fromJson.name, doc.name);
      expect(fromJson.lastPageRead, 14);
      expect(fromJson.totalPages, 85);
      expect(fromJson.isFavorite, true);
      expect(fromJson.folder, 'Finance');
      expect(fromJson.tags, ['taxes', '2026']);
    });

    test('formattedSize calculates B, KB and MB correctly', () {
      final docB = DocumentMeta(
        id: '1',
        name: 'tiny.pdf',
        path: '',
        sizeInBytes: 500,
        lastOpened: DateTime.now(),
        createdAt: DateTime.now(),
      );
      expect(docB.formattedSize, '500 B');

      final docKB = docB.copyWith(sizeInBytes: 153600);
      expect(docKB.formattedSize, '150.0 KB');

      final docMB = docB.copyWith(sizeInBytes: 5242880);
      expect(docMB.formattedSize, '5.0 MB');
    });

    test('copyWith modifies attributes immutably', () {
      final original = DocumentMeta(
        id: 'orig',
        name: 'Original.pdf',
        path: '/path/orig.pdf',
        sizeInBytes: 1000,
        lastOpened: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final modified = original.copyWith(
        name: 'Renamed.pdf',
        lastPageRead: 5,
        isFavorite: true,
      );

      expect(modified.name, 'Renamed.pdf');
      expect(modified.lastPageRead, 5);
      expect(modified.isFavorite, true);
      expect(original.name, 'Original.pdf');
      expect(original.lastPageRead, 1);
    });
  });
}
