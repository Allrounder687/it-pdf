import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/features/annotations/domain/annotation_model.dart';

void main() {
  group('Annotation Engine Geometry & Model Tests', () {
    test('NormalizedPoint scales accurately across varying viewport sizes', () {
      const point = NormalizedPoint(0.5, 0.25);
      const pageSize = Size(800, 1000);

      final offset = point.toOffset(pageSize);
      expect(offset.dx, 400.0);
      expect(offset.dy, 250.0);

      final roundTrip = NormalizedPoint.fromOffset(offset, pageSize);
      expect(roundTrip.x, 0.5);
      expect(roundTrip.y, 0.25);
    });

    test('NormalizedRect scales bounds accurately', () {
      const nRect = NormalizedRect(
        left: 0.1,
        top: 0.2,
        right: 0.6,
        bottom: 0.8,
      );
      const pageSize = Size(1000, 2000);

      final rect = nRect.toRect(pageSize);
      expect(rect.left, 100.0);
      expect(rect.top, 400.0);
      expect(rect.right, 600.0);
      expect(rect.bottom, 1600.0);
      expect(rect.width, 500.0);
      expect(rect.height, 1200.0);
    });

    test('Annotation serialization preserves points, colors and type', () {
      final ann = Annotation(
        id: 'ann-1',
        documentId: 'doc-1',
        pageNumber: 3,
        type: AnnotationType.highlight,
        colorValue: 0xFFFFEB3B,
        strokeWidth: 16.0,
        opacity: 0.45,
        points: const [NormalizedPoint(0.1, 0.1), NormalizedPoint(0.5, 0.1)],
        createdAt: DateTime.now(),
      );

      final map = ann.toMap();
      expect(map['id'], 'ann-1');
      expect(map['type'], 'highlight');
      expect(map['points'].length, 2);

      final fromMap = Annotation.fromMap(map);
      expect(fromMap.id, ann.id);
      expect(fromMap.type, AnnotationType.highlight);
      expect(fromMap.points.length, 2);
      expect(fromMap.strokeWidth, 16.0);
      expect(fromMap.opacity, 0.45);
    });
  });
}
