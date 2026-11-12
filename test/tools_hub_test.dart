import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/features/editor/presentation/tools/tools_registry.dart';
import 'package:it_pdf/features/editor/presentation/tools_screen.dart';

void main() {
  test('registeredPdfTools contains 14 distinct standalone tools', () {
    expect(registeredPdfTools.length, 14);
    final ids = registeredPdfTools.map((t) => t.id).toSet();
    expect(ids.length, 14);
  });

  testWidgets('ToolsScreen renders hub, filters by category and search query', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ToolsScreen())),
    );

    await tester.pumpAndSettle();

    expect(find.text('PDF Tools Hub'), findsOneWidget);
    expect(find.text('Compress PDF'), findsOneWidget);
    expect(find.text('Merge PDF Studio'), findsOneWidget);
    expect(find.text('Protect & Permissions'), findsOneWidget);

    // Filter by Security & Sign category
    await tester.tap(find.text('Security & Sign'));
    await tester.pumpAndSettle();

    expect(find.text('Protect & Permissions'), findsOneWidget);
    expect(find.text('Unlock / Decrypt PDF'), findsOneWidget);
    expect(find.text('Merge PDF Studio'), findsNothing);

    // Switch back to All Tools and search
    await tester.tap(find.text('All Tools'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'watermark');
    await tester.pumpAndSettle();

    expect(find.text('Watermark Studio'), findsOneWidget);
    expect(find.text('Merge PDF Studio'), findsNothing);
  });
}
