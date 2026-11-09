import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/features/page_organizer/domain/page_organizer_notifier.dart';

void main() {
  group('PageOrganizer Logic Tests', () {
    const params = PageOrganizerParams(
      path: '/path/test.pdf',
      id: 'test-id',
      name: 'test.pdf',
      pageCount: 5,
    );

    test('initializes with correct page count and positions', () {
      final container = ProviderContainer();
      final state = container.read(pageOrganizerNotifierProvider(params));

      expect(state.pages.length, 5);
      expect(state.pages[0].originalPageNumber, 1);
      expect(state.pages[0].currentPosition, 0);
      expect(state.pages[4].originalPageNumber, 5);
    });

    test('rotates page by 90 degrees and wraps at 360', () {
      final container = ProviderContainer();
      final notifier = container.read(
        pageOrganizerNotifierProvider(params).notifier,
      );

      notifier.rotatePage(0, 90);
      var state = container.read(pageOrganizerNotifierProvider(params));
      expect(state.pages[0].rotationDegrees, 90);

      notifier.rotatePage(0, 270);
      state = container.read(pageOrganizerNotifierProvider(params));
      expect(state.pages[0].rotationDegrees, 0); // 360 % 360 == 0
    });

    test('reorders page and updates relative current positions', () {
      final container = ProviderContainer();
      final notifier = container.read(
        pageOrganizerNotifierProvider(params).notifier,
      );

      // Move page 0 (original 1) to index 3
      notifier.reorderPage(0, 3);
      final state = container.read(pageOrganizerNotifierProvider(params));

      expect(state.pages[0].originalPageNumber, 2);
      expect(state.pages[1].originalPageNumber, 3);
      expect(state.pages[2].originalPageNumber, 1);
    });

    test('selects and deletes selected pages', () {
      final container = ProviderContainer();
      final notifier = container.read(
        pageOrganizerNotifierProvider(params).notifier,
      );

      notifier.toggleSelect(1); // select page 2
      notifier.toggleSelect(3); // select page 4
      notifier.deleteSelected();

      final state = container.read(pageOrganizerNotifierProvider(params));
      expect(state.pages.length, 3);
      expect(state.pages[0].originalPageNumber, 1);
      expect(state.pages[1].originalPageNumber, 3);
      expect(state.pages[2].originalPageNumber, 5);
    });
  });
}
