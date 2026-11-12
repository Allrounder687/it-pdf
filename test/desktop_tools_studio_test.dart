import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/features/editor/domain/tool_task_notifier.dart';
import 'package:it_pdf/features/home/presentation/home_screen.dart';

void main() {
  testWidgets(
    'Desktop HomeScreen shows monochrome Tools Studio, Edit PDF, Preview Modal, and concurrent Task Tray states',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomeScreen())),
      );
      await tester.pumpAndSettle();

      // Desktop renders IT PDF Tools Studio with Edit PDF & Document Insights visible
      expect(find.text('IT PDF Tools Studio'), findsOneWidget);
      expect(find.text('Edit PDF & Visual Objects'), findsOneWidget);
      expect(find.text('Document Insights & Summary'), findsOneWidget);

      // Tapping a tool card opens its Capability Preview Modal
      await tester.tap(find.text('Edit PDF & Visual Objects'));
      await tester.pumpAndSettle();

      expect(find.text('CAPABILITIES & FEATURES'), findsOneWidget);
      expect(find.text('Open Fullscreen Studio'), findsOneWidget);

      // Minimize to Task Tray docks a Yellow RUNNING task onto the homepage
      await tester.tap(find.byTooltip('Minimize to Task Tray'));
      await tester.pumpAndSettle();

      expect(find.text('TASK TRAY (1)'), findsOneWidget);
      expect(find.text('RUNNING'), findsOneWidget);

      // Verify state transitions: complete (Green) and fail (Red) update tray & notifications
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final taskId = container.read(toolTaskManagerProvider).first.id;

      container
          .read(toolTaskManagerProvider.notifier)
          .completeTask(
            taskId,
            outputPath: 'sample_out.pdf',
            message: 'Edited cleanly',
          );
      await tester.pump();
      expect(find.text('DONE'), findsOneWidget);
      expect(find.text('Edit PDF & Visual Objects Finished'), findsOneWidget);

      container
          .read(toolTaskManagerProvider.notifier)
          .failTask(taskId, error: 'Corrupt stream');
      await tester.pump();
      expect(find.text('ERROR'), findsOneWidget);
      expect(find.text('Edit PDF & Visual Objects Failed'), findsOneWidget);

      // Let 5s auto-dismiss timers drain cleanly so Flutter test doesn't complain
      await tester.pump(const Duration(seconds: 6));
    },
  );
}
